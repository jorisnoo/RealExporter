import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import RealExporter

struct VideoGeneratorTests {
    @Test func mixedAspectRatiosFitWithoutLosingEdges() throws {
        let source = try #require(CGContext(
            data: nil, width: 80, height: 60, bitsPerComponent: 8,
            bytesPerRow: 320, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        source.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
        source.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        source.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        source.fill(CGRect(x: 0, y: 0, width: 10, height: 60))
        source.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        source.fill(CGRect(x: 70, y: 0, width: 10, height: 60))
        let canvas = try #require(CGContext(
            data: nil, width: 60, height: 80, bitsPerComponent: 8,
            bytesPerRow: 240, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        VideoGenerator.drawFrame(try #require(source.makeImage()), in: canvas)
        let pixels = try #require(canvas.data).assumingMemoryBound(to: UInt8.self)
        func rgb(_ x: Int, _ y: Int) -> [UInt8] {
            let offset = y * canvas.bytesPerRow + x * 4
            return [pixels[offset], pixels[offset + 1], pixels[offset + 2]]
        }
        #expect(rgb(2, 40) == [255, 0, 0])
        #expect(rgb(30, 40) == [0, 255, 0])
        #expect(rgb(57, 40) == [0, 0, 255])
        #expect(rgb(30, 2) == [0, 0, 0])
        #expect(rgb(30, 77) == [0, 0, 0])
    }

    @Test(arguments: [false, true])
    func terminatedWriterThrowsInsteadOfWaiting(failToStart: Bool) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 80, AVVideoHeightKey: 60,
        ])
        writer.add(input)
        if failToStart {
            try Data().write(to: url)
            #expect(!writer.startWriting())
            #expect(writer.status == .failed)
        } else {
            #expect(writer.startWriting())
            writer.startSession(atSourceTime: .zero)
            writer.cancelWriting()
        }
        let wait = Task { try await VideoGenerator.waitUntilReady(writer: writer, input: input) }
        // Ensure a regression fails instead of hanging the test suite.
        let watchdog = Task {
            try await Task.sleep(for: .seconds(2))
            wait.cancel()
        }
        defer { watchdog.cancel() }
        do {
            try await wait.value
            Issue.record("A terminated writer was treated as ready")
        } catch is CancellationError {
            Issue.record("Readiness wait did not detect writer termination")
        } catch {
            #expect(writer.status == (failToStart ? .failed : .cancelled))
        }
    }

    @Test(arguments: [VideoResolution.original, .hd720])
    func generatesPlayableVideoWithMixedImageSizes(resolution: VideoResolution) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try TestFixtures.writeImage(TestFixtures.makeImage(width: 60, height: 80), to: root.appendingPathComponent("portrait.png"))
        try TestFixtures.writeImage(TestFixtures.makeImage(width: 80, height: 60), to: root.appendingPathComponent("landscape.png"))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let data = TestFixtures.makeBeRealExport(posts: [
            TestFixtures.makePost(primaryPath: "portrait.png", secondaryPath: "portrait.png", takenAt: date),
            TestFixtures.makePost(primaryPath: "landscape.png", secondaryPath: "landscape.png", takenAt: date.addingTimeInterval(1)),
        ], baseURL: root)
        var options = VideoOptions()
        options.imageContent = .backOnly
        options.resolution = resolution
        options.destinationURL = root.appendingPathComponent("video.mp4")
        var count = 0
        try await VideoGenerator.generate(data: data, options: options) { count = $0.current }
        #expect(count == 2)
        let asset = AVURLAsset(url: options.destinationURL!)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        #expect(try await track.load(.naturalSize) == (resolution.size ?? CGSize(width: 60, height: 80)))
        #expect(try await asset.load(.duration).seconds > 0)
    }

    @Test func renderingFailureRemovesIncompleteVideo() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try TestFixtures.writeImage(TestFixtures.makeImage(), to: root.appendingPathComponent("valid.png"))
        try Data("invalid image".utf8).write(to: root.appendingPathComponent("broken.png"))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let data = TestFixtures.makeBeRealExport(posts: [
            TestFixtures.makePost(primaryPath: "valid.png", secondaryPath: "valid.png", takenAt: date),
            TestFixtures.makePost(primaryPath: "broken.png", secondaryPath: "broken.png", takenAt: date.addingTimeInterval(1)),
        ], baseURL: root)
        var options = VideoOptions()
        options.imageContent = .backOnly
        let destination = root.appendingPathComponent("incomplete.mp4")
        options.destinationURL = destination
        var count = 0
        await #expect(throws: ImageProcessorError.self) {
            try await VideoGenerator.generate(data: data, options: options) { count = $0.current }
        }
        #expect(count == 1)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

}
