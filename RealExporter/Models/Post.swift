import Foundation

struct Post: Codable, Identifiable {
    let primary: MediaReference
    let secondary: MediaReference
    let btsMedia: MediaReference?
    let retakeCounter: Int?
    let caption: String?
    let location: Location?
    let visibility: [String]?
    let takenAt: Date

    var id: String {
        primary.filename
    }

    var hasBothImages: Bool {
        !primary.isVideo && !secondary.isVideo
    }

    var hasVideo: Bool {
        primary.isVideo || secondary.isVideo || btsMedia != nil
    }
}
