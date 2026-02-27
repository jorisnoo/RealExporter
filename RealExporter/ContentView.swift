import SwiftUI

enum AppState {
    case selectSource
    case loading
    case summary
    case hub
    case options
    case exporting
    case videoOptions
    case generatingVideo
}

@Observable
@MainActor
final class AppViewModel {
    var appState: AppState = .selectSource
    var selectedURL: URL?
    var isLoading = false
    var loadedData: BeRealExport?
    var exportOptions = ExportOptions()
    var videoOptions = VideoOptions()
    var exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
    var exportState: ExportState = .exporting
    var errorMessage: String?

    private var exportTask: Task<Void, Never>?
    private var videoTask: Task<Void, Never>?

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

    func startVideoGeneration() {
        guard let data = loadedData else { return }

        appState = .generatingVideo
        exportState = .exporting
        exportProgress = ExportProgress(current: 0, total: data.uniqueBeRealCount, currentItem: "")

        Analytics.videoStarted(count: data.uniqueBeRealCount)

        videoTask = Task {
            do {
                try await VideoGenerator.generate(
                    data: data,
                    options: videoOptions
                ) { progress in
                    self.exportProgress = progress
                }
                Analytics.videoCompleted(
                    count: data.uniqueBeRealCount,
                    imageContent: self.videoOptions.imageContent.rawValue,
                    resolution: self.videoOptions.resolution.rawValue,
                    fps: self.videoOptions.framesPerSecond
                )
                self.exportState = .completed
            } catch is CancellationError {
                self.exportState = .cancelled
            } catch VideoGeneratorError.cancelled {
                self.exportState = .cancelled
            } catch {
                self.exportState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelVideoGeneration() {
        videoTask?.cancel()
    }

    func returnToHub() {
        exportTask?.cancel()
        exportTask = nil
        videoTask?.cancel()
        videoTask = nil
        exportOptions = ExportOptions()
        videoOptions = VideoOptions()
        exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
        exportState = .exporting
        appState = .hub
    }

    func resetToStart() {
        exportTask?.cancel()
        exportTask = nil
        videoTask?.cancel()
        videoTask = nil
        selectedURL = nil
        if let tempDir = loadedData?.temporaryDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        loadedData = nil
        exportOptions = ExportOptions()
        videoOptions = VideoOptions()
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
                            viewModel.appState = .hub
                        },
                        onBack: {
                            viewModel.resetToStart()
                        }
                    )
                }

            case .hub:
                if let data = viewModel.loadedData {
                    HubView(
                        beRealCount: data.uniqueBeRealCount,
                        onExportPhotos: {
                            viewModel.appState = .options
                        },
                        onCreateVideo: {
                            viewModel.appState = .videoOptions
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
                            viewModel.appState = .hub
                        }
                    )
                }

            case .exporting:
                ExportProgressView(
                    progress: viewModel.exportProgress,
                    state: viewModel.exportState,
                    destinationURL: viewModel.exportOptions.destinationURL,
                    videoCount: viewModel.loadedData?.uniqueVideoCount ?? 0,
                    context: .photoExport,
                    onCancel: {
                        viewModel.cancelExport()
                    },
                    onDone: {
                        viewModel.returnToHub()
                    }
                )

            case .videoOptions:
                if let data = viewModel.loadedData {
                    VideoOptionsView(
                        data: data,
                        options: $viewModel.videoOptions,
                        onCreateVideo: {
                            viewModel.startVideoGeneration()
                        },
                        onBack: {
                            viewModel.appState = .hub
                        }
                    )
                }

            case .generatingVideo:
                ExportProgressView(
                    progress: viewModel.exportProgress,
                    state: viewModel.exportState,
                    destinationURL: viewModel.videoOptions.destinationURL,
                    context: .videoGeneration,
                    onCancel: {
                        viewModel.cancelVideoGeneration()
                    },
                    onDone: {
                        viewModel.returnToHub()
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
