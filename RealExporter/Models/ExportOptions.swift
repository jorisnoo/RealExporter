import Foundation

enum ImageStyle: String, CaseIterable, Identifiable {
    case combined = "Combined"
    case separate = "Separate"
    case both = "Both"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .combined:
            return "Front camera overlaid on back camera"
        case .separate:
            return "Front and back as separate files"
        case .both:
            return "Export both combined and separate versions"
        }
    }
}

enum FolderStructure: String, CaseIterable, Identifiable {
    case byDate = "By Date"
    case flat = "Flat"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .byDate:
            return "Organized in year/month/day folders"
        case .flat:
            return "All files in one folder with date prefix"
        }
    }
}

struct ExportOptions {
    var imageStyle: ImageStyle = .separate
    var folderStructure: FolderStructure = .byDate
    var includeConversations: Bool = true
    var includeComments: Bool = true
    var destinationURL: URL?

    var isValid: Bool {
        destinationURL != nil
    }
}
