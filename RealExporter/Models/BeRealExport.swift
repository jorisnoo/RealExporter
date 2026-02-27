import Foundation

struct BeRealExport {
    let user: User
    let posts: [Post]
    let memories: [Memory]
    let conversationImages: [ConversationImage]
    let comments: [Comment]
    let baseURL: URL
    let temporaryDirectory: URL?

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

    var uniqueVideoCount: Int {
        var uniquePaths = Set<String>()

        for post in posts where post.primary.isVideo || post.secondary.isVideo {
            uniquePaths.insert(post.primary.path)
        }

        for memory in memories where memory.frontImage.isVideo || memory.backImage.isVideo {
            uniquePaths.insert(memory.backImage.path)
        }

        for post in posts where post.btsMedia != nil {
            uniquePaths.insert(post.btsMedia!.path)
        }

        for memory in memories where memory.btsMedia != nil {
            uniquePaths.insert(memory.btsMedia!.path)
        }

        return uniquePaths.count
    }

    func filteredConversationImages(startDate: Date?, endDate: Date?) -> [ConversationImage] {
        let calendar = Calendar.current
        let rangeStart = startDate.map { calendar.startOfDay(for: $0) }
        let rangeEnd = endDate.map { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))! }

        return conversationImages.filter { image in
            guard let date = image.date else { return true }
            if let start = rangeStart, date < start { return false }
            if let end = rangeEnd, date > end { return false }
            return true
        }
    }

    func filteredComments(startDate: Date?, endDate: Date?) -> [Comment] {
        let calendar = Calendar.current
        let rangeStart = startDate.map { calendar.startOfDay(for: $0) }
        let rangeEnd = endDate.map { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))! }

        var postDateById: [String: Date] = [:]
        for post in posts {
            let postId = URL(fileURLWithPath: post.primary.path).lastPathComponent.replacingOccurrences(of: ".webp", with: "")
            postDateById[postId] = post.takenAt
        }

        return comments.filter { comment in
            guard let date = postDateById[comment.postId] else { return false }
            if let start = rangeStart, date < start { return false }
            if let end = rangeEnd, date > end { return false }
            return true
        }
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
