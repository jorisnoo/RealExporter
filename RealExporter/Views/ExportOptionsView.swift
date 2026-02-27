import SwiftUI

struct ExportOptionsView: View {
    private static let lastExportFolderKey = "lastExportFolder"

    let data: BeRealExport
    @Binding var options: ExportOptions
    let startDate: Date?
    let endDate: Date?
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
                    selectDestination()
                    if options.destinationURL != nil {
                        onExport()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 500)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overlay Position")
                        .font(.subheadline)
                    Picker("", selection: $options.overlayPosition) {
                        ForEach(OverlayPosition.allCases) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                }
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

}
