import Foundation

struct BeRealExport {
    let user: User
    let posts: [Post]
    let memories: [Memory]
    let conversationImages: [ConversationImage]
    let comments: [Comment]
    let baseURL: URL

    var uniqueBeRealCount: Int {
        var uniquePaths = Set<String>()

        for post in posts where post.hasBothImages {
            uniquePaths.insert(post.primary.path)
        }

        for memory in memories where memory.hasBothImages {
            uniquePaths.insert(memory.backImageForExport.path)
        }

        return uniquePaths.count
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
