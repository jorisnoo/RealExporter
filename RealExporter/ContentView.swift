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
    /// Every BeReal with both photos, collected once per import because it
    /// checks each file on disk.
    private(set) var frames: [VideoGenerator.FrameItem] = []
    var exportOptions = ExportOptions()
    var videoOptions = VideoOptions()
    var exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
    var exportState: ExportState = .exporting
    var exportResult = ExportResult()
    var errorMessage: String?
    var startDate: Date?
    var endDate: Date?

    var effectiveStartDate: Date {
        startDate ?? loadedData?.dateRange?.lowerBound ?? Date()
    }

    var effectiveEndDate: Date {
        endDate ?? loadedData?.dateRange?.upperBound ?? Date()
    }

    var framesInRange: [VideoGenerator.FrameItem] {
        VideoGenerator.filterFrames(frames, startDate: effectiveStartDate, endDate: effectiveEndDate)
    }

    private var exportTask: Task<Void, Never>?
    private var videoTask: Task<Void, Never>?
    // Picked files and folders stay accessible while these are held.
    private var sourceAccess: ScopedAccess?
    private var destinationAccess: ScopedAccess?

    func loadData(from url: URL) {
        // A second drop while unzipping would orphan the first extraction.
        guard !isLoading else { return }
        isLoading = true
        appState = .loading
        sourceAccess = ScopedAccess(url)

        Task {
            do {
                let data = try await DataLoader.loadFromURL(url)
                self.loadedData = data
                self.frames = VideoGenerator.collectFrames(data: data)
                self.startDate = data.dateRange?.lowerBound
                self.endDate = data.dateRange?.upperBound
                self.isLoading = false
                self.appState = .summary
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.appState = .selectSource
                self.selectedURL = nil
                self.sourceAccess = nil
            }
        }
    }

    func startExport() {
        guard let data = loadedData else { return }

        exportOptions.startDate = startDate
        exportOptions.endDate = endDate
        #if os(iOS)
        // Picked folders often hold other files, so export into a new one.
        if let picked = exportOptions.destinationURL {
            destinationAccess = ScopedAccess(picked)
            do {
                exportOptions.destinationURL = try Exporter.makeExportFolder(in: picked)
            } catch {
                errorMessage = error.localizedDescription
                destinationAccess = nil
                return
            }
        }
        #endif
        appState = .exporting
        exportState = .exporting
        exportResult = ExportResult()
        exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")

        Analytics.exportStarted(count: data.uniqueBeRealCount)

        exportTask = Task {
            do {
                self.exportResult = try await Exporter.export(
                    data: data,
                    options: exportOptions
                ) { progress in
                    self.exportProgress = progress
                }
                Analytics.exportCompleted(
                    count: self.exportResult.beReals,
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

        videoOptions.startDate = startDate
        videoOptions.endDate = endDate
        appState = .generatingVideo
        exportState = .exporting
        exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")

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
        clearDestinations()
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
        frames = []
        sourceAccess = nil
        startDate = nil
        endDate = nil
        clearDestinations()
        exportProgress = ExportProgress(current: 0, total: 0, currentItem: "")
        exportState = .exporting
        appState = .selectSource
    }

    private func clearDestinations() {
        #if os(iOS)
        // The video only lives in the temporary folder until it's shared.
        if let video = videoOptions.destinationURL {
            try? FileManager.default.removeItem(at: video)
        }
        #endif
        exportOptions.destinationURL = nil
        videoOptions.destinationURL = nil
        destinationAccess = nil
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
                        frames: viewModel.frames,
                        startDate: Binding(
                            get: { viewModel.effectiveStartDate },
                            set: { viewModel.startDate = $0 }
                        ),
                        endDate: Binding(
                            get: { viewModel.effectiveEndDate },
                            set: { viewModel.endDate = $0 }
                        ),
                        dateRange: data.dateRange,
                        onContinue: {
                            viewModel.appState = .hub
                        },
                        onBack: {
                            viewModel.resetToStart()
                        }
                    )
                }

            case .hub:
                if viewModel.loadedData != nil {
                    HubView(
                        beRealCount: viewModel.framesInRange.count,
                        onExportPhotos: {
                            viewModel.appState = .options
                        },
                        onCreateVideo: {
                            viewModel.appState = .videoOptions
                        },
                        onBack: {
                            viewModel.appState = .summary
                        }
                    )
                }

            case .options:
                if let data = viewModel.loadedData {
                    ExportOptionsView(
                        data: data,
                        frames: viewModel.framesInRange,
                        options: $viewModel.exportOptions,
                        startDate: viewModel.startDate,
                        endDate: viewModel.endDate,
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
                    result: viewModel.exportResult,
                    context: .photoExport,
                    onCancel: {
                        viewModel.cancelExport()
                    },
                    onBack: {
                        viewModel.returnToHub()
                    },
                    onDone: {
                        viewModel.resetToStart()
                    }
                )

            case .videoOptions:
                if viewModel.loadedData != nil {
                    VideoOptionsView(
                        frames: viewModel.framesInRange,
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
                    onBack: {
                        viewModel.returnToHub()
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
