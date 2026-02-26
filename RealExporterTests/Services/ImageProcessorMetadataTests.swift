import Foundation
import ImageIO
import Testing
@testable import RealExporter

struct ImageProcessorMetadataTests {
    // MARK: - Date formatting

    @Test func dateFormattedAsExifString() {
        let date = Date(timeIntervalSince1970: 1_705_312_800)
        let metadata = ExportMetadata(date: date, location: nil, caption: nil)
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let dateString = exifDict?[kCGImagePropertyExifDateTimeOriginal as String] as? String

        #expect(dateString != nil)
        let parts = dateString!.split(separator: " ")
        #expect(parts.count == 2)
        #expect(parts[0].contains(":"))
        #expect(parts[1].contains(":"))
    }

    // MARK: - GPS coordinates

    @Test func gpsNorthEastCoordinates() {
        let location = Location(latitude: 48.8566, longitude: 2.3522)
        let metadata = ExportMetadata(date: Date(), location: location, caption: nil)
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let gpsDict = props[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        #expect(gpsDict != nil)
        #expect(gpsDict?[kCGImagePropertyGPSLatitude as String] as? Double == 48.8566)
        #expect(gpsDict?[kCGImagePropertyGPSLatitudeRef as String] as? String == "N")
        #expect(gpsDict?[kCGImagePropertyGPSLongitude as String] as? Double == 2.3522)
        #expect(gpsDict?[kCGImagePropertyGPSLongitudeRef as String] as? String == "E")
    }

    @Test func gpsSouthernHemisphere() {
        let location = Location(latitude: -33.8688, longitude: 151.2093)
        let metadata = ExportMetadata(date: Date(), location: location, caption: nil)
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let gpsDict = props[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        #expect(gpsDict?[kCGImagePropertyGPSLatitudeRef as String] as? String == "S")
        #expect(gpsDict?[kCGImagePropertyGPSLatitude as String] as? Double == 33.8688)
    }

    @Test func gpsWesternHemisphere() {
        let location = Location(latitude: 40.7128, longitude: -74.0060)
        let metadata = ExportMetadata(date: Date(), location: location, caption: nil)
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let gpsDict = props[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        #expect(gpsDict?[kCGImagePropertyGPSLongitudeRef as String] as? String == "W")
        #expect(gpsDict?[kCGImagePropertyGPSLongitude as String] as? Double == 74.0060)
    }

    // MARK: - Caption

    @Test func captionIncludedInExif() {
        let metadata = ExportMetadata(date: Date(), location: nil, caption: "Beautiful sunset")
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiffDict = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        #expect(exifDict?[kCGImagePropertyExifUserComment as String] as? String == "Beautiful sunset")
        #expect(tiffDict?[kCGImagePropertyTIFFImageDescription as String] as? String == "Beautiful sunset")
    }

    @Test func emptyCaptionOmitted() {
        let metadata = ExportMetadata(date: Date(), location: nil, caption: "")
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        #expect(exifDict?[kCGImagePropertyExifUserComment as String] == nil)
    }

    @Test func nilCaptionOmitted() {
        let metadata = ExportMetadata(date: Date(), location: nil, caption: nil)
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        #expect(exifDict?[kCGImagePropertyExifUserComment as String] == nil)
    }

    // MARK: - No location

    @Test func noLocationMeansNoGpsDictionary() {
        let metadata = ExportMetadata(date: Date(), location: nil, caption: nil)
        let props = ImageProcessor.buildExifProperties(metadata: metadata)

        let gpsDict = props[kCGImagePropertyGPSDictionary as String]
        #expect(gpsDict == nil)
    }
}
