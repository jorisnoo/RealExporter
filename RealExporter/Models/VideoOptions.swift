import Foundation
import CoreGraphics

enum VideoImageContent: String, CaseIterable, Identifiable {
    case combined = "Combined"
    case backOnly = "Back Camera"
    case frontOnly = "Front Camera"

    var id: String { rawValue }
}

enum VideoResolution: String, CaseIterable, Identifiable {
    case original = "Original"
    case hd1080 = "1080p"
    case hd720 = "720p"

    var id: String { rawValue }

    var size: CGSize? {
        switch self {
        case .original: return nil
        case .hd1080: return CGSize(width: 1920, height: 1080)
        case .hd720: return CGSize(width: 1280, height: 720)
        }
    }
}

struct VideoOptions {
    var imageContent: VideoImageContent = .combined
    var framesPerSecond: Double = 8
    var resolution: VideoResolution = .original
    var showDateOverlay: Bool = false
    var overlayPosition: OverlayPosition = .topLeft
    var startDate: Date?
    var endDate: Date?
    var destinationURL: URL?
}
