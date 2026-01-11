import SwiftUI

enum ExportState {
    case exporting
    case completed
    case cancelled
    case failed(String)
}

struct ExportProgressView: View {
    let progress: ExportProgress
    let state: ExportState
    let destinationURL: URL?
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
            return "Exporting..."
        case .completed:
            return "Export Complete"
        case .cancelled:
            return "Export Cancelled"
        case .failed:
            return "Export Failed"
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

            Text("Successfully exported \(progress.total) images")
                .font(.headline)

            if let url = destinationURL {
                Button("Open in Finder") {
                    NSWorkspace.shared.open(url)
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

            Text("Export was cancelled")
                .font(.headline)

            if progress.current > 0 {
                Text("\(progress.current) of \(progress.total) images were exported before cancellation")
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

            Text("Export failed")
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
