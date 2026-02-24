import SwiftUI

struct ExportOptionsView: View {
    private static let lastExportFolderKey = "lastExportFolder"

    let data: BeRealExport
    @Binding var options: ExportOptions
    let onExport: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Export Options")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 24) {
                        imageStyleSection

                        Divider()

                        folderStructureSection

                        Divider()

                        contentSection

                        Divider()

                        destinationSection
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.controlBackgroundColor))
                    )
                }
                .padding(40)
            }

            Divider()

            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Export") {
                    if options.destinationURL == nil {
                        selectDestination()
                    }
                    if options.destinationURL != nil {
                        onExport()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            loadLastDestination()
        }
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

            Text(options.imageStyle.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if showOverlayPicker {
                Picker("Overlay Position", selection: $options.overlayPosition) {
                    ForEach(OverlayPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.segmented)
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
                    Text("Conversation photos (\(data.conversationImages.count))")
                }
            }

            Toggle(isOn: $options.includeComments) {
                HStack {
                    Image(systemName: "text.bubble")
                    Text("Comments (\(data.comments.count))")
                }
            }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Destination", systemImage: "arrow.down.doc")
                .font(.headline)

            HStack {
                if let url = options.destinationURL {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)

                    Text(url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Change") {
                        selectDestination()
                    }
                } else {
                    Button("Select Destination Folder") {
                        selectDestination()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

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
            options.destinationURL = url
            UserDefaults.standard.set(url, forKey: Self.lastExportFolderKey)
        }
    }

    private func loadLastDestination() {
        if options.destinationURL == nil,
           let lastFolder = UserDefaults.standard.url(forKey: Self.lastExportFolderKey),
           FileManager.default.fileExists(atPath: lastFolder.path) {
            options.destinationURL = lastFolder
        }
    }
}
