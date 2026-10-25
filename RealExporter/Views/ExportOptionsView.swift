import SwiftUI
import UniformTypeIdentifiers

struct ExportOptionsView: View {
    private static let lastExportFolderKey = "lastExportFolder"

    let data: BeRealExport
    let frames: [VideoGenerator.FrameItem]
    @Binding var options: ExportOptions
    let startDate: Date?
    let endDate: Date?
    let onExport: () -> Void
    let onBack: () -> Void

    @State private var choosingFolder = false

    /// The options that change how a BeReal looks once exported.
    private nonisolated struct PreviewOptions: Equatable, Sendable {
        let imageStyle: ImageStyle
        let overlayPosition: OverlayPosition
    }

    var body: some View {
        VStack(spacing: 0) {
            FittingScrollView {
                VStack(spacing: 24) {
                    Text("Export Options")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    previewSection
                        .padding(24)
                        .cardStyle()

                    VStack(alignment: .leading, spacing: 24) {
                        imageStyleSection

                        Divider()

                        folderStructureSection

                        Divider()

                        contentSection
                    }
                    .padding(24)
                    .cardStyle()
                }
                .padding(.screenPadding)
            }

            Divider()

            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Export") {
                    #if os(macOS)
                    selectDestination()
                    if options.destinationURL != nil {
                        onExport()
                    }
                    #else
                    choosingFolder = true
                    #endif
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                options.destinationURL = url
                onExport()
            }
        }
    }

    private var previewSection: some View {
        PreviewSection(
            frames: frames,
            options: PreviewOptions(imageStyle: options.imageStyle, overlayPosition: options.overlayPosition),
            render: { frame, options in
                guard let frontPath = frame.frontPath else { return [] }
                let outputs = try ImageProcessor.previewOutputs(
                    backPath: frame.backPath,
                    frontPath: frontPath,
                    style: options.imageStyle,
                    overlayPosition: options.overlayPosition,
                    maxPixelSize: 400
                )
                // Combined images first: they're what the options change most.
                let combined = outputs.filter { $0.suffix.hasPrefix("_combined") }
                let separate = outputs.filter { !$0.suffix.hasPrefix("_combined") }
                return (combined + separate).map { output in
                    PreviewImage(id: output.suffix, caption: "\(output.suffix.dropFirst()).jpg", image: output.image)
                }
            },
            footer: { frame in
                let path = Exporter.folderComponents(for: frame.date, folderStructure: options.folderStructure)
                    + ["\(Exporter.baseName(for: frame.date))_….jpg"]
                return "Saved as " + path.joined(separator: "/")
            }
        )
    }

    private var showOverlayPicker: Bool {
        options.imageStyle == .combined || options.imageStyle == .both
    }

    private var imageStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Image Style", systemImage: "photo.on.rectangle")
                .font(.headline)

            Picker("Image Style", selection: $options.imageStyle) {
                ForEach(ImageStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(options.imageStyle.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if showOverlayPicker {
                Label("Overlay Position", systemImage: "pip.enter")
                    .font(.headline)
                    .padding(.top, 4)
                Picker("", selection: $options.overlayPosition) {
                    ForEach(OverlayPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .compactPickerStyle()
                .labelsHidden()
            }
        }
        .animation(.default, value: options.imageStyle)
    }

    private var folderStructureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Folder Structure", systemImage: "folder")
                .font(.headline)

            Picker("Folder Structure", selection: $options.folderStructure) {
                ForEach(FolderStructure.allCases) { structure in
                    Text(structure.rawValue).tag(structure)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(options.folderStructure.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Extras", systemImage: "plus.circle")
                .font(.headline)

            Toggle(isOn: $options.includeConversations) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Conversation photos (\(data.filteredConversationImages(startDate: startDate, endDate: endDate).count))")
                }
            }

            Toggle(isOn: $options.includeComments) {
                HStack {
                    Image(systemName: "text.bubble")
                    Text("Comments (\(data.filteredComments(startDate: startDate, endDate: endDate).count))")
                }
            }
        }
    }

    #if os(macOS)
    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select the destination folder for exported images"

        if let lastFolder = UserDefaults.standard.url(forKey: Self.lastExportFolderKey) {
            panel.directoryURL = lastFolder
        }

        if panel.runModal() == .OK, let url = panel.url {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
            let visibleContents = contents.filter { !$0.hasPrefix(".") }
            if !visibleContents.isEmpty {
                let alert = NSAlert()
                alert.messageText = "Folder Not Empty"
                alert.informativeText = "The selected folder is not empty. Please choose an empty folder."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
            options.destinationURL = url
            UserDefaults.standard.set(url, forKey: Self.lastExportFolderKey)
        }
    }
    #endif
}
