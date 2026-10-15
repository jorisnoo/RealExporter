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

/// What an export actually wrote, for the completion message.
struct ExportResult: Sendable, Equatable {
    var beReals = 0
    var videos = 0
    var chatPhotos = 0
}

enum ExporterError: LocalizedError {
    case noDestination
    case failedToCreateDirectory
    case cancelled
    case nothingToExport

    var errorDescription: String? {
        switch self {
        case .noDestination:
            return "No destination folder selected."
        case .failedToCreateDirectory:
            return "Failed to create output directory."
        case .cancelled:
            return "Export was cancelled."
        case .nothingToExport:
            return "There are no BeReals in the selected date range."
        }
    }
}

enum Exporter {
    @discardableResult
    static func export(
        data: BeRealExport,
        options: ExportOptions,
        progressHandler: @escaping @MainActor (ExportProgress) -> Void
    ) async throws -> ExportResult {
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
                    location: memory.location,
                    caption: memory.caption
                )
            }
        }

        var videoItems: [String: (date: Date, postId: String, backPath: URL, frontPath: URL, backExt: String, frontExt: String, location: Location?, caption: String?)] = [:]

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
                postId: post.primary.postId,
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
                    postId: memory.backImage.postId,
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

        let calendar = Calendar.current
        let rangeStart = options.startDate.map { calendar.startOfDay(for: $0) }
        let rangeEnd = options.endDate.map { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))! }

        let itemsToExport = mergedItems.map { (postId: $0.key, item: $0.value) }
            .filter { item in
                if let start = rangeStart, item.item.date < start { return false }
                if let end = rangeEnd, item.item.date > end { return false }
                return true
            }
            .sorted { ($0.item.date, $0.postId) < ($1.item.date, $1.postId) }
        let videosToExport = videoItems.values
            .filter { item in
                if let start = rangeStart, item.date < start { return false }
                if let end = rangeEnd, item.date > end { return false }
                return true
            }
            .sorted { ($0.date, $0.backPath.path) < ($1.date, $1.backPath.path) }
        let btsToExport = btsItems.values
            .filter { item in
                if let start = rangeStart, item.date < start { return false }
                if let end = rangeEnd, item.date > end { return false }
                return true
            }
            .sorted { ($0.date, $0.path.path) < ($1.date, $1.path.path) }

        var commentsByPostId: [String: [String]] = [:]
        if options.includeComments {
            for comment in data.filteredComments(startDate: options.startDate, endDate: options.endDate) {
                commentsByPostId[comment.postId, default: []].append(comment.content)
            }
        }

        let conversationImages = options.includeConversations
            ? data.filteredConversationImages(startDate: options.startDate, endDate: options.endDate)
                .sorted { ($0.date ?? .distantPast, $0.id) < ($1.date ?? .distantPast, $1.id) }
            : []
        let total = itemsToExport.count + videosToExport.count + btsToExport.count + conversationImages.count
        guard total > 0 else {
            throw ExporterError.nothingToExport
        }

        let dateFormatter = ExportDateFormat.fileNameFormatter()
        let imageStyle = options.imageStyle
        let overlayPosition = options.overlayPosition
        let folderStructure = options.folderStructure

        var currentIndex = 0
        var result = ExportResult()
        var commentsByFolder: [URL: [CommentEntry]] = [:]
        var nameCounts: [String: Int] = [:]

        // Keep comments gathered so far if the export is cancelled or fails.
        var commentsWritten = false
        defer {
            if !commentsWritten {
                try? writeComments(commentsByFolder)
            }
        }

        func collectComments(forPostId postId: String, filename: String, in folder: URL) {
            guard let postComments = commentsByPostId[postId], !postComments.isEmpty else { return }
            commentsByFolder[folder, default: []].append(CommentEntry(filename: filename, comments: postComments))
        }

        // Reserve the whole name family, including separate and combined images.
        func nextBaseName(for date: Date, suffix: String = "") -> String {
            let base = "bereal_\(dateFormatter.string(from: date))\(suffix)"
            nameCounts[base, default: 0] += 1
            let count = nameCounts[base]!
            return count == 1 ? base : "\(base)_\(count)"
        }

        for (postId, item) in itemsToExport {
            try Task.checkCancellation()
            await Task.yield()

            let outputPath = try buildOutputPath(
                for: item.date,
                folderStructure: folderStructure,
                destinationURL: destinationURL,
                baseName: nextBaseName(for: item.date)
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

            collectComments(
                forPostId: MediaReference.postId(forPath: postId),
                filename: outputPath.deletingPathExtension().lastPathComponent,
                in: outputPath.deletingLastPathComponent()
            )

            result.beReals += 1
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

            let baseName = nextBaseName(for: video.date)
            let backOutput = outputDirectory.appendingPathComponent("\(baseName)_back.\(video.backExt)")
            let frontOutput = outputDirectory.appendingPathComponent("\(baseName)_front.\(video.frontExt)")

            if !fileManager.fileExists(atPath: backOutput.path) {
                try fileManager.copyItem(at: video.backPath, to: backOutput)
            }
            if !fileManager.fileExists(atPath: frontOutput.path) {
                try fileManager.copyItem(at: video.frontPath, to: frontOutput)
            }

            collectComments(forPostId: video.postId, filename: baseName, in: outputDirectory)

            result.videos += 1
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

            let baseName = "\(nextBaseName(for: bts.date, suffix: "_bts")).\(bts.ext)"
            let outputPath = outputDirectory.appendingPathComponent(baseName)

            if !fileManager.fileExists(atPath: outputPath.path) {
                try fileManager.copyItem(at: bts.path, to: outputPath)
            }

            result.videos += 1
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

                let base = image.date.map { "chat_\(dateFormatter.string(from: $0))" }
                    ?? "chat_\(image.conversationId)_\((image.filename as NSString).deletingPathExtension)"
                nameCounts[base, default: 0] += 1
                let count = nameCounts[base]!
                let outputFilename = (count == 1 ? base : "\(base)_\(count)") + ".jpg"

                let outputPath = conversationsFolder.appendingPathComponent(outputFilename)
                let sourceURL = image.url
                let imageDate = image.date

                try await Task.detached {
                    try ImageProcessor.convertToJPEG(source: sourceURL, destination: outputPath, date: imageDate)
                }.value

                result.chatPhotos += 1
                currentIndex += 1
                let progress = ExportProgress(
                    current: currentIndex,
                    total: total,
                    currentItem: "Conversations/\(outputFilename)"
                )
                await progressHandler(progress)
            }
        }

        commentsWritten = true
        try writeComments(commentsByFolder)

        return result
    }

    private struct CommentEntry {
        let filename: String
        let comments: [String]
    }

    private static func writeComments(_ commentsByFolder: [URL: [CommentEntry]]) throws {
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

    private static func buildOutputDirectory(
        for date: Date,
        folderStructure: FolderStructure,
        destinationURL: URL
    ) throws -> URL {
        let fileManager = FileManager.default

        let outputDirectory: URL
        switch folderStructure {
        case .byDate:
            let calendar = ExportDateFormat.calendar
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
        baseName: String
    ) throws -> URL {
        let outputDirectory = try buildOutputDirectory(
            for: date,
            folderStructure: folderStructure,
            destinationURL: destinationURL
        )
        let filename = "\(baseName).jpg"
        return outputDirectory.appendingPathComponent(filename)
    }
}
