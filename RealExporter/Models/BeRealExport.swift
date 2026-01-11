import Foundation

struct BeRealExport {
    let user: User
    let posts: [Post]
    let memories: [Memory]
    let conversationImages: [ConversationImage]
    let baseURL: URL

    var totalImageCount: Int {
        let postImages = posts.filter { $0.hasBothImages }.count
        let memoryImages = memories.filter { $0.hasBothImages }.count
        return postImages + memoryImages
    }

    var dateRange: ClosedRange<Date>? {
        let postDates = posts.map { $0.takenAt }
        let memoryDates = memories.map { $0.takenTime }
        let allDates = postDates + memoryDates

        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            return nil
        }

        return minDate...maxDate
    }
}

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]

    static let valid = ValidationResult(isValid: true, errors: [], warnings: [])

    static func invalid(_ errors: [String]) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors, warnings: [])
    }
}
