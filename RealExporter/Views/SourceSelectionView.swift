import SwiftUI
import UniformTypeIdentifiers

struct SourceSelectionView: View {
    @Binding var selectedURL: URL?
    @Binding var isLoading: Bool
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("RealExporter")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Export your BeReal data in a more useful format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            dropZone
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
                )

            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(isDragging ? .accentColor : .secondary)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                } else {
                    Text("Drop or click to select")
                        .font(.headline)
                        .foregroundColor(isDragging ? .accentColor : .primary)

                    Text("BeReal export folder or ZIP file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            openFilePicker()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            DispatchQueue.main.async {
                self.selectedURL = url
            }
        }

        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.zip, UTType.folder]
        panel.message = "Select your BeReal data export"

        if panel.runModal() == .OK {
            selectedURL = panel.url
        }
    }
}
