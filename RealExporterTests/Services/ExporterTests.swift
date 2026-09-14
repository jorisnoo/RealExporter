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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
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
}
