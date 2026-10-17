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

    @Test func dateUsesGregorianYearAndIncludesOffset() throws {
        let date = Date(timeIntervalSince1970: 1_705_312_800) // 15 Jan 2024
        let props = ImageProcessor.buildExifProperties(metadata: ExportMetadata(date: date, location: nil, caption: nil))
        let exif = try #require(props[kCGImagePropertyExifDictionary as String] as? [String: Any])
        let dateString = try #require(exif[kCGImagePropertyExifDateTimeOriginal as String] as? String)
        #expect(dateString.hasPrefix("2024:01:1"))
        let offset = try #require(exif[kCGImagePropertyExifOffsetTimeOriginal as String] as? String)
        #expect(offset.wholeMatch(of: /[+-]\d{2}:\d{2}/) != nil)
    }

    @Test func missingDateOmitsDateFields() {
        let props = ImageProcessor.buildExifProperties(metadata: ExportMetadata(date: nil, location: nil, caption: nil))
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal as String] == nil)
        #expect(tiff?[kCGImagePropertyTIFFDateTime as String] == nil)
    }

    @Test(arguments: [(0, "+00:00"), (19_800, "+05:30"), (-12_600, "-03:30")])
    func exifOffsetFormatting(seconds: Int, expected: String) throws {
        let zone = try #require(TimeZone(secondsFromGMT: seconds))
        #expect(ExportDateFormat.exifOffset(for: Date(), in: zone) == expected)
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
