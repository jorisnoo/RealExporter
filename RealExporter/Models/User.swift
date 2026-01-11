import Foundation

struct Birthdate: Codable {
    let year: Int
    let month: Int
    let day: Int
}

struct ProfilePicture: Codable {
    let path: String
    let bucket: String
    let height: String
    let width: String
}

struct User: Codable {
    let username: String
    let fullname: String
    let birthdate: Birthdate?
    let phoneNumber: String?
    let clientVersion: String?
    let device: String?
    let deviceId: String?
    let profilePicture: ProfilePicture?
    let platform: Int?
    let countryCode: String?
    let language: String?
    let timezone: String?
    let region: String?
    let createdAt: Date?
}
