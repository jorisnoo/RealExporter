import Foundation
import Testing
@testable import RealExporter

struct ExportOptionsTests {
    @Test func isValidWithDestinationURL() {
        var options = ExportOptions()
        options.destinationURL = URL(fileURLWithPath: "/tmp/output")
        #expect(options.isValid == true)
    }

    @Test func isValidWithoutDestinationURL() {
        let options = ExportOptions()
        #expect(options.isValid == false)
    }

    @Test func defaultValues() {
        let options = ExportOptions()
        #expect(options.imageStyle == .both)
        #expect(options.overlayPosition == .auto)
        #expect(options.folderStructure == .byDate)
        #expect(options.includeConversations == true)
        #expect(options.includeComments == true)
        #expect(options.destinationURL == nil)
    }
}
