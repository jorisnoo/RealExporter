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
    let completedMessage: (ExportProgress, Int) -> String
    let cancelledMessage: (ExportProgress) -> String
    let failedTitle: String
    let itemNoun: String

    static let photoExport = ProgressContext(
        activeTitle: "Exporting...",
        completedTitle: "Export Complete",
        completedMessage: { progress, videoCount in
            "Successfully exported \(progress.total) images" + (videoCount > 0 ? " and \(videoCount) videos" : "")
        },
        cancelledMessage: { progress in
            "\(progress.current) of \(progress.total) images were exported before cancellation"
        },
        failedTitle: "Export Failed",
        itemNoun: "images"
    )

    static let videoGeneration = ProgressContext(
        activeTitle: "Generating Video...",
        completedTitle: "Video Complete",
        completedMessage: { _, _ in "Video saved successfully" },
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
    var videoCount: Int = 0
    var context: ProgressContext = .photoExport
    let onCancel: () -> Void
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
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private var completedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(context.completedMessage(progress, videoCount))
                .font(.headline)

            if let url = destinationURL {
                Button("Open in Finder") {
                    if url.hasDirectoryPath {
                        NSWorkspace.shared.open(url)
                    } else {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
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
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private var bottomButtons: some View {
        HStack {
            Spacer()

            switch state {
            case .exporting:
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

            case .completed, .cancelled, .failed:
                Button("Done") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
