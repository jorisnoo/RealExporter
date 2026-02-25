import Foundation

struct Memory: Codable, Identifiable {
    let frontImage: MediaReference
    let backImage: MediaReference
    let btsMedia: MediaReference?
    let primaryPlaceholder: MediaReference?
    let secondaryPlaceholder: MediaReference?
    let caption: String?
    let isLate: Bool?
    let date: Date
    let takenTime: Date
    let location: Location?
    let berealMoment: Date?

    var id: String {
        frontImage.filename
    }

    var hasBothImages: Bool {
        !frontImage.isVideo && !backImage.isVideo
    }

    var hasVideo: Bool {
        frontImage.isVideo || backImage.isVideo || btsMedia != nil
    }

    var frontImageForExport: MediaReference {
        if frontImage.isVideo, let placeholder = primaryPlaceholder {
            return placeholder
        }
        return frontImage
    }

    var backImageForExport: MediaReference {
        if backImage.isVideo, let placeholder = secondaryPlaceholder {
            return placeholder
        }
        return backImage
    }
}
