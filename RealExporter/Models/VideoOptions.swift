import Foundation
import CoreGraphics

enum VideoImageContent: String, CaseIterable, Identifiable {
    case combinedFrontMain = "Front + Back Overlay"
    case combinedBackMain = "Back + Front Overlay"
    case backOnly = "Back Camera"
    case frontOnly = "Front Camera"

    var id: String { rawValue }
}

enum VideoResolution: String, CaseIterable, Identifiable {
    case original = "Original"
    case hd1080 = "1080p"
    case hd720 = "720p"

    var id: String { rawValue }

    /// Length of the frame's shorter side, or nil to keep the photos' size.
    var shortSide: Int? {
        switch self {
        case .original: return nil
        case .hd1080: return 1080
        case .hd720: return 720
        }
    }

    /// Output size for photos of `sourceSize`, keeping their orientation and
    /// aspect ratio so portrait BeReals aren't letterboxed into a landscape frame.
    func size(for sourceSize: CGSize) -> CGSize? {
        guard let shortSide, sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = CGFloat(shortSide) / min(sourceSize.width, sourceSize.height)
        func even(_ value: CGFloat) -> CGFloat { CGFloat(Int((value * scale).rounded()) / 2 * 2) }
        return CGSize(width: even(sourceSize.width), height: even(sourceSize.height))
    }
}

struct VideoOptions {
    var imageContent: VideoImageContent = .combinedFrontMain
    var framesPerSecond: Double = 8
    var resolution: VideoResolution = .original
    var showDateOverlay: Bool = false
    var overlayPosition: OverlayPosition = .topLeft
    var startDate: Date?
    var endDate: Date?
    var destinationURL: URL?
}
