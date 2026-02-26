import Testing
@testable import RealExporter

struct PostTests {
    @Test func idUsesPrimaryFilename() {
        let post = TestFixtures.makePost(primaryPath: "Photos/post/my_photo.jpg")
        #expect(post.id == "my_photo.jpg")
    }

    @Test func hasBothImagesWhenBothAreImages() {
        let post = TestFixtures.makePost()
        #expect(post.hasBothImages == true)
    }

    @Test func hasBothImagesIsFalseWhenPrimaryIsVideo() {
        let post = TestFixtures.makePost(primaryMediaType: "video")
        #expect(post.hasBothImages == false)
    }

    @Test func hasBothImagesIsFalseWhenSecondaryIsVideo() {
        let post = TestFixtures.makePost(secondaryMediaType: "video")
        #expect(post.hasBothImages == false)
    }

    @Test func hasVideoWhenPrimaryIsVideo() {
        let post = TestFixtures.makePost(primaryMediaType: "video")
        #expect(post.hasVideo == true)
    }

    @Test func hasVideoWhenSecondaryIsVideo() {
        let post = TestFixtures.makePost(secondaryMediaType: "video")
        #expect(post.hasVideo == true)
    }

    @Test func hasVideoWhenBtsMediaPresent() {
        let bts = TestFixtures.makeMediaReference(path: "Photos/bts/video.mp4", mediaType: "video")
        let post = TestFixtures.makePost(btsMedia: bts)
        #expect(post.hasVideo == true)
    }

    @Test func hasVideoIsFalseWhenAllImages() {
        let post = TestFixtures.makePost()
        #expect(post.hasVideo == false)
    }
}
