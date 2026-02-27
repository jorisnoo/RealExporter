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

            let backPosition = overlayPosition == .auto
                ? resolveAutoPosition(background: backImage, overlay: frontImage)
                : overlayPosition
            let frontPosition = overlayPosition == .auto
                ? resolveAutoPosition(background: frontImage, overlay: backImage)
                : overlayPosition

            let backAsBg = try stitchImages(back: backImage, front: frontImage, overlayPosition: backPosition)
            try saveAsJPEG(image: backAsBg, to: backOutputPath, metadata: metadata)

            let frontAsBg = try stitchImages(back: frontImage, front: backImage, overlayPosition: frontPosition)
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

    private static func runVisionAnalysis(for image: CGImage) -> (
        attentionSaliency: VNSaliencyImageObservation?,
        objectnessSaliency: VNSaliencyImageObservation?,
        faces: [VNFaceObservation],
        bodies: [VNHumanObservation],
        animals: [VNRecognizedObjectObservation],
        textObservations: [VNRecognizedTextObservation]
    ) {
        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        let faceRequest = VNDetectFaceRectanglesRequest()
        let bodyRequest = VNDetectHumanRectanglesRequest()
        let animalRequest = VNRecognizeAnimalsRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast

        let handler = VNImageRequestHandler(cgImage: image)

        do {
            try handler.perform([attentionRequest, objectnessRequest, faceRequest, bodyRequest, animalRequest, textRequest])
        } catch {
            return (nil, nil, [], [], [], [])
        }

        let attention = attentionRequest.results?.first
        let objectness = objectnessRequest.results?.first
        let faces = faceRequest.results ?? []
        let bodies = bodyRequest.results ?? []
        let animals = animalRequest.results ?? []
        let textObservations = textRequest.results ?? []
        return (attention, objectness, faces, bodies, animals, textObservations)
    }

    private static func saliencyScoresFromObservation(
        _ observation: VNSaliencyImageObservation,
        image: CGImage,
        overlayWidth: Int, overlayHeight: Int,
        padding: Int
    ) -> [OverlayPosition: Float]? {
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

    private static func faceOverlapScores(
        faces: [VNFaceObservation],
        overlayWidth: Int,
        overlayHeight: Int,
        imageWidth: Int,
        imageHeight: Int,
        padding: Int
    ) -> [OverlayPosition: Float] {
        var scores: [OverlayPosition: Float] = [
            .topLeft: 0, .topRight: 0, .bottomLeft: 0, .bottomRight: 0,
        ]

        guard !faces.isEmpty else { return scores }

        let ow = Double(overlayWidth) / Double(imageWidth)
        let oh = Double(overlayHeight) / Double(imageHeight)
        let padX = Double(padding) / Double(imageWidth)
        let padY = Double(padding) / Double(imageHeight)

        // Overlay rects in normalized coords (bottom-left origin, matching Vision)
        let cornerRects: [(OverlayPosition, CGRect)] = [
            (.topLeft,     CGRect(x: padX, y: 1 - oh - padY, width: ow, height: oh)),
            (.topRight,    CGRect(x: 1 - ow - padX, y: 1 - oh - padY, width: ow, height: oh)),
            (.bottomLeft,  CGRect(x: padX, y: padY, width: ow, height: oh)),
            (.bottomRight, CGRect(x: 1 - ow - padX, y: padY, width: ow, height: oh)),
        ]

        for face in faces {
            let faceRect = face.boundingBox
            let faceArea = faceRect.width * faceRect.height
            for (pos, overlayRect) in cornerRects {
                let intersection = overlayRect.intersection(faceRect)
                if !intersection.isNull {
                    let overlapRatio = (intersection.width * intersection.height) / faceArea
                    if overlapRatio > 0.15 {
                        scores[pos] = 1.0
                    }
                }
            }
        }

        return scores
    }

    private static func bodyOverlapScores(
        bodies: [VNHumanObservation],
        animals: [VNRecognizedObjectObservation],
        overlayWidth: Int,
        overlayHeight: Int,
        imageWidth: Int,
        imageHeight: Int,
        padding: Int
    ) -> [OverlayPosition: Float] {
        var scores: [OverlayPosition: Float] = [
            .topLeft: 0, .topRight: 0, .bottomLeft: 0, .bottomRight: 0,
        ]

        let allBoxes: [CGRect] = bodies.map(\.boundingBox) + animals.map(\.boundingBox)
        guard !allBoxes.isEmpty else { return scores }

        let ow = Double(overlayWidth) / Double(imageWidth)
        let oh = Double(overlayHeight) / Double(imageHeight)
        let padX = Double(padding) / Double(imageWidth)
        let padY = Double(padding) / Double(imageHeight)

        let cornerRects: [(OverlayPosition, CGRect)] = [
            (.topLeft,     CGRect(x: padX, y: 1 - oh - padY, width: ow, height: oh)),
            (.topRight,    CGRect(x: 1 - ow - padX, y: 1 - oh - padY, width: ow, height: oh)),
            (.bottomLeft,  CGRect(x: padX, y: padY, width: ow, height: oh)),
            (.bottomRight, CGRect(x: 1 - ow - padX, y: padY, width: ow, height: oh)),
        ]

        for box in allBoxes {
            for (pos, overlayRect) in cornerRects {
                let intersection = overlayRect.intersection(box)
                if !intersection.isNull {
                    scores[pos, default: 0] += Float(intersection.width * intersection.height)
                }
            }
        }

        return scores
    }

    private static func textOverlapScores(
        textObservations: [VNRecognizedTextObservation],
        overlayWidth: Int,
        overlayHeight: Int,
        imageWidth: Int,
        imageHeight: Int,
        padding: Int
    ) -> [OverlayPosition: Float] {
        var scores: [OverlayPosition: Float] = [
            .topLeft: 0, .topRight: 0, .bottomLeft: 0, .bottomRight: 0,
        ]

        guard !textObservations.isEmpty else { return scores }

        let ow = Double(overlayWidth) / Double(imageWidth)
        let oh = Double(overlayHeight) / Double(imageHeight)
        let padX = Double(padding) / Double(imageWidth)
        let padY = Double(padding) / Double(imageHeight)

        let cornerRects: [(OverlayPosition, CGRect)] = [
            (.topLeft,     CGRect(x: padX, y: 1 - oh - padY, width: ow, height: oh)),
            (.topRight,    CGRect(x: 1 - ow - padX, y: 1 - oh - padY, width: ow, height: oh)),
            (.bottomLeft,  CGRect(x: padX, y: padY, width: ow, height: oh)),
            (.bottomRight, CGRect(x: 1 - ow - padX, y: padY, width: ow, height: oh)),
        ]

        for text in textObservations {
            let textRect = text.boundingBox
            for (pos, overlayRect) in cornerRects {
                let intersection = overlayRect.intersection(textRect)
                if !intersection.isNull {
                    scores[pos, default: 0] += Float(intersection.width * intersection.height)
                }
            }
        }

        return scores
    }

    private static func bestCorner(
        for image: CGImage,
        overlayWidth: Int,
        overlayHeight: Int,
        padding: Int
    ) -> OverlayPosition {
        let analysis = runVisionAnalysis(for: image)
        let faceScores = faceOverlapScores(
            faces: analysis.faces,
            overlayWidth: overlayWidth,
            overlayHeight: overlayHeight,
            imageWidth: image.width,
            imageHeight: image.height,
            padding: padding
        )
        let bodyScores = bodyOverlapScores(
            bodies: analysis.bodies,
            animals: analysis.animals,
            overlayWidth: overlayWidth,
            overlayHeight: overlayHeight,
            imageWidth: image.width,
            imageHeight: image.height,
            padding: padding
        )
        let textScores = textOverlapScores(
            textObservations: analysis.textObservations,
            overlayWidth: overlayWidth,
            overlayHeight: overlayHeight,
            imageWidth: image.width,
            imageHeight: image.height,
            padding: padding
        )

        let faceWeight: Float = 10.0
        let bodyWeight: Float = 5.0
        let textWeight: Float = 3.0

        // Prefer Vision saliency — pick the corner humans look at least
        let attentionScores = analysis.attentionSaliency.flatMap {
            saliencyScoresFromObservation($0, image: image, overlayWidth: overlayWidth, overlayHeight: overlayHeight, padding: padding)
        }
        let objectnessScores = analysis.objectnessSaliency.flatMap {
            saliencyScoresFromObservation($0, image: image, overlayWidth: overlayWidth, overlayHeight: overlayHeight, padding: padding)
        }

        if attentionScores != nil || objectnessScores != nil {
            var combined: [OverlayPosition: Float] = [:]
            for pos in [OverlayPosition.topLeft, .topRight, .bottomLeft, .bottomRight] {
                let attScore = attentionScores?[pos] ?? 0
                let objScore = objectnessScores?[pos] ?? 0
                let saliencyAvg: Float
                if attentionScores != nil && objectnessScores != nil {
                    saliencyAvg = (attScore + objScore) / 2.0
                } else {
                    saliencyAvg = attScore + objScore
                }
                combined[pos] = saliencyAvg
                    + (faceScores[pos] ?? 0) * faceWeight
                    + (bodyScores[pos] ?? 0) * bodyWeight
                    + (textScores[pos] ?? 0) * textWeight
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
            let bodyPenalty = Double(bodyScores[pos] ?? 0) * Double(bodyWeight) * 1000
            let textPenalty = Double(textScores[pos] ?? 0) * Double(textWeight) * 1000
            let adjusted = v + facePenalty + bodyPenalty + textPenalty
            if adjusted < bestVariance {
                bestVariance = adjusted
                bestPos = pos
            }
        }

        return bestPos
    }

    private static func resolveAutoPosition(background: CGImage, overlay: CGImage) -> OverlayPosition {
        let overlayWidth = background.width / 3
        let overlayHeight = Int(Double(overlayWidth) * (Double(overlay.height) / Double(overlay.width)))
        let padding = background.width / 30
        return bestCorner(for: background, overlayWidth: overlayWidth, overlayHeight: overlayHeight, padding: padding)
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
        switch overlayPosition {
        case .topLeft, .auto, .all:
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
        }
        let overlayRect = CGRect(
            x: overlayX,
            y: overlayY,
            width: CGFloat(overlayWidth),
            height: CGFloat(overlayHeight)
        )

        let clipPath = CGPath(
            roundedRect: overlayRect,
            cornerWidth: CGFloat(cornerRadius),
            cornerHeight: CGFloat(cornerRadius),
            transform: nil
        )

        // Drop shadow behind the overlay
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: CGFloat(cornerRadius) / 2, color: CGColor(gray: 0, alpha: 0.5))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.addPath(clipPath)
        context.fillPath()
        context.restoreGState()

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

    static func renderFrame(
        backPath: URL,
        frontPath: URL?,
        imageContent: VideoImageContent,
        overlayPosition: OverlayPosition,
        targetSize: CGSize?
    ) throws -> CGImage {
        guard let backImage = loadImage(from: backPath) else {
            throw ImageProcessorError.failedToLoadImage(backPath.path)
        }

        let rendered: CGImage
        switch imageContent {
        case .backOnly:
            rendered = backImage
        case .frontOnly:
            guard let frontPath, let frontImage = loadImage(from: frontPath) else {
                throw ImageProcessorError.failedToLoadImage(frontPath?.path ?? "nil")
            }
            rendered = frontImage
        case .combinedBackMain:
            guard let frontPath, let frontImage = loadImage(from: frontPath) else {
                throw ImageProcessorError.failedToLoadImage(frontPath?.path ?? "nil")
            }
            let position = overlayPosition == .auto
                ? resolveAutoPosition(background: backImage, overlay: frontImage)
                : overlayPosition
            rendered = try stitchImages(back: backImage, front: frontImage, overlayPosition: position)
        case .combinedFrontMain:
            guard let frontPath, let frontImage = loadImage(from: frontPath) else {
                throw ImageProcessorError.failedToLoadImage(frontPath?.path ?? "nil")
            }
            let position = overlayPosition == .auto
                ? resolveAutoPosition(background: frontImage, overlay: backImage)
                : overlayPosition
            rendered = try stitchImages(back: frontImage, front: backImage, overlayPosition: position)
        }

        guard let targetSize, targetSize.width > 0, targetSize.height > 0 else {
            return rendered
        }

        let srcAspect = Double(rendered.width) / Double(rendered.height)
        let dstAspect = targetSize.width / targetSize.height

        let fitWidth: Int
        let fitHeight: Int
        if srcAspect > dstAspect {
            fitWidth = Int(targetSize.width)
            fitHeight = Int(targetSize.width / srcAspect)
        } else {
            fitHeight = Int(targetSize.height)
            fitWidth = Int(targetSize.height * srcAspect)
        }

        guard let ctx = CGContext(
            data: nil,
            width: fitWidth,
            height: fitHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageProcessorError.failedToCreateContext
        }
        ctx.interpolationQuality = .high
        ctx.draw(rendered, in: CGRect(x: 0, y: 0, width: fitWidth, height: fitHeight))
        guard let scaled = ctx.makeImage() else {
            throw ImageProcessorError.failedToCreateImage
        }
        return scaled
    }

    static func drawDateOverlay(on image: CGImage, date: Date) throws -> CGImage {
        let width = image.width
        let height = image.height

        guard let ctx = CGContext(
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

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let dateString = formatter.string(from: date).uppercased()

        let fontSize = CGFloat(height) / 32
        let margin = CGFloat(width) / 25

        // Font: SF Pro Rounded Medium, fallback to Helvetica Neue Medium
        let font: CTFont
        if let sfDescriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: "SF Pro Rounded" as CFString,
            kCTFontStyleNameAttribute: "Medium" as CFString,
        ] as CFDictionary) as CTFontDescriptor? {
            let sfFont = CTFontCreateWithFontDescriptor(sfDescriptor, fontSize, nil)
            let actualFamily = CTFontCopyFamilyName(sfFont) as String
            font = actualFamily == "SF Pro Rounded" ? sfFont : CTFontCreateWithName("HelveticaNeue-Medium" as CFString, fontSize, nil)
        } else {
            font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, fontSize, nil)
        }

        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorFromContextAttributeName: true,
            kCTKernAttributeName: 1.5 as CGFloat,
        ]
        let attrString = CFAttributedStringCreate(nil, dateString as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrString)
        let textBounds = CTLineGetBoundsWithOptions(line, [])

        // Pill dimensions
        let hPad = fontSize * 1.0
        let vPad = fontSize * 0.5
        let pillWidth = textBounds.width + hPad * 2
        let pillHeight = textBounds.height + vPad * 2
        let pillX = margin
        let pillY = margin
        let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        let cornerRadius = pillHeight / 2

        // Pill shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -2),
            blur: 8,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3)
        )
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(pillPath)
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45))
        ctx.fillPath()
        ctx.restoreGState()

        // Text position (centered inside pill)
        let textX = pillX + hPad - textBounds.origin.x
        let textY = pillY + vPad - textBounds.origin.y

        // Text shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -1),
            blur: 3,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6)
        )
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
        ctx.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()

        guard let result = ctx.makeImage() else {
            throw ImageProcessorError.failedToCreateImage
        }
        return result
    }

    static func buildExifProperties(metadata: ExportMetadata) -> [String: Any] {
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
