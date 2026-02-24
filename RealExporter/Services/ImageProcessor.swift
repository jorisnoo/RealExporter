import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessorError: LocalizedError {
    case failedToLoadImage(String)
    case failedToCreateContext
    case failedToCreateImage
    case failedToWriteImage

    var errorDescription: String? {
        switch self {
        case .failedToLoadImage(let path):
            return "Failed to load image: \(path)"
        case .failedToCreateContext:
            return "Failed to create graphics context."
        case .failedToCreateImage:
            return "Failed to create combined image."
        case .failedToWriteImage:
            return "Failed to write output image."
        }
    }
}

struct ExportMetadata {
    let date: Date
    let location: Location?
    let caption: String?
}

enum ImageProcessor {
    static func processAndSave(
        backPath: URL,
        frontPath: URL,
        outputPath: URL,
        style: ImageStyle,
        metadata: ExportMetadata
    ) throws {
        switch style {
        case .combined:
            try saveCombinedImage(
                backPath: backPath,
                frontPath: frontPath,
                outputPath: outputPath,
                metadata: metadata
            )
        case .separate:
            try saveSeparateImages(
                backPath: backPath,
                frontPath: frontPath,
                outputPath: outputPath,
                metadata: metadata
            )
        case .both:
            try saveSeparateImages(
                backPath: backPath,
                frontPath: frontPath,
                outputPath: outputPath,
                metadata: metadata
            )
            try saveCombinedImage(
                backPath: backPath,
                frontPath: frontPath,
                outputPath: outputPath,
                metadata: metadata
            )
        }
    }

    private static func saveCombinedImage(
        backPath: URL,
        frontPath: URL,
        outputPath: URL,
        metadata: ExportMetadata
    ) throws {
        guard let backImage = loadImage(from: backPath) else {
            throw ImageProcessorError.failedToLoadImage(backPath.path)
        }
        guard let frontImage = loadImage(from: frontPath) else {
            throw ImageProcessorError.failedToLoadImage(frontPath.path)
        }

        let baseName = outputPath.deletingPathExtension().lastPathComponent
        let directory = outputPath.deletingLastPathComponent()

        let backOutputPath = directory.appendingPathComponent("\(baseName)_combined_back.jpg")
        let frontOutputPath = directory.appendingPathComponent("\(baseName)_combined_front.jpg")

        let backAsBg = try stitchImages(back: backImage, front: frontImage)
        try saveAsJPEG(image: backAsBg, to: backOutputPath, metadata: metadata)

        let frontAsBg = try stitchImages(back: frontImage, front: backImage)
        try saveAsJPEG(image: frontAsBg, to: frontOutputPath, metadata: metadata)
    }

    private static func saveSeparateImages(
        backPath: URL,
        frontPath: URL,
        outputPath: URL,
        metadata: ExportMetadata
    ) throws {
        let baseName = outputPath.deletingPathExtension().lastPathComponent
        let directory = outputPath.deletingLastPathComponent()

        let backOutputPath = directory.appendingPathComponent("\(baseName)_back.jpg")
        let frontOutputPath = directory.appendingPathComponent("\(baseName)_front.jpg")

        guard let backImage = loadImage(from: backPath) else {
            throw ImageProcessorError.failedToLoadImage(backPath.path)
        }
        guard let frontImage = loadImage(from: frontPath) else {
            throw ImageProcessorError.failedToLoadImage(frontPath.path)
        }

        try saveAsJPEG(image: backImage, to: backOutputPath, metadata: metadata)
        try saveAsJPEG(image: frontImage, to: frontOutputPath, metadata: metadata)
    }

    private static func loadImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    private static func stitchImages(back: CGImage, front: CGImage) throws -> CGImage {
        let width = back.width
        let height = back.height

        guard front.width > 0 else {
            throw ImageProcessorError.failedToLoadImage("Front image has zero width")
        }

        let overlayWidth = width / 3
        let overlayHeight = Int(Double(overlayWidth) * (Double(front.height) / Double(front.width)))

        let padding = width / 30
        let cornerRadius = overlayWidth / 12
        let borderWidth = max(2, width / 200)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageProcessorError.failedToCreateContext
        }

        context.draw(back, in: CGRect(x: 0, y: 0, width: width, height: height))

        let overlayX = CGFloat(padding)
        let overlayY = CGFloat(height - overlayHeight - padding)
        let overlayRect = CGRect(
            x: overlayX,
            y: overlayY,
            width: CGFloat(overlayWidth),
            height: CGFloat(overlayHeight)
        )

        let borderRect = overlayRect.insetBy(dx: CGFloat(-borderWidth), dy: CGFloat(-borderWidth))
        let borderPath = CGPath(
            roundedRect: borderRect,
            cornerWidth: CGFloat(cornerRadius + borderWidth),
            cornerHeight: CGFloat(cornerRadius + borderWidth),
            transform: nil
        )
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.addPath(borderPath)
        context.fillPath()

        let clipPath = CGPath(
            roundedRect: overlayRect,
            cornerWidth: CGFloat(cornerRadius),
            cornerHeight: CGFloat(cornerRadius),
            transform: nil
        )
        context.saveGState()
        context.addPath(clipPath)
        context.clip()
        context.draw(front, in: overlayRect)
        context.restoreGState()

        guard let result = context.makeImage() else {
            throw ImageProcessorError.failedToCreateImage
        }

        return result
    }

    private static func saveAsJPEG(image: CGImage, to url: URL, metadata: ExportMetadata) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageProcessorError.failedToWriteImage
        }

        let properties = buildExifProperties(metadata: metadata)

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        if !CGImageDestinationFinalize(destination) {
            throw ImageProcessorError.failedToWriteImage
        }
    }

    private static func buildExifProperties(metadata: ExportMetadata) -> [String: Any] {
        var properties: [String: Any] = [:]

        properties[kCGImageDestinationLossyCompressionQuality as String] = 0.9

        var exifDict: [String: Any] = [:]
        var tiffDict: [String: Any] = [:]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let dateString = formatter.string(from: metadata.date)

        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateString
        exifDict[kCGImagePropertyExifDateTimeDigitized as String] = dateString
        tiffDict[kCGImagePropertyTIFFDateTime as String] = dateString

        if let caption = metadata.caption, !caption.isEmpty {
            exifDict[kCGImagePropertyExifUserComment as String] = caption
            tiffDict[kCGImagePropertyTIFFImageDescription as String] = caption
        }

        properties[kCGImagePropertyExifDictionary as String] = exifDict
        properties[kCGImagePropertyTIFFDictionary as String] = tiffDict

        if let location = metadata.location {
            var gpsDict: [String: Any] = [:]

            gpsDict[kCGImagePropertyGPSLatitude as String] = abs(location.latitude)
            gpsDict[kCGImagePropertyGPSLatitudeRef as String] = location.latitude >= 0 ? "N" : "S"
            gpsDict[kCGImagePropertyGPSLongitude as String] = abs(location.longitude)
            gpsDict[kCGImagePropertyGPSLongitudeRef as String] = location.longitude >= 0 ? "E" : "W"

            properties[kCGImagePropertyGPSDictionary as String] = gpsDict
        }

        return properties
    }
}
