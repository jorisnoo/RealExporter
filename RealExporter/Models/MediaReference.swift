import Foundation

struct MediaReference: Codable {
    let bucket: String
    let height: Int
    let width: Int
    let path: String
    let mediaType: String?
    let mimeType: String?

    var isVideo: Bool {
        mediaType == "video" || mimeType?.contains("video") == true
    }

    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    func localPath(relativeTo baseURL: URL) -> URL {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        let components = cleanPath.components(separatedBy: "/")
        if components.count >= 4 && components[0] == "Photos" {
            let simplifiedPath = "Photos/\(components[2])/\(components[3])"
            return baseURL.appendingPathComponent(simplifiedPath)
        }

        return baseURL.appendingPathComponent(cleanPath)
    }
}
