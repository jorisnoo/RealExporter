import Foundation
import Testing
@testable import RealExporter

struct DataLoaderTests {
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RealExporterTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func createValidDataFolder(at baseURL: URL) throws {
        let photosDir = baseURL.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let userJSON = """
        {"username": "testuser", "fullname": "Test User"}
        """
        try userJSON.write(
            to: baseURL.appendingPathComponent("user.json"),
            atomically: true, encoding: .utf8
        )

        let postsJSON = """
        [{"primary": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/front.jpg"}, "secondary": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/back.jpg"}, "takenAt": "2024-01-15T12:00:00Z"}]
        """
        try postsJSON.write(
            to: baseURL.appendingPathComponent("posts.json"),
            atomically: true, encoding: .utf8
        )

        let memoriesJSON = """
        [{"frontImage": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/front.jpg"}, "backImage": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/back.jpg"}, "date": "2024-01-15T00:00:00Z", "takenTime": "2024-01-15T12:30:00Z"}]
        """
        try memoriesJSON.write(
            to: baseURL.appendingPathComponent("memories.json"),
            atomically: true, encoding: .utf8
        )
    }

    @Test func loadFromFolderWithValidStructure() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createValidDataFolder(at: tempDir)

        let export = try await DataLoader.loadFromFolder(tempDir)
        #expect(export.user.username == "testuser")
        #expect(export.posts.count == 1)
        #expect(export.memories.count == 1)
    }

    @Test func loadFromFolderMissingUserJsonThrows() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        await #expect(throws: DataLoaderError.self) {
            try await DataLoader.loadFromFolder(tempDir)
        }
    }

    @Test func loadFromFolderMissingPhotosFolderThrows() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        try """
        {"username": "test", "fullname": "Test"}
        """.write(
            to: tempDir.appendingPathComponent("user.json"),
            atomically: true, encoding: .utf8
        )
        try "[]".write(
            to: tempDir.appendingPathComponent("posts.json"),
            atomically: true, encoding: .utf8
        )
        try "[]".write(
            to: tempDir.appendingPathComponent("memories.json"),
            atomically: true, encoding: .utf8
        )

        await #expect(throws: DataLoaderError.self) {
            try await DataLoader.loadFromFolder(tempDir)
        }
    }

    @Test func loadFromFolderMalformedJsonThrows() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let photosDir = tempDir.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        try "not json".write(
            to: tempDir.appendingPathComponent("user.json"),
            atomically: true, encoding: .utf8
        )
        try "[]".write(
            to: tempDir.appendingPathComponent("posts.json"),
            atomically: true, encoding: .utf8
        )
        try "[]".write(
            to: tempDir.appendingPathComponent("memories.json"),
            atomically: true, encoding: .utf8
        )

        await #expect(throws: DataLoaderError.self) {
            try await DataLoader.loadFromFolder(tempDir)
        }
    }

    @Test func loadFromFolderFindsNestedDataFolder() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let nestedDir = tempDir.appendingPathComponent("export-data")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try createValidDataFolder(at: nestedDir)

        let export = try await DataLoader.loadFromFolder(tempDir)
        #expect(export.user.username == "testuser")
    }

    @Test func loadFromFolderCommentsFileLoaded() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createValidDataFolder(at: tempDir)

        let commentsJSON = """
        [{"postId": "123", "content": "Nice!"}]
        """
        try commentsJSON.write(
            to: tempDir.appendingPathComponent("comments.json"),
            atomically: true, encoding: .utf8
        )

        let export = try await DataLoader.loadFromFolder(tempDir)
        #expect(export.comments.count == 1)
        #expect(export.comments.first?.content == "Nice!")
    }

    @Test func loadFromFolderMissingCommentsReturnsEmpty() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createValidDataFolder(at: tempDir)

        let export = try await DataLoader.loadFromFolder(tempDir)
        #expect(export.comments.isEmpty)
    }

    @Test func loadFromURLWithDirectoryWorks() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createValidDataFolder(at: tempDir)

        let export = try await DataLoader.loadFromURL(tempDir)
        #expect(export.user.username == "testuser")
    }

    @Test func loadFromZipExtractsNestedDataFolder() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let dataDir = tempDir.appendingPathComponent("bereal-export")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        try createValidDataFolder(at: dataDir)

        let zipURL = tempDir.appendingPathComponent("export.zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", "--keepParent", dataDir.path, zipURL.path]
        try ditto.run()
        ditto.waitUntilExit()
        try #require(ditto.terminationStatus == 0)

        let export = try await DataLoader.loadFromURL(zipURL)
        defer { export.temporaryDirectory.map(cleanup) }

        #expect(export.user.username == "testuser")
        #expect(export.posts.count == 1)
        #expect(export.temporaryDirectory != nil)
    }

    @Test func loadFromZipWithCorruptArchiveThrows() async throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let zipURL = tempDir.appendingPathComponent("broken.zip")
        try "not a zip".write(to: zipURL, atomically: true, encoding: .utf8)

        await #expect(throws: DataLoaderError.self) {
            try await DataLoader.loadFromZip(zipURL)
        }
    }

    @Test func loadFromURLWithNonexistentPathThrows() async {
        let badURL = URL(fileURLWithPath: "/nonexistent/path/that/does/not/exist")
        await #expect(throws: Error.self) {
            try await DataLoader.loadFromURL(badURL)
        }
    }
}
