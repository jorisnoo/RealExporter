import SwiftUI
import UniformTypeIdentifiers

struct SourceSelectionView: View {
    @Binding var selectedURL: URL?
    @Binding var isLoading: Bool
    @State private var isDragging = false
    @State private var showingGuide = false
    @State private var showingPicker = false

    #if os(macOS)
    private static let pickPrompt = "Drop or click to select"
    #else
    private static let pickPrompt = "Tap to select"
    #endif

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

            Button("Don't have your data yet?") {
                showingGuide = true
            }
            #if os(macOS)
            .buttonStyle(.link)
            #else
            .buttonStyle(.borderless)
            #endif
            .font(.subheadline)
        }
        .padding(.screenPadding)
        .windowMinSize(width: 500, height: 400)
        .sheet(isPresented: $showingGuide) {
            DataRequestGuideView()
        }
        .fileImporter(isPresented: $showingPicker, allowedContentTypes: [.zip, .folder]) { result in
            if case .success(let url) = result {
                selectedURL = url
            }
        }
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
                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.cardBackground)
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
                    Text(Self.pickPrompt)
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
        .onTapGesture(perform: pickSource)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pickSource() }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            selectedURL = url
            return true
        } isTargeted: { targeted in
            isDragging = targeted
        }
    }

    private func pickSource() {
        guard !isLoading else { return }
        #if os(macOS)
        openFilePicker()
        #else
        showingPicker = true
        #endif
    }

    #if os(macOS)
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.zip, UTType.folder]
        panel.message = "Select your BeReal data export"

        if let lastPath = UserDefaults.standard.string(forKey: "lastImportDirectory") {
            panel.directoryURL = URL(fileURLWithPath: lastPath)
        }

        if panel.runModal() == .OK {
            selectedURL = panel.url
            if let url = panel.url {
                let directory = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
                UserDefaults.standard.set(directory.path, forKey: "lastImportDirectory")
            }
        }
    }
    #endif
}
