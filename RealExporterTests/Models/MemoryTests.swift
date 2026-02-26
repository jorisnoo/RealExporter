import Testing
@testable import RealExporter

struct MemoryTests {
    // MARK: - frontImageForExport

    @Test func frontImageForExportReturnsPlaceholderWhenFrontIsVideo() {
        let placeholder = TestFixtures.makeMediaReference(path: "Photos/placeholder/front_placeholder.jpg")
        let memory = TestFixtures.makeMemory(
            primaryPlaceholder: placeholder,
            frontMediaType: "video"
        )
        #expect(memory.frontImageForExport.path == placeholder.path)
    }

    @Test func frontImageForExportReturnsOriginalWhenImage() {
        let memory = TestFixtures.makeMemory(frontImagePath: "Photos/memory/front.jpg")
        #expect(memory.frontImageForExport.path == "Photos/memory/front.jpg")
    }

    @Test func frontImageForExportReturnsVideoWhenNoPlaceholder() {
        let memory = TestFixtures.makeMemory(frontMediaType: "video")
        #expect(memory.frontImageForExport.isVideo == true)
    }

    // MARK: - backImageForExport

    @Test func backImageForExportReturnsPlaceholderWhenBackIsVideo() {
        let placeholder = TestFixtures.makeMediaReference(path: "Photos/placeholder/back_placeholder.jpg")
        let memory = TestFixtures.makeMemory(
            secondaryPlaceholder: placeholder,
            backMediaType: "video"
        )
        #expect(memory.backImageForExport.path == placeholder.path)
    }

    @Test func backImageForExportReturnsOriginalWhenImage() {
        let memory = TestFixtures.makeMemory(backImagePath: "Photos/memory/back.jpg")
        #expect(memory.backImageForExport.path == "Photos/memory/back.jpg")
    }

    @Test func backImageForExportReturnsVideoWhenNoPlaceholder() {
        let memory = TestFixtures.makeMemory(backMediaType: "video")
        #expect(memory.backImageForExport.isVideo == true)
    }

    // MARK: - hasBothImages / hasVideo

    @Test func hasBothImagesWhenBothAreImages() {
        let memory = TestFixtures.makeMemory()
        #expect(memory.hasBothImages == true)
    }

    @Test func hasBothImagesIsFalseWhenFrontIsVideo() {
        let memory = TestFixtures.makeMemory(frontMediaType: "video")
        #expect(memory.hasBothImages == false)
    }

    @Test func hasVideoWhenFrontIsVideo() {
        let memory = TestFixtures.makeMemory(frontMediaType: "video")
        #expect(memory.hasVideo == true)
    }

    @Test func hasVideoWhenBtsMediaPresent() {
        let bts = TestFixtures.makeMediaReference(path: "Photos/bts.mp4", mediaType: "video")
        let memory = TestFixtures.makeMemory(btsMedia: bts)
        #expect(memory.hasVideo == true)
    }

    @Test func hasVideoIsFalseWhenAllImages() {
        let memory = TestFixtures.makeMemory()
        #expect(memory.hasVideo == false)
    }
}
