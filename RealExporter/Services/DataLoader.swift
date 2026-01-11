import Foundation
import UniformTypeIdentifiers

enum DataLoaderError: LocalizedError {
    case invalidPath
    case missingUserJson
    case missingPostsJson
    case missingMemoriesJson
    case missingPhotosFolder
    case parsingError(String)
    case noDataFolderFound

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "The selected path is not valid."
        case .missingUserJson:
            return "Missing user.json file."
        case .missingPostsJson:
            return "Missing posts.json file."
        case .missingMemoriesJson:
            return "Missing memories.json file."
        case .missingPhotosFolder:
            return "Missing Photos folder."
        case .parsingError(let message):
            return "Failed to parse data: \(message)"
        case .noDataFolderFound:
            return "Could not find BeReal data folder."
        }
    }
}

class DataLoader {
    static let shared = DataLoader()

    private let fileManager = FileManager.default

    private init() {}

    func loadFromURL(_ url: URL) async throws -> BeRealExport {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        if isDirectory {
            return try await loadFromFolder(url)
        } else if url.pathExtension.lowercased() == "zip" {
            return try await loadFromZip(url)
        } else {
            throw DataLoaderError.invalidPath
        }
    }

    func loadFromFolder(_ folderURL: URL) async throws -> BeRealExport {
        let dataFolderURL = try findDataFolder(in: folderURL)
        return try await parseDataFolder(dataFolderURL)
    }

    func loadFromZip(_ zipURL: URL) async throws -> BeRealExport {
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        try await extractZip(zipURL, to: tempDirectory)

        let dataFolderURL = try findDataFolder(in: tempDirectory)
        return try await parseDataFolder(dataFolderURL)
    }

    private func findDataFolder(in directory: URL) throws -> URL {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                let userJsonPath = item.appendingPathComponent("user.json")
                if fileManager.fileExists(atPath: userJsonPath.path) {
                    return item
                }

                if let nestedResult = try? findDataFolder(in: item) {
                    return nestedResult
                }
            }
        }

        let userJsonPath = directory.appendingPathComponent("user.json")
        if fileManager.fileExists(atPath: userJsonPath.path) {
            return directory
        }

        throw DataLoaderError.noDataFolderFound
    }

    private func parseDataFolder(_ folderURL: URL) async throws -> BeRealExport {
        let userURL = folderURL.appendingPathComponent("user.json")
        let postsURL = folderURL.appendingPathComponent("posts.json")
        let memoriesURL = folderURL.appendingPathComponent("memories.json")
        let photosURL = folderURL.appendingPathComponent("Photos")

        guard fileManager.fileExists(atPath: userURL.path) else {
            throw DataLoaderError.missingUserJson
        }
        guard fileManager.fileExists(atPath: postsURL.path) else {
            throw DataLoaderError.missingPostsJson
        }
        guard fileManager.fileExists(atPath: memoriesURL.path) else {
            throw DataLoaderError.missingMemoriesJson
        }
        guard fileManager.fileExists(atPath: photosURL.path) else {
            throw DataLoaderError.missingPhotosFolder
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let user: User
        do {
            let userData = try Data(contentsOf: userURL)
            user = try decoder.decode(User.self, from: userData)
        } catch {
            throw DataLoaderError.parsingError("user.json - \(error.localizedDescription)")
        }

        let posts: [Post]
        do {
            let postsData = try Data(contentsOf: postsURL)
            posts = try decoder.decode([Post].self, from: postsData)
        } catch {
            throw DataLoaderError.parsingError("posts.json - \(error.localizedDescription)")
        }

        let memories: [Memory]
        do {
            let memoriesData = try Data(contentsOf: memoriesURL)
            memories = try decoder.decode([Memory].self, from: memoriesData)
        } catch {
            throw DataLoaderError.parsingError("memories.json - \(error.localizedDescription)")
        }

        let conversationImages = loadConversationImages(from: folderURL)

        return BeRealExport(
            user: user,
            posts: posts,
            memories: memories,
            conversationImages: conversationImages,
            baseURL: folderURL
        )
    }

    private func loadConversationImages(from folderURL: URL) -> [ConversationImage] {
        let conversationsURL = folderURL.appendingPathComponent("conversations")

        guard fileManager.fileExists(atPath: conversationsURL.path) else {
            return []
        }

        var images: [ConversationImage] = []
        let imageExtensions = ["webp", "jpg", "jpeg", "png", "heic"]

        guard let conversationFolders = try? fileManager.contentsOfDirectory(
            at: conversationsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for conversationFolder in conversationFolders {
            let isDirectory = (try? conversationFolder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            guard isDirectory else { continue }

            let conversationId = conversationFolder.lastPathComponent

            guard let files = try? fileManager.contentsOfDirectory(
                at: conversationFolder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for file in files {
                let ext = file.pathExtension.lowercased()
                if imageExtensions.contains(ext) {
                    let image = ConversationImage(
                        id: "\(conversationId)_\(file.lastPathComponent)",
                        url: file,
                        conversationId: conversationId,
                        filename: file.lastPathComponent
                    )
                    images.append(image)
                }
            }
        }

        return images
    }

    private func extractZip(_ zipURL: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", destination.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw DataLoaderError.parsingError("Failed to extract ZIP file")
        }
    }

    func validate(_ url: URL) async -> ValidationResult {
        do {
            _ = try await loadFromURL(url)
            return .valid
        } catch let error as DataLoaderError {
            return .invalid([error.localizedDescription])
        } catch {
            return .invalid([error.localizedDescription])
        }
    }
}
