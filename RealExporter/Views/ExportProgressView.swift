import SwiftUI

enum ExportState {
    case exporting
    case completed
    case cancelled
    case failed(String)
}

struct ProgressContext {
    let activeTitle: String
    let completedTitle: String
    let completedMessage: (ExportResult) -> String
    let cancelledMessage: (ExportProgress) -> String
    let failedTitle: String
    let itemNoun: String

    static let photoExport = ProgressContext(
        activeTitle: "Exporting...",
        completedTitle: "Export Complete",
        completedMessage: { result in
            let parts = [
                ProgressContext.countLabel(result.beReals, "BeReal", "BeReals"),
                ProgressContext.countLabel(result.videos, "video", "videos"),
                ProgressContext.countLabel(result.chatPhotos, "chat photo", "chat photos"),
            ].compactMap { $0 }
            return parts.isEmpty ? "Export finished" : "Exported " + ListFormatter.localizedString(byJoining: parts)
        },
        cancelledMessage: { progress in
            "\(progress.current) of \(progress.total) items were exported before cancellation"
        },
        failedTitle: "Export Failed",
        itemNoun: "items"
    )

    private static func countLabel(_ count: Int, _ singular: String, _ plural: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? singular : plural)"
    }

    // On iOS the video waits in a temporary file until it's saved or shared.
    #if os(macOS)
    private static let videoCompletedMessage = "Video saved successfully"
    #else
    private static let videoCompletedMessage = "Your time-lapse is ready"
    #endif

    static let videoGeneration = ProgressContext(
        activeTitle: "Generating Video...",
        completedTitle: "Video Complete",
        completedMessage: { _ in videoCompletedMessage },
        cancelledMessage: { progress in
            "\(progress.current) of \(progress.total) frames were processed before cancellation"
        },
        failedTitle: "Video Failed",
        itemNoun: "frames"
    )
}

struct ExportProgressView: View {
    let progress: ExportProgress
    let state: ExportState
    let destinationURL: URL?
    var result = ExportResult()
    var context: ProgressContext = .photoExport
    let onCancel: () -> Void
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            switch state {
            case .exporting:
                exportingContent
            case .completed:
                completedContent
            case .cancelled:
                cancelledContent
            case .failed(let message):
                failedContent(message)
            }

            Spacer()

            bottomButtons
        }
        .padding(.screenPadding)
        .windowMinSize(width: 500, height: 400)
        #if os(iOS)
        // Auto-lock would suspend a long export partway through.
        .onChange(of: isExporting, initial: true) {
            UIApplication.shared.isIdleTimerDisabled = isExporting
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    private var isExporting: Bool {
        if case .exporting = state { return true }
        return false
    }

    @ViewBuilder
    private func revealButton(_ url: URL) -> some View {
        #if os(macOS)
        Button("Open in Finder") {
            if url.hasDirectoryPath {
                NSWorkspace.shared.open(url)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .buttonStyle(.bordered)
        #else
        if url.hasDirectoryPath {
            Button("Show in Files") {
                url.showInFiles()
            }
            .buttonStyle(.bordered)
        } else if FileManager.default.fileExists(atPath: url.path) {
            ShareLink(item: url) {
                Label("Save or Share Video", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        #endif
    }

    private var title: String {
        switch state {
        case .exporting:
            return context.activeTitle
        case .completed:
            return context.completedTitle
        case .cancelled:
            return "\(context.completedTitle.replacingOccurrences(of: "Complete", with: "Cancelled").replacingOccurrences(of: "complete", with: "cancelled"))"
        case .failed:
            return context.failedTitle
        }
    }

    private var exportingContent: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress.percentage)
                .progressViewStyle(.linear)

            HStack {
                Text("\(progress.current) of \(progress.total)")
                    .font(.headline)

                Spacer()

                Text("\(Int(progress.percentage * 100))%")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }

            if !progress.currentItem.isEmpty {
                Text(progress.currentItem)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(24)
        .cardStyle()
    }

    private var completedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(context.completedMessage(result))
                .font(.headline)
                .multilineTextAlignment(.center)

            if let url = destinationURL {
                revealButton(url)
            }
        }
        .padding(24)
        .cardStyle()
    }

    private var cancelledContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("\(context.activeTitle.replacingOccurrences(of: "...", with: "")) was cancelled")
                .font(.headline)

            if progress.current > 0 {
                Text(context.cancelledMessage(progress))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let url = destinationURL {
                revealButton(url)
            }
        }
        .padding(24)
        .cardStyle()
    }

    private func failedContent(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text(context.failedTitle)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .cardStyle()
    }

    private var bottomButtons: some View {
        HStack {
            switch state {
            case .exporting:
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

            case .completed, .cancelled, .failed:
                // Keeps the loaded data so another export doesn't need a re-import.
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
