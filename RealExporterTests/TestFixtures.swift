import Foundation
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
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
        comments: [RealExporter.Comment] = [],
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

extension TestFixtures {
    static func makeImage(width: Int = 80, height: Int = 60) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    static func writeImage(_ image: CGImage, to url: URL) throws {
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
