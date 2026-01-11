import Foundation

struct Post: Codable, Identifiable {
    let primary: MediaReference
    let secondary: MediaReference
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
}
