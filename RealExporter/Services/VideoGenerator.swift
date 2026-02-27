import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

enum VideoGeneratorError: LocalizedError {
    case noDestination
    case noFrames
    case failedToStartWriter(String)
    case failedToCreatePixelBuffer
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noDestination:
            return "No destination file selected."
        case .noFrames:
            return "No images found to include in the video."
        case .failedToStartWriter(let msg):
            return "Failed to start video writer: \(msg)"
        case .failedToCreatePixelBuffer:
            return "Failed to create pixel buffer for frame."
        case .cancelled:
            return "Video generation was cancelled."
        }
    }
}

enum VideoGenerator {
    struct FrameItem {
        let date: Date
        let backPath: URL
        let frontPath: URL?
    }

    static func generate(
        data: BeRealExport,
        options: VideoOptions,
        progressHandler: @escaping @MainActor (ExportProgress) -> Void
    ) async throws {
        guard let destinationURL = options.destinationURL else {
            throw VideoGeneratorError.noDestination
        }

        let allFrames = collectFrames(data: data)
        let frames = filterFrames(allFrames, startDate: options.startDate, endDate: options.endDate)
        guard !frames.isEmpty else {
            throw VideoGeneratorError.noFrames
        }

        try Task.checkCancellation()

        // Determine frame size from first image
        let firstBackPath = frames[0].backPath
        let firstFrontPath = frames[0].frontPath
        let imageContent = options.imageContent
        let overlayPos = options.overlayPosition
        let targetSize = options.resolution.size
        let firstFrame = try await Task.detached {
            try ImageProcessor.renderFrame(
                backPath: firstBackPath,
                frontPath: firstFrontPath,
                imageContent: imageContent,
                overlayPosition: overlayPos,
                targetSize: targetSize
            )
        }.value
        let frameWidth = firstFrame.width
        let frameHeight = firstFrame.height

        // Ensure even dimensions for H.264
        let videoWidth = frameWidth % 2 == 0 ? frameWidth : frameWidth + 1
        let videoHeight = frameHeight % 2 == 0 ? frameHeight : frameHeight + 1

        // Set up AVAssetWriter
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: bufferAttributes
        )

        writer.add(writerInput)
        guard writer.startWriting() else {
            throw VideoGeneratorError.failedToStartWriter(writer.error?.localizedDescription ?? "Unknown error")
        }
        writer.startSession(atSourceTime: .zero)

        let total = frames.count
        let showDateOverlay = options.showDateOverlay
        let fps = options.framesPerSecond

        for (index, frame) in frames.enumerated() {
            try Task.checkCancellation()

            var rendered = try await Task.detached {
                try ImageProcessor.renderFrame(
                    backPath: frame.backPath,
                    frontPath: frame.frontPath,
                    imageContent: imageContent,
                    overlayPosition: overlayPos,
                    targetSize: targetSize
                )
            }.value

            if showDateOverlay {
                rendered = try await Task.detached {
                    try ImageProcessor.drawDateOverlay(on: rendered, date: frame.date)
                }.value
            }

            let presentationTime = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))

            // Wait for writer input to be ready
            while !writerInput.isReadyForMoreMediaData {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(10))
            }

            guard let pixelBuffer = createPixelBuffer(
                from: rendered,
                width: videoWidth,
                height: videoHeight,
                adaptor: adaptor
            ) else {
                throw VideoGeneratorError.failedToCreatePixelBuffer
            }

            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

            let progress = ExportProgress(
                current: index + 1,
                total: total,
                currentItem: ""
            )
            await progressHandler(progress)
        }

        // Finish writing
        writerInput.markAsFinished()
        await writer.finishWriting()

        if let error = writer.error {
            throw error
        }
    }

    static func frameCount(data: BeRealExport, startDate: Date, endDate: Date) -> Int {
        filterFrames(collectFrames(data: data), startDate: startDate, endDate: endDate).count
    }

    private static func filterFrames(_ frames: [FrameItem], startDate: Date?, endDate: Date?) -> [FrameItem] {
        frames.filter { frame in
            if let start = startDate, frame.date < Calendar.current.startOfDay(for: start) {
                return false
            }
            if let end = endDate, frame.date > Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end))! {
                return false
            }
            return true
        }
    }

    private static func collectFrames(data: BeRealExport) -> [FrameItem] {
        let fileManager = FileManager.default
        var merged: [String: FrameItem] = [:]

        for post in data.posts where post.hasBothImages {
            let backPath = post.primary.localPath(relativeTo: data.baseURL)
            let frontPath = post.secondary.localPath(relativeTo: data.baseURL)
            guard fileManager.fileExists(atPath: backPath.path),
                  fileManager.fileExists(atPath: frontPath.path) else { continue }
            let key = post.primary.path
            merged[key] = FrameItem(date: post.takenAt, backPath: backPath, frontPath: frontPath)
        }

        for memory in data.memories where memory.hasBothImages {
            let backPath = memory.backImageForExport.localPath(relativeTo: data.baseURL)
            let frontPath = memory.frontImageForExport.localPath(relativeTo: data.baseURL)
            guard fileManager.fileExists(atPath: backPath.path),
                  fileManager.fileExists(atPath: frontPath.path) else { continue }
            let key = memory.backImageForExport.path
            if merged[key] == nil {
                merged[key] = FrameItem(date: memory.takenTime, backPath: backPath, frontPath: frontPath)
            }
        }

        return merged.values.sorted { $0.date < $1.date }
    }

    private static func createPixelBuffer(
        from image: CGImage,
        width: Int,
        height: Int,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        // Clear to black (handles odd-dimension padding)
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Center the image in the buffer
        let offsetX = (width - image.width) / 2
        let offsetY = (height - image.height) / 2
        ctx.draw(image, in: CGRect(x: offsetX, y: offsetY, width: image.width, height: image.height))

        return buffer
    }
}
