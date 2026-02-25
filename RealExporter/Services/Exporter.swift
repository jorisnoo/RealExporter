import Foundation

struct ExportProgress: Sendable {
    let current: Int
    let total: Int
    let currentItem: String

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

enum ExporterError: LocalizedError {
    case noDestination
    case failedToCreateDirectory
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noDestination:
            return "No destination folder selected."
        case .failedToCreateDirectory:
            return "Failed to create output directory."
        case .cancelled:
            return "Export was cancelled."
        }
    }
}

enum Exporter {
    static func export(
        data: BeRealExport,
        options: ExportOptions,
        progressHandler: @escaping @MainActor (ExportProgress) -> Void
    ) async throws {
        guard let destinationURL = options.destinationURL else {
            throw ExporterError.noDestination
        }

        let fileManager = FileManager.default

        var mergedItems: [String: (date: Date, backPath: URL, frontPath: URL, location: Location?, caption: String?)] = [:]

        for post in data.posts where post.hasBothImages {
            let backPath = post.primary.localPath(relativeTo: data.baseURL)
            let frontPath = post.secondary.localPath(relativeTo: data.baseURL)

            guard fileManager.fileExists(atPath: backPath.path) &&
                  fileManager.fileExists(atPath: frontPath.path) else {
                continue
            }

            let key = post.primary.path
            mergedItems[key] = (
                date: post.takenAt,
                backPath: backPath,
                frontPath: frontPath,
                location: post.location,
                caption: post.caption
            )
        }

        for memory in data.memories where memory.hasBothImages {
            let backPath = memory.backImageForExport.localPath(relativeTo: data.baseURL)
            let frontPath = memory.frontImageForExport.localPath(relativeTo: data.baseURL)

            guard fileManager.fileExists(atPath: backPath.path) &&
                  fileManager.fileExists(atPath: frontPath.path) else {
                continue
            }

            let key = memory.backImageForExport.path
            if mergedItems[key] == nil {
                mergedItems[key] = (
                    date: memory.takenTime,
                    backPath: backPath,
                    frontPath: frontPath,
                    location: nil,
                    caption: memory.caption
                )
            }
        }

        var videoItems: [String: (date: Date, backPath: URL, frontPath: URL, backExt: String, frontExt: String, location: Location?, caption: String?)] = [:]

        for post in data.posts where post.primary.isVideo || post.secondary.isVideo {
            let backPath = post.primary.localPath(relativeTo: data.baseURL)
            let frontPath = post.secondary.localPath(relativeTo: data.baseURL)

            guard fileManager.fileExists(atPath: backPath.path) &&
                  fileManager.fileExists(atPath: frontPath.path) else {
                continue
            }

            let key = post.primary.path
            videoItems[key] = (
                date: post.takenAt,
                backPath: backPath,
                frontPath: frontPath,
                backExt: backPath.pathExtension,
                frontExt: frontPath.pathExtension,
                location: post.location,
                caption: post.caption
            )
        }

        for memory in data.memories where memory.frontImage.isVideo || memory.backImage.isVideo {
            let backPath = memory.backImage.localPath(relativeTo: data.baseURL)
            let frontPath = memory.frontImage.localPath(relativeTo: data.baseURL)

            guard fileManager.fileExists(atPath: backPath.path) &&
                  fileManager.fileExists(atPath: frontPath.path) else {
                continue
            }

            let key = memory.backImage.path
            if videoItems[key] == nil {
                videoItems[key] = (
                    date: memory.takenTime,
                    backPath: backPath,
                    frontPath: frontPath,
                    backExt: backPath.pathExtension,
                    frontExt: frontPath.pathExtension,
                    location: nil,
                    caption: memory.caption
                )
            }
        }

        var btsItems: [String: (date: Date, path: URL, ext: String)] = [:]

        for post in data.posts {
            guard let bts = post.btsMedia else { continue }
            let btsPath = bts.localPath(relativeTo: data.baseURL)
            guard fileManager.fileExists(atPath: btsPath.path) else { continue }
            btsItems[bts.path] = (date: post.takenAt, path: btsPath, ext: btsPath.pathExtension)
        }

        for memory in data.memories {
            guard let bts = memory.btsMedia else { continue }
            let btsPath = bts.localPath(relativeTo: data.baseURL)
            guard fileManager.fileExists(atPath: btsPath.path) else { continue }
            if btsItems[bts.path] == nil {
                btsItems[bts.path] = (date: memory.takenTime, path: btsPath, ext: btsPath.pathExtension)
            }
        }

        let itemsToExport = mergedItems.map { (postId: $0.key, item: $0.value) }.sorted { $0.item.date < $1.item.date }
        let videosToExport = videoItems.values.sorted { $0.date < $1.date }
        let btsToExport = btsItems.values.sorted { $0.date < $1.date }

        var commentsByPostId: [String: [String]] = [:]
        if options.includeComments {
            for comment in data.comments {
                commentsByPostId[comment.postId, default: []].append(comment.content)
            }
        }

        let conversationImages = options.includeConversations ? data.conversationImages : []
        let total = itemsToExport.count + videosToExport.count + btsToExport.count + conversationImages.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let imageStyle = options.imageStyle
        let overlayPosition = options.overlayPosition
        let folderStructure = options.folderStructure

        var currentIndex = 0
        var commentsByFolder: [URL: [(filename: String, comments: [String])]] = [:]

        for (postId, item) in itemsToExport {
            try Task.checkCancellation()
            await Task.yield()

            let outputPath = try buildOutputPath(
                for: item.date,
                folderStructure: folderStructure,
                destinationURL: destinationURL,
                dateFormatter: dateFormatter
            )

            let metadata = ExportMetadata(
                date: item.date,
                location: item.location,
                caption: item.caption
            )

            let backPath = item.backPath
            let frontPath = item.frontPath

            try await Task.detached {
                try ImageProcessor.processAndSave(
                    backPath: backPath,
                    frontPath: frontPath,
                    outputPath: outputPath,
                    style: imageStyle,
                    overlayPosition: overlayPosition,
                    metadata: metadata
                )
            }.value

            let postIdFilename = URL(fileURLWithPath: postId).lastPathComponent.replacingOccurrences(of: ".webp", with: "")
            if let postComments = commentsByPostId[postIdFilename], !postComments.isEmpty {
                let folder = outputPath.deletingLastPathComponent()
                let filename = "bereal_\(dateFormatter.string(from: item.date))"
                commentsByFolder[folder, default: []].append((filename: filename, comments: postComments))
            }

            currentIndex += 1
            let progress = ExportProgress(
                current: currentIndex,
                total: total,
                currentItem: outputPath.lastPathComponent
            )
            await progressHandler(progress)
        }

        for video in videosToExport {
            try Task.checkCancellation()
            await Task.yield()

            let outputDirectory = try buildOutputDirectory(
                for: video.date,
                folderStructure: folderStructure,
                destinationURL: destinationURL
            )

            let baseName = "bereal_\(dateFormatter.string(from: video.date))"
            let backOutput = outputDirectory.appendingPathComponent("\(baseName)_back.\(video.backExt)")
            let frontOutput = outputDirectory.appendingPathComponent("\(baseName)_front.\(video.frontExt)")

            if !fileManager.fileExists(atPath: backOutput.path) {
                try fileManager.copyItem(at: video.backPath, to: backOutput)
            }
            if !fileManager.fileExists(atPath: frontOutput.path) {
                try fileManager.copyItem(at: video.frontPath, to: frontOutput)
            }

            currentIndex += 1
            let progress = ExportProgress(
                current: currentIndex,
                total: total,
                currentItem: "\(baseName)_back.\(video.backExt)"
            )
            await progressHandler(progress)
        }

        for bts in btsToExport {
            try Task.checkCancellation()
            await Task.yield()

            let outputDirectory = try buildOutputDirectory(
                for: bts.date,
                folderStructure: folderStructure,
                destinationURL: destinationURL
            )

            let baseName = "bereal_\(dateFormatter.string(from: bts.date))_bts.\(bts.ext)"
            let outputPath = outputDirectory.appendingPathComponent(baseName)

            if !fileManager.fileExists(atPath: outputPath.path) {
                try fileManager.copyItem(at: bts.path, to: outputPath)
            }

            currentIndex += 1
            let progress = ExportProgress(
                current: currentIndex,
                total: total,
                currentItem: baseName
            )
            await progressHandler(progress)
        }

        if !conversationImages.isEmpty {
            let conversationsFolder = destinationURL.appendingPathComponent("Conversations")
            if !fileManager.fileExists(atPath: conversationsFolder.path) {
                try fileManager.createDirectory(at: conversationsFolder, withIntermediateDirectories: true)
            }

            for image in conversationImages {
                try Task.checkCancellation()
                await Task.yield()

                let outputFilename: String
                if let date = image.date {
                    outputFilename = "chat_\(dateFormatter.string(from: date))_\(image.id.suffix(8)).jpg"
                } else {
                    let name = (image.filename as NSString).deletingPathExtension
                    outputFilename = "\(name).jpg"
                }

                let outputPath = conversationsFolder.appendingPathComponent(outputFilename)
                let sourceURL = image.url
                let imageDate = image.date

                if !fileManager.fileExists(atPath: outputPath.path) {
                    try await Task.detached {
                        try ImageProcessor.convertToJPEG(source: sourceURL, destination: outputPath, date: imageDate)
                    }.value
                }

                currentIndex += 1
                let progress = ExportProgress(
                    current: currentIndex,
                    total: total,
                    currentItem: "Conversations/\(outputFilename)"
                )
                await progressHandler(progress)
            }
        }

        if options.includeComments && !commentsByFolder.isEmpty {
            for (folder, items) in commentsByFolder {
                var content = ""
                for item in items.sorted(by: { $0.filename < $1.filename }) {
                    content += "\(item.filename):\n"
                    for comment in item.comments {
                        content += "  - \(comment)\n"
                    }
                    content += "\n"
                }

                let commentsPath = folder.appendingPathComponent("comments.txt")
                try content.write(to: commentsPath, atomically: true, encoding: .utf8)
            }
        }
    }

    private static func buildOutputDirectory(
        for date: Date,
        folderStructure: FolderStructure,
        destinationURL: URL
    ) throws -> URL {
        let fileManager = FileManager.default

        let outputDirectory: URL
        switch folderStructure {
        case .byDate:
            let calendar = Calendar.current
            let year = calendar.component(.year, from: date)
            let month = String(format: "%02d", calendar.component(.month, from: date))
            let day = String(format: "%02d", calendar.component(.day, from: date))

            outputDirectory = destinationURL
                .appendingPathComponent(String(year))
                .appendingPathComponent(month)
                .appendingPathComponent(day)

        case .flat:
            outputDirectory = destinationURL
        }

        if !fileManager.fileExists(atPath: outputDirectory.path) {
            try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }

        return outputDirectory
    }

    private static func buildOutputPath(
        for date: Date,
        folderStructure: FolderStructure,
        destinationURL: URL,
        dateFormatter: DateFormatter
    ) throws -> URL {
        let outputDirectory = try buildOutputDirectory(
            for: date,
            folderStructure: folderStructure,
            destinationURL: destinationURL
        )
        let filename = "bereal_\(dateFormatter.string(from: date)).jpg"
        return outputDirectory.appendingPathComponent(filename)
    }
}
