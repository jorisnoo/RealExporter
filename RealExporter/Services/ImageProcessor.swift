import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Vision

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
        overlayPosition: OverlayPosition,
        metadata: ExportMetadata
    ) throws {
        switch style {
        case .combined:
            try saveCombinedImage(
                backPath: backPath,
                frontPath: frontPath,
                outputPath: outputPath,
                overlayPosition: overlayPosition,
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
                overlayPosition: overlayPosition,
                metadata: metadata
            )
        }
    }

    private static func saveCombinedImage(
        backPath: URL,
        frontPath: URL,
        outputPath: URL,
        overlayPosition: OverlayPosition,
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

        if overlayPosition == .all {
            let corners: [OverlayPosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
            for corner in corners {
                let suffix = switch corner {
                case .topLeft: "topLeft"
                case .topRight: "topRight"
                case .bottomLeft: "bottomLeft"
                case .bottomRight: "bottomRight"
                default: "topLeft"
                }

                let backOutputPath = directory.appendingPathComponent("\(baseName)_combined_back_\(suffix).jpg")
                let frontOutputPath = directory.appendingPathComponent("\(baseName)_combined_front_\(suffix).jpg")

                let backAsBg = try stitchImages(back: backImage, front: frontImage, overlayPosition: corner)
                try saveAsJPEG(image: backAsBg, to: backOutputPath, metadata: metadata)

                let frontAsBg = try stitchImages(back: frontImage, front: backImage, overlayPosition: corner)
                try saveAsJPEG(image: frontAsBg, to: frontOutputPath, metadata: metadata)
            }
        } else {
            let backOutputPath = directory.appendingPathComponent("\(baseName)_combined_back.jpg")
            let frontOutputPath = directory.appendingPathComponent("\(baseName)_combined_front.jpg")

            let backAsBg = try stitchImages(back: backImage, front: frontImage, overlayPosition: overlayPosition)
            try saveAsJPEG(image: backAsBg, to: backOutputPath, metadata: metadata)

            let frontAsBg = try stitchImages(back: frontImage, front: backImage, overlayPosition: overlayPosition)
            try saveAsJPEG(image: frontAsBg, to: frontOutputPath, metadata: metadata)
        }
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

    static func convertToJPEG(source: URL, destination: URL, date: Date?) throws {
        guard let image = loadImage(from: source) else {
            throw ImageProcessorError.failedToLoadImage(source.path)
        }
        let metadata = ExportMetadata(
            date: date ?? Date(),
            location: nil,
            caption: nil
        )
        try saveAsJPEG(image: image, to: destination, metadata: metadata)
    }

    private static func loadImage(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    private static func extractLuminance(from image: CGImage, width targetWidth: Int, height targetHeight: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        guard let context = CGContext(
            data: &buffer,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return buffer
    }

    private static func regionVariance(
        data: [UInt8],
        imageWidth: Int,
        regionX: Int,
        regionY: Int,
        regionWidth: Int,
        regionHeight: Int
    ) -> Double {
        let maxX = min(regionX + regionWidth, imageWidth)
        let maxY = min(regionY + regionHeight, data.count / imageWidth)
        let x0 = max(regionX, 0)
        let y0 = max(regionY, 0)

        var sum = 0
        var sumSq = 0
        var count = 0

        for y in y0..<maxY {
            let rowOffset = y * imageWidth
            for x in x0..<maxX {
                let v = Int(data[rowOffset + x])
                sum += v
                sumSq += v * v
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        let mean = Double(sum) / Double(count)
        let meanSq = Double(sumSq) / Double(count)
        return meanSq - mean * mean
    }

    private static func averageSaliency(
        buffer: UnsafePointer<Float32>,
        mapWidth: Int,
        mapHeight: Int,
        bytesPerRow: Int,
        regionX: Int, regionY: Int,
        regionWidth: Int, regionHeight: Int
    ) -> Float {
        let stride = bytesPerRow / MemoryLayout<Float32>.size
        let x0 = max(regionX, 0)
        let y0 = max(regionY, 0)
        let maxX = min(regionX + regionWidth, mapWidth)
        let maxY = min(regionY + regionHeight, mapHeight)

        var sum: Float = 0
        var count = 0

        for y in y0..<maxY {
            let rowOffset = y * stride
            for x in x0..<maxX {
                sum += buffer[rowOffset + x]
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        return sum / Float(count)
    }

    private static func saliencyScores(
        for image: CGImage,
        overlayWidth: Int, overlayHeight: Int,
        padding: Int
    ) -> [OverlayPosition: Float]? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else {
            return nil
        }

        let pixelBuffer = observation.pixelBuffer

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let mapWidth = CVPixelBufferGetWidth(pixelBuffer)
        let mapHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: Float32.self)

        let scaleX = Double(mapWidth) / Double(image.width)
        let scaleY = Double(mapHeight) / Double(image.height)

        let ow = Int(Double(overlayWidth) * scaleX)
        let oh = Int(Double(overlayHeight) * scaleY)
        let pad = Int(Double(padding) * scaleX)

        // Both CG and Vision use bottom-left origin
        let corners: [(OverlayPosition, Int, Int)] = [
            (.topLeft,     pad,                  mapHeight - oh - pad),
            (.topRight,    mapWidth - ow - pad,  mapHeight - oh - pad),
            (.bottomLeft,  pad,                  pad),
            (.bottomRight, mapWidth - ow - pad,  pad),
        ]

        var scores: [OverlayPosition: Float] = [:]
        for (pos, rx, ry) in corners {
            scores[pos] = averageSaliency(
                buffer: buffer,
                mapWidth: mapWidth, mapHeight: mapHeight,
                bytesPerRow: bytesPerRow,
                regionX: rx, regionY: ry,
                regionWidth: ow, regionHeight: oh
            )
        }

        return scores
    }

    private static func faceCornerScores(for image: CGImage) -> [OverlayPosition: Float] {
        var scores: [OverlayPosition: Float] = [
            .topLeft: 0, .topRight: 0, .bottomLeft: 0, .bottomRight: 0,
        ]

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image)

        do {
            try handler.perform([request])
        } catch {
            return scores
        }

        guard let results = request.results, !results.isEmpty else {
            return scores
        }

        for face in results {
            let box = face.boundingBox // normalised, bottom-left origin
            let centerX = box.midX
            let centerY = box.midY
            let area = Float(box.width * box.height) // larger face → stronger penalty

            // Map face center to the corner it falls in
            let position: OverlayPosition
            if centerX < 0.5 {
                position = centerY >= 0.5 ? .topLeft : .bottomLeft
            } else {
                position = centerY >= 0.5 ? .topRight : .bottomRight
            }

            scores[position, default: 0] += area
        }

        return scores
    }

    private static func bestCorner(
        for image: CGImage,
        overlayWidth: Int,
        overlayHeight: Int,
        padding: Int
    ) -> OverlayPosition {
        let faceScores = faceCornerScores(for: image)
        // Weight high enough that a face almost always pushes overlay away,
        // but saliency still resolves ties between face-free corners.
        let faceWeight: Float = 10.0

        // Prefer Vision saliency — pick the corner humans look at least
        if let saliency = saliencyScores(for: image, overlayWidth: overlayWidth, overlayHeight: overlayHeight, padding: padding) {
            var combined: [OverlayPosition: Float] = [:]
            for pos in [OverlayPosition.topLeft, .topRight, .bottomLeft, .bottomRight] {
                combined[pos] = (saliency[pos] ?? 0) + (faceScores[pos] ?? 0) * faceWeight
            }
            if let best = combined.min(by: { $0.value < $1.value }) {
                return best.key
            }
        }

        // Fallback: luminance variance (flattest corner)
        let targetWidth = 400
        let scale = Double(targetWidth) / Double(image.width)
        let targetHeight = Int(Double(image.height) * scale)

        guard let lum = extractLuminance(from: image, width: targetWidth, height: targetHeight) else {
            return .topLeft
        }

        let ow = Int(Double(overlayWidth) * scale)
        let oh = Int(Double(overlayHeight) * scale)
        let pad = Int(Double(padding) * scale)

        // CG bottom-left origin: top = high Y, bottom = low Y
        let corners: [(OverlayPosition, Int, Int)] = [
            (.topLeft,     pad,                        targetHeight - oh - pad),
            (.topRight,    targetWidth - ow - pad,     targetHeight - oh - pad),
            (.bottomLeft,  pad,                        pad),
            (.bottomRight, targetWidth - ow - pad,     pad),
        ]

        var bestPos: OverlayPosition = .topLeft
        var bestVariance = Double.infinity

        for (pos, rx, ry) in corners {
            let v = regionVariance(data: lum, imageWidth: targetWidth, regionX: rx, regionY: ry, regionWidth: ow, regionHeight: oh)
            let facePenalty = Double(faceScores[pos] ?? 0) * Double(faceWeight) * 1000
            let adjusted = v + facePenalty
            if adjusted < bestVariance {
                bestVariance = adjusted
                bestPos = pos
            }
        }

        return bestPos
    }

    private static func stitchImages(back: CGImage, front: CGImage, overlayPosition: OverlayPosition) throws -> CGImage {
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

        let resolvedPosition: OverlayPosition = if overlayPosition == .auto {
            bestCorner(for: back, overlayWidth: overlayWidth, overlayHeight: overlayHeight, padding: padding)
        } else {
            overlayPosition
        }

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

        // CG uses bottom-left origin, so top = high Y, bottom = low Y
        let overlayX: CGFloat
        let overlayY: CGFloat
        switch resolvedPosition {
        case .auto:
            // Already resolved above; fallback to topLeft
            overlayX = CGFloat(padding)
            overlayY = CGFloat(height - overlayHeight - padding)
        case .topLeft:
            overlayX = CGFloat(padding)
            overlayY = CGFloat(height - overlayHeight - padding)
        case .topRight:
            overlayX = CGFloat(width - overlayWidth - padding)
            overlayY = CGFloat(height - overlayHeight - padding)
        case .bottomLeft:
            overlayX = CGFloat(padding)
            overlayY = CGFloat(padding)
        case .bottomRight:
            overlayX = CGFloat(width - overlayWidth - padding)
            overlayY = CGFloat(padding)
        case .all:
            overlayX = CGFloat(padding)
            overlayY = CGFloat(height - overlayHeight - padding)
        }
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
