import SwiftUI

enum AppState {
    case selectSource
    case loading
    case summary
    case options
    case exporting
}

@Observable
@MainActor
final class AppViewModel {
    var appState: AppState = .selectSource
    var selectedURL: URL?
    var isLoading = false
    var loadedData: BeRealExport?
    var exportOptions = ExportOptions()
    var exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
    var exportState: ExportState = .exporting
    var errorMessage: String?

    private var exportTask: Task<Void, Never>?

    func loadData(from url: URL) {
        isLoading = true
        appState = .loading

        Task {
            do {
                let data = try await DataLoader.loadFromURL(url)
                self.loadedData = data
                self.isLoading = false
                self.appState = .summary
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.appState = .selectSource
                self.selectedURL = nil
            }
        }
    }

    func startExport() {
        guard let data = loadedData else { return }

        appState = .exporting
        exportState = .exporting
        exportProgress = ExportProgress(current: 0, total: data.uniqueBeRealCount, currentItem: "")

        Analytics.exportStarted(count: data.uniqueBeRealCount)

        exportTask = Task {
            do {
                try await Exporter.export(
                    data: data,
                    options: exportOptions
                ) { progress in
                    self.exportProgress = progress
                }
                Analytics.exportCompleted(
                    count: data.uniqueBeRealCount,
                    imageStyle: self.exportOptions.imageStyle.rawValue,
                    folderStructure: self.exportOptions.folderStructure.rawValue
                )
                self.exportState = .completed
            } catch is CancellationError {
                self.exportState = .cancelled
            } catch let error as ExporterError where error == .cancelled {
                self.exportState = .cancelled
            } catch {
                self.exportState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelExport() {
        exportTask?.cancel()
    }

    func resetToStart() {
        exportTask?.cancel()
        exportTask = nil
        selectedURL = nil
        if let tempDir = loadedData?.temporaryDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        loadedData = nil
        exportOptions = ExportOptions()
        exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
        exportState = .exporting
        appState = .selectSource
    }
}

struct ContentView: View {
    @State private var viewModel = AppViewModel()

    var body: some View {
        Group {
            switch viewModel.appState {
            case .selectSource, .loading:
                SourceSelectionView(
                    selectedURL: $viewModel.selectedURL,
                    isLoading: $viewModel.isLoading
                )
                .onChange(of: viewModel.selectedURL) { _, newValue in
                    if let url = newValue {
                        viewModel.loadData(from: url)
                    }
                }

            case .summary:
                if let data = viewModel.loadedData {
                    DataSummaryView(
                        data: data,
                        onContinue: {
                            viewModel.appState = .options
                        },
                        onBack: {
                            viewModel.resetToStart()
                        }
                    )
                }

            case .options:
                if let data = viewModel.loadedData {
                    ExportOptionsView(
                        data: data,
                        options: $viewModel.exportOptions,
                        onExport: {
                            viewModel.startExport()
                        },
                        onBack: {
                            viewModel.appState = .summary
                        }
                    )
                }

            case .exporting:
                ExportProgressView(
                    progress: viewModel.exportProgress,
                    state: viewModel.exportState,
                    destinationURL: viewModel.exportOptions.destinationURL,
                    videoCount: viewModel.loadedData?.uniqueVideoCount ?? 0,
                    onCancel: {
                        viewModel.cancelExport()
                    },
                    onDone: {
                        viewModel.resetToStart()
                    }
                )
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

#Preview {
    ContentView()
}
