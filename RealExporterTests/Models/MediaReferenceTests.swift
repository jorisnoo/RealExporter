import Foundation
import Testing
@testable import RealExporter

struct MediaReferenceTests {
    // MARK: - isVideo

    @Test func isVideoWithVideoMediaType() {
        let ref = TestFixtures.makeMediaReference(mediaType: "video")
        #expect(ref.isVideo == true)
    }

    @Test func isVideoWithVideoMimeType() {
        let ref = TestFixtures.makeMediaReference(mimeType: "video/mp4")
        #expect(ref.isVideo == true)
    }

    @Test func isVideoWithImageMediaType() {
        let ref = TestFixtures.makeMediaReference(mediaType: "image")
        #expect(ref.isVideo == false)
    }

    @Test func isVideoWithNilTypes() {
        let ref = TestFixtures.makeMediaReference()
        #expect(ref.isVideo == false)
    }

    // MARK: - filename

    @Test func filenameExtractsLastPathComponent() {
        let ref = TestFixtures.makeMediaReference(path: "Photos/user123/post/image.jpg")
        #expect(ref.filename == "image.jpg")
    }

    // MARK: - localPath

    @Test(arguments: [
        ("Photos/userId/subfolder/file.jpg", "Photos/subfolder/file.jpg"),
        ("/Photos/userId/subfolder/file.jpg", "Photos/subfolder/file.jpg"),
        ("Photos/short.jpg", "Photos/short.jpg"),
        ("Photos/a/b.jpg", "Photos/a/b.jpg"),
        ("simple.jpg", "simple.jpg"),
    ])
    func localPathResolution(input: String, expected: String) {
        let ref = TestFixtures.makeMediaReference(path: input)
        let base = URL(fileURLWithPath: "/tmp/test")
        let result = ref.localPath(relativeTo: base)
        #expect(result.path == "/tmp/test/\(expected)")
    }
}
