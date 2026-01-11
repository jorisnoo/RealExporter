import SwiftUI

enum AppState {
    case selectSource
    case loading
    case summary
    case options
    case exporting
}

struct ContentView: View {
    @State private var appState: AppState = .selectSource
    @State private var selectedURL: URL?
    @State private var isLoading = false
    @State private var loadedData: BeRealExport?
    @State private var exportOptions = ExportOptions()
    @State private var exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
    @State private var exportState: ExportState = .exporting
    @State private var errorMessage: String?

    private let exporter = Exporter()

    var body: some View {
        Group {
            switch appState {
            case .selectSource, .loading:
                SourceSelectionView(
                    selectedURL: $selectedURL,
                    isLoading: $isLoading
                )
                .onChange(of: selectedURL) { _, newValue in
                    if let url = newValue {
                        loadData(from: url)
                    }
                }

            case .summary:
                if let data = loadedData {
                    DataSummaryView(
                        data: data,
                        onContinue: {
                            appState = .options
                        },
                        onBack: {
                            resetToStart()
                        }
                    )
                }

            case .options:
                if let data = loadedData {
                    ExportOptionsView(
                        data: data,
                        options: $exportOptions,
                        onExport: {
                            startExport()
                        },
                        onBack: {
                            appState = .summary
                        }
                    )
                }

            case .exporting:
                ExportProgressView(
                    progress: exportProgress,
                    state: exportState,
                    destinationURL: exportOptions.destinationURL,
                    onCancel: {
                        exporter.cancel()
                    },
                    onDone: {
                        resetToStart()
                    }
                )
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func loadData(from url: URL) {
        isLoading = true
        appState = .loading

        Task {
            do {
                let data = try await DataLoader.shared.loadFromURL(url)
                await MainActor.run {
                    self.loadedData = data
                    self.isLoading = false
                    self.appState = .summary
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.appState = .selectSource
                    self.selectedURL = nil
                }
            }
        }
    }

    private func startExport() {
        guard let data = loadedData else { return }

        appState = .exporting
        exportState = .exporting
        exportProgress = ExportProgress(current: 0, total: data.totalImageCount, currentItem: "")

        Task {
            do {
                try await exporter.export(
                    data: data,
                    options: exportOptions
                ) { progress in
                    Task { @MainActor in
                        self.exportProgress = progress
                    }
                }
                await MainActor.run {
                    self.exportState = .completed
                }
            } catch let error as ExporterError where error == .cancelled {
                await MainActor.run {
                    self.exportState = .cancelled
                }
            } catch {
                await MainActor.run {
                    self.exportState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func resetToStart() {
        selectedURL = nil
        loadedData = nil
        exportOptions = ExportOptions()
        exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
        exportState = .exporting
        appState = .selectSource
    }
}

#Preview {
    ContentView()
}
