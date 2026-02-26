import Foundation
@testable import RealExporter

enum TestFixtures {
    static func makeMediaReference(
        path: String = "Photos/post/image.jpg",
        bucket: String = "test-bucket",
        height: Int = 1500,
        width: Int = 2000,
        mediaType: String? = nil,
        mimeType: String? = nil
    ) -> MediaReference {
        MediaReference(
            bucket: bucket,
            height: height,
            width: width,
            path: path,
            mediaType: mediaType,
            mimeType: mimeType
        )
    }

    static func makePost(
        primaryPath: String = "Photos/post/primary.jpg",
        secondaryPath: String = "Photos/post/secondary.jpg",
        btsMedia: MediaReference? = nil,
        caption: String? = nil,
        location: Location? = nil,
        takenAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        primaryMediaType: String? = nil,
        secondaryMediaType: String? = nil
    ) -> Post {
        Post(
            primary: makeMediaReference(path: primaryPath, mediaType: primaryMediaType),
            secondary: makeMediaReference(path: secondaryPath, mediaType: secondaryMediaType),
            btsMedia: btsMedia,
            retakeCounter: 0,
            caption: caption,
            location: location,
            visibility: nil,
            takenAt: takenAt
        )
    }

    static func makeMemory(
        frontImagePath: String = "Photos/memory/front.jpg",
        backImagePath: String = "Photos/memory/back.jpg",
        btsMedia: MediaReference? = nil,
        primaryPlaceholder: MediaReference? = nil,
        secondaryPlaceholder: MediaReference? = nil,
        caption: String? = nil,
        location: Location? = nil,
        date: Date = Date(timeIntervalSince1970: 1_700_000_000),
        takenTime: Date = Date(timeIntervalSince1970: 1_700_000_000),
        frontMediaType: String? = nil,
        backMediaType: String? = nil
    ) -> Memory {
        Memory(
            frontImage: makeMediaReference(path: frontImagePath, mediaType: frontMediaType),
            backImage: makeMediaReference(path: backImagePath, mediaType: backMediaType),
            btsMedia: btsMedia,
            primaryPlaceholder: primaryPlaceholder,
            secondaryPlaceholder: secondaryPlaceholder,
            caption: caption,
            isLate: false,
            date: date,
            takenTime: takenTime,
            location: location,
            berealMoment: nil
        )
    }

    static func makeUser(
        username: String = "testuser",
        fullname: String = "Test User"
    ) -> User {
        User(
            username: username,
            fullname: fullname,
            birthdate: nil,
            phoneNumber: nil,
            clientVersion: nil,
            device: nil,
            deviceId: nil,
            profilePicture: nil,
            platform: nil,
            countryCode: nil,
            language: nil,
            timezone: nil,
            region: nil,
            createdAt: nil
        )
    }

    static func makeBeRealExport(
        posts: [Post] = [],
        memories: [Memory] = [],
        conversationImages: [ConversationImage] = [],
        comments: [Comment] = [],
        baseURL: URL = URL(fileURLWithPath: "/tmp/test"),
        user: User? = nil
    ) -> BeRealExport {
        BeRealExport(
            user: user ?? makeUser(),
            posts: posts,
            memories: memories,
            conversationImages: conversationImages,
            comments: comments,
            baseURL: baseURL,
            temporaryDirectory: nil
        )
    }
}
