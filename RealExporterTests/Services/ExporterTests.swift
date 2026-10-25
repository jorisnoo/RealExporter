import Foundation
import ImageIO
import Testing
@testable import RealExporter

struct ExporterTests {
    @Test(arguments: ImageStyle.allCases)
    func sameTimestampPreservesPhotosAndCommentReferences(style: ImageStyle) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try TestFixtures.makeImage()
        for name in ["a.webp", "b.webp", "front.webp"] {
            try TestFixtures.writeImage(image, to: root.appendingPathComponent(name))
        }
        let posts = [
            TestFixtures.makePost(primaryPath: "b.webp", secondaryPath: "front.webp", caption: "second"),
            TestFixtures.makePost(primaryPath: "a.webp", secondaryPath: "front.webp", caption: "first"),
        ]
        let data = TestFixtures.makeBeRealExport(posts: posts, comments: [
            Comment(postId: "a", content: "first comment"),
            Comment(postId: "b", content: "second comment"),
        ], baseURL: root)
        var options = ExportOptions()
        options.imageStyle = style
        options.folderStructure = .flat
        options.includeComments = true
        options.destinationURL = root.appendingPathComponent("output")
        var completed = 0
        try await Exporter.export(data: data, options: options) { completed = $0.current }
        #expect(completed == 2)
        let output = try #require(options.destinationURL)
        let files = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
        let photos = files.filter { $0.pathExtension == "jpg" }
        #expect(photos.count == (style == .both ? 8 : 4))
        var captions: [String: Int] = [:]
        for photo in photos {
            let source = try #require(CGImageSourceCreateWithURL(photo as CFURL, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
            let exif = try #require(properties[kCGImagePropertyExifDictionary as String] as? [String: Any])
            let caption = try #require(exif[kCGImagePropertyExifUserComment as String] as? String)
            captions[caption, default: 0] += 1
        }
        #expect(captions["first"] == photos.count / 2)
        #expect(captions["second"] == photos.count / 2)
        let formatter = ExportDateFormat.fileNameFormatter()
        let base = "bereal_\(formatter.string(from: posts[0].takenAt))"
        let comments = try String(contentsOf: output.appendingPathComponent("comments.txt"), encoding: .utf8)
        #expect(comments.contains("\(base):\n  - first comment"))
        #expect(comments.contains("\(base)_2:\n  - second comment"))
    }

    @Test func sameTimestampPreservesVideosAndBts() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var posts: [Post] = []
        var expected = Set<Data>()
        for index in 1...2 {
            for suffix in ["back", "front", "bts"] {
                let name = "\(index)_\(suffix).mp4"
                let bytes = Data(name.utf8)
                expected.insert(bytes)
                try bytes.write(to: root.appendingPathComponent(name))
            }
            posts.append(TestFixtures.makePost(
                primaryPath: "\(index)_back.mp4", secondaryPath: "\(index)_front.mp4",
                btsMedia: TestFixtures.makeMediaReference(path: "\(index)_bts.mp4", mediaType: "video"),
                primaryMediaType: "video", secondaryMediaType: "video"
            ))
        }
        var options = ExportOptions()
        options.folderStructure = .flat
        options.destinationURL = root.appendingPathComponent("output")
        try await Exporter.export(data: TestFixtures.makeBeRealExport(posts: posts, baseURL: root), options: options) { _ in }
        let files = try FileManager.default.contentsOfDirectory(at: options.destinationURL!, includingPropertiesForKeys: nil)
        #expect(files.count == 6)
        #expect(try Set(files.map { try Data(contentsOf: $0) }) == expected)
    }

    @Test func chatPhotosWithSameTimestampAreAllExported() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try TestFixtures.makeImage()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var chatImages: [ConversationImage] = []
        for (conversation, filename, imageDate) in [("c1", "m1-a.webp", date), ("c1", "m1-b.webp", date), ("c2", "photo.webp", nil), ("c3", "photo.webp", nil)] as [(String, String, Date?)] {
            let url = root.appendingPathComponent("\(conversation)_\(filename).png")
            try TestFixtures.writeImage(image, to: url)
            chatImages.append(ConversationImage(id: "\(conversation)_\(filename)", url: url, conversationId: conversation, filename: filename, date: imageDate))
        }
        var options = ExportOptions()
        options.destinationURL = root.appendingPathComponent("output")
        let result = try await Exporter.export(
            data: TestFixtures.makeBeRealExport(conversationImages: chatImages, baseURL: root),
            options: options
        ) { _ in }
        #expect(result == ExportResult(beReals: 0, videos: 0, chatPhotos: 4))
        let folder = options.destinationURL!.appendingPathComponent("Conversations")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        let stamp = ExportDateFormat.fileNameFormatter().string(from: date)
        #expect(names == ["chat_\(stamp).jpg", "chat_\(stamp)_2.jpg", "chat_c2_photo.jpg", "chat_c3_photo.jpg"])
        // Undated chat photos must not be stamped with the export date.
        let source = try #require(CGImageSourceCreateWithURL(folder.appendingPathComponent("chat_c2_photo.jpg") as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal as String] == nil)
    }

    @Test func commentsOnVideoPostsAreWritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["clip.mp4", "clip_front.mp4"] {
            try Data(name.utf8).write(to: root.appendingPathComponent(name))
        }
        let post = TestFixtures.makePost(
            primaryPath: "clip.mp4", secondaryPath: "clip_front.mp4",
            primaryMediaType: "video", secondaryMediaType: "video"
        )
        let data = TestFixtures.makeBeRealExport(posts: [post], comments: [Comment(postId: "clip", content: "nice")], baseURL: root)
        #expect(data.filteredComments(startDate: nil, endDate: nil).count == 1)
        var options = ExportOptions()
        options.folderStructure = .flat
        options.destinationURL = root.appendingPathComponent("output")
        let result = try await Exporter.export(data: data, options: options) { _ in }
        #expect(result.videos == 1)
        let comments = try String(contentsOf: options.destinationURL!.appendingPathComponent("comments.txt"), encoding: .utf8)
        #expect(comments.contains("  - nice"))
    }

    @Test func emptyDateRangeThrows() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try TestFixtures.makeImage()
        try TestFixtures.writeImage(image, to: root.appendingPathComponent("a.webp"))
        let post = TestFixtures.makePost(primaryPath: "a.webp", secondaryPath: "a.webp", takenAt: Date(timeIntervalSince1970: 1_700_000_000))
        var options = ExportOptions()
        options.destinationURL = root.appendingPathComponent("output")
        options.startDate = Date(timeIntervalSince1970: 1_800_000_000)
        options.endDate = Date(timeIntervalSince1970: 1_800_000_000)
        await #expect(throws: ExporterError.nothingToExport) {
            try await Exporter.export(data: TestFixtures.makeBeRealExport(posts: [post], baseURL: root), options: options) { _ in }
        }
    }

    @Test(arguments: ImageStyle.allCases, [OverlayPosition.auto, .all])
    func previewMatchesExportedFiles(style: ImageStyle, position: OverlayPosition) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try TestFixtures.makeImage()
        let back = root.appendingPathComponent("back.webp")
        let front = root.appendingPathComponent("front.webp")
        try TestFixtures.writeImage(image, to: back)
        try TestFixtures.writeImage(image, to: front)
        try ImageProcessor.processAndSave(
            backPath: back, frontPath: front, outputPath: root.appendingPathComponent("out.jpg"),
            style: style, overlayPosition: position, metadata: ExportMetadata(date: nil, location: nil, caption: nil)
        )
        let written = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("out") }
        let preview = try ImageProcessor.previewOutputs(
            backPath: back, frontPath: front, style: style, overlayPosition: position, maxPixelSize: 40
        )
        #expect(Set(preview.map { "out\($0.suffix).jpg" }) == Set(written))
        #expect(preview.allSatisfy { max($0.image.width, $0.image.height) <= 40 })
    }

    @Test func exportFolderIsNumberedWhenNameIsTaken() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try Exporter.makeExportFolder(in: root, date: date)
        let second = try Exporter.makeExportFolder(in: root, date: date)
        #expect(first != second)
        #expect(second.lastPathComponent == first.lastPathComponent + " 2")
    }
}
