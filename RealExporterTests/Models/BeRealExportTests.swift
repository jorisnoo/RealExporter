import Foundation
import Testing
@testable import RealExporter

struct BeRealExportTests {
    // MARK: - uniqueBeRealCount

    @Test func uniqueBeRealCountWithEmptyData() {
        let export = TestFixtures.makeBeRealExport()
        #expect(export.uniqueBeRealCount == 0)
    }

    @Test func uniqueBeRealCountExcludesVideoPosts() {
        let videoPost = TestFixtures.makePost(primaryMediaType: "video")
        let export = TestFixtures.makeBeRealExport(posts: [videoPost])
        #expect(export.uniqueBeRealCount == 0)
    }

    @Test func uniqueBeRealCountCountsImagePosts() {
        let post1 = TestFixtures.makePost(primaryPath: "Photos/post/a.jpg")
        let post2 = TestFixtures.makePost(primaryPath: "Photos/post/b.jpg")
        let export = TestFixtures.makeBeRealExport(posts: [post1, post2])
        #expect(export.uniqueBeRealCount == 2)
    }

    @Test func uniqueBeRealCountDeduplicatesAcrossPostsAndMemories() {
        let post = TestFixtures.makePost(primaryPath: "Photos/shared/image.jpg")
        let memory = TestFixtures.makeMemory(backImagePath: "Photos/shared/image.jpg")
        let export = TestFixtures.makeBeRealExport(posts: [post], memories: [memory])
        #expect(export.uniqueBeRealCount == 1)
    }

    @Test func uniqueBeRealCountCountsBothPostsAndMemories() {
        let post = TestFixtures.makePost(primaryPath: "Photos/post/a.jpg")
        let memory = TestFixtures.makeMemory(backImagePath: "Photos/memory/b.jpg")
        let export = TestFixtures.makeBeRealExport(posts: [post], memories: [memory])
        #expect(export.uniqueBeRealCount == 2)
    }

    // MARK: - uniqueVideoCount

    @Test func uniqueVideoCountWithEmptyData() {
        let export = TestFixtures.makeBeRealExport()
        #expect(export.uniqueVideoCount == 0)
    }

    @Test func uniqueVideoCountCountsVideoPosts() {
        let post = TestFixtures.makePost(
            primaryPath: "Photos/post/video.mp4",
            primaryMediaType: "video"
        )
        let export = TestFixtures.makeBeRealExport(posts: [post])
        #expect(export.uniqueVideoCount == 1)
    }

    @Test func uniqueVideoCountCountsBtsMedia() {
        let bts = TestFixtures.makeMediaReference(path: "Photos/bts/video.mp4", mediaType: "video")
        let post = TestFixtures.makePost(btsMedia: bts)
        let export = TestFixtures.makeBeRealExport(posts: [post])
        #expect(export.uniqueVideoCount == 1)
    }

    @Test func uniqueVideoCountCountsMemoryVideos() {
        let memory = TestFixtures.makeMemory(frontMediaType: "video")
        let export = TestFixtures.makeBeRealExport(memories: [memory])
        #expect(export.uniqueVideoCount == 1)
    }

    // MARK: - dateRange

    @Test func dateRangeWithEmptyData() {
        let export = TestFixtures.makeBeRealExport()
        #expect(export.dateRange == nil)
    }

    @Test func dateRangeSpansPostsAndMemories() {
        let earlyDate = Date(timeIntervalSince1970: 1_600_000_000)
        let lateDate = Date(timeIntervalSince1970: 1_800_000_000)
        let post = TestFixtures.makePost(takenAt: earlyDate)
        let memory = TestFixtures.makeMemory(takenTime: lateDate)
        let export = TestFixtures.makeBeRealExport(posts: [post], memories: [memory])
        let range = export.dateRange
        #expect(range?.lowerBound == earlyDate)
        #expect(range?.upperBound == lateDate)
    }

    @Test func dateRangeWithOnlyPosts() {
        let date1 = Date(timeIntervalSince1970: 1_600_000_000)
        let date2 = Date(timeIntervalSince1970: 1_700_000_000)
        let export = TestFixtures.makeBeRealExport(posts: [
            TestFixtures.makePost(takenAt: date1),
            TestFixtures.makePost(primaryPath: "Photos/post/b.jpg", takenAt: date2),
        ])
        let range = export.dateRange
        #expect(range?.lowerBound == date1)
        #expect(range?.upperBound == date2)
    }
}
