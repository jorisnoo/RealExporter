import Foundation
import Testing
@testable import RealExporter

struct CodableTests {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - User

    @Test func decodeUserWithAllFields() throws {
        let json = """
        {
            "username": "johndoe",
            "fullname": "John Doe",
            "birthdate": {"year": 1990, "month": 5, "day": 15},
            "phoneNumber": "+1234567890",
            "clientVersion": "2.0.0",
            "device": "iPhone 15",
            "deviceId": "abc123",
            "profilePicture": {"path": "profile.jpg", "bucket": "bucket", "height": "200", "width": "200"},
            "platform": 1,
            "countryCode": "US",
            "language": "en",
            "timezone": "America/New_York",
            "region": "us-east",
            "createdAt": "2023-01-15T10:30:00Z"
        }
        """
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.username == "johndoe")
        #expect(user.fullname == "John Doe")
        #expect(user.birthdate?.year == 1990)
        #expect(user.phoneNumber == "+1234567890")
    }

    @Test func decodeUserWithOnlyRequiredFields() throws {
        let json = """
        {
            "username": "minimal",
            "fullname": "Minimal User"
        }
        """
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.username == "minimal")
        #expect(user.birthdate == nil)
        #expect(user.phoneNumber == nil)
        #expect(user.createdAt == nil)
    }

    // MARK: - Post

    @Test func decodePostWithFullData() throws {
        let json = """
        {
            "primary": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/p/post/front.jpg", "mediaType": "image", "mimeType": "image/jpeg"},
            "secondary": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/p/post/back.jpg"},
            "retakeCounter": 3,
            "caption": "Hello world",
            "location": {"latitude": 48.8566, "longitude": 2.3522},
            "visibility": ["friends"],
            "takenAt": "2024-01-15T12:00:00Z"
        }
        """
        let post = try decoder.decode(Post.self, from: Data(json.utf8))
        #expect(post.primary.path == "Photos/p/post/front.jpg")
        #expect(post.caption == "Hello world")
        #expect(post.location?.latitude == 48.8566)
        #expect(post.retakeCounter == 3)
    }

    @Test func decodePostWithMinimalFields() throws {
        let json = """
        {
            "primary": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/front.jpg"},
            "secondary": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/back.jpg"},
            "takenAt": "2024-01-15T12:00:00Z"
        }
        """
        let post = try decoder.decode(Post.self, from: Data(json.utf8))
        #expect(post.btsMedia == nil)
        #expect(post.caption == nil)
        #expect(post.location == nil)
    }

    // MARK: - Memory

    @Test func decodeMemoryWithVideoAndPlaceholder() throws {
        let json = """
        {
            "frontImage": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/front.webm", "mediaType": "video", "mimeType": "video/webm"},
            "backImage": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/back.jpg"},
            "primaryPlaceholder": {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/front_placeholder.jpg"},
            "caption": "Memory caption",
            "isLate": true,
            "date": "2024-01-15T00:00:00Z",
            "takenTime": "2024-01-15T12:30:00Z",
            "location": {"latitude": 51.5074, "longitude": -0.1278},
            "berealMoment": "2024-01-15T12:00:00Z"
        }
        """
        let memory = try decoder.decode(Memory.self, from: Data(json.utf8))
        #expect(memory.frontImage.isVideo == true)
        #expect(memory.primaryPlaceholder?.path == "Photos/front_placeholder.jpg")
        #expect(memory.isLate == true)
    }

    // MARK: - Comment

    @Test func decodeComment() throws {
        let json = """
        {"postId": "abc123", "content": "Nice photo!"}
        """
        let comment = try decoder.decode(RealExporter.Comment.self, from: Data(json.utf8))
        #expect(comment.postId == "abc123")
        #expect(comment.content == "Nice photo!")
    }

    // MARK: - MediaReference

    @Test func decodeMediaReferenceWithOptionalFields() throws {
        let json = """
        {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/image.jpg", "mediaType": "image", "mimeType": "image/jpeg"}
        """
        let ref = try decoder.decode(MediaReference.self, from: Data(json.utf8))
        #expect(ref.mediaType == "image")
        #expect(ref.mimeType == "image/jpeg")
    }

    @Test func decodeMediaReferenceWithoutOptionalFields() throws {
        let json = """
        {"bucket": "b", "height": 1500, "width": 2000, "path": "Photos/image.jpg"}
        """
        let ref = try decoder.decode(MediaReference.self, from: Data(json.utf8))
        #expect(ref.mediaType == nil)
        #expect(ref.mimeType == nil)
        #expect(ref.path == "Photos/image.jpg")
    }
}
