import Foundation

struct ConversationImage: Identifiable {
    let id: String
    let url: URL
    let conversationId: String
    let filename: String
    let date: Date?
}

struct ChatLog: Codable {
    let conversationId: String
    let createdAt: Date
    let messages: [ChatMessage]
}

struct ChatMessage: Codable {
    let id: String
    let userId: String
    let message: String?
    let createdAt: Date
}
