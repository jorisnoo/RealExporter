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

@MainActor
class Exporter {
    private let fileManager = FileManager.default
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func export(
        data: BeRealExport,
        options: ExportOptions,
        progressHandler: @escaping @MainActor (ExportProgress) -> Void
    ) async throws {
        guard let destinationURL = options.destinationURL else {
            throw ExporterError.noDestination
        }

        isCancelled = false

        var itemsToExport: [(type: String, date: Date, backPath: URL, frontPath: URL, location: Location?, caption: String?)] = []

        for post in data.posts where post.hasBothImages {
            let backPath = post.primary.localPath(relativeTo: data.baseURL)
            let frontPath = post.secondary.localPath(relativeTo: data.baseURL)

            if fileManager.fileExists(atPath: backPath.path) &&
               fileManager.fileExists(atPath: frontPath.path) {
                itemsToExport.append((
                    type: "post",
                    date: post.takenAt,
                    backPath: backPath,
                    frontPath: frontPath,
                    location: post.location,
                    caption: post.caption
                ))
            }
        }

        for memory in data.memories where memory.hasBothImages {
            let backPath = memory.backImageForExport.localPath(relativeTo: data.baseURL)
            let frontPath = memory.frontImageForExport.localPath(relativeTo: data.baseURL)

            if fileManager.fileExists(atPath: backPath.path) &&
               fileManager.fileExists(atPath: frontPath.path) {
                itemsToExport.append((
                    type: "memory",
                    date: memory.takenTime,
                    backPath: backPath,
                    frontPath: frontPath,
                    location: nil,
                    caption: memory.caption
                ))
            }
        }

        let conversationImages = options.includeConversations ? data.conversationImages : []
        let total = itemsToExport.count + conversationImages.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let imageStyle = options.imageStyle
        let folderStructure = options.folderStructure

        var currentIndex = 0

        for item in itemsToExport {
            await Task.yield()

            if isCancelled {
                throw ExporterError.cancelled
            }

            let outputPath = try buildOutputPath(
                for: item.date,
                type: item.type,
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
            let combined = imageStyle == .combined

            try await Task.detached {
                try await ImageProcessor.shared.processAndSave(
                    backPath: backPath,
                    frontPath: frontPath,
                    outputPath: outputPath,
                    combined: combined,
                    metadata: metadata
                )
            }.value

            currentIndex += 1
            let progress = ExportProgress(
                current: currentIndex,
                total: total,
                currentItem: outputPath.lastPathComponent
            )
            progressHandler(progress)
        }

        if !conversationImages.isEmpty {
            let conversationsFolder = destinationURL.appendingPathComponent("Conversations")
            if !fileManager.fileExists(atPath: conversationsFolder.path) {
                try fileManager.createDirectory(at: conversationsFolder, withIntermediateDirectories: true)
            }

            for image in conversationImages {
                await Task.yield()

                if isCancelled {
                    throw ExporterError.cancelled
                }

                let outputPath = conversationsFolder.appendingPathComponent(image.filename)

                if !fileManager.fileExists(atPath: outputPath.path) {
                    try fileManager.copyItem(at: image.url, to: outputPath)
                }

                currentIndex += 1
                let progress = ExportProgress(
                    current: currentIndex,
                    total: total,
                    currentItem: "Conversations/\(image.filename)"
                )
                progressHandler(progress)
            }
        }
    }

    private func buildOutputPath(
        for date: Date,
        type: String,
        folderStructure: FolderStructure,
        destinationURL: URL,
        dateFormatter: DateFormatter
    ) throws -> URL {
        let filename = "bereal_\(type)_\(dateFormatter.string(from: date)).jpg"

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

        return outputDirectory.appendingPathComponent(filename)
    }
}
