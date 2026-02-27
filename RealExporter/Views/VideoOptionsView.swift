import SwiftUI
import UniformTypeIdentifiers

struct VideoOptionsView: View {
    let beRealCount: Int
    @Binding var options: VideoOptions
    let onCreateVideo: () -> Void
    let onBack: () -> Void

    private var estimatedDuration: String {
        let seconds = Double(beRealCount) / options.framesPerSecond
        if seconds < 60 {
            return String(format: "~%.0f seconds", seconds)
        } else {
            let minutes = seconds / 60
            return String(format: "~%.1f minutes", minutes)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Video Options")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 24) {
                        contentSection

                        Divider()

                        speedSection

                        Divider()

                        resolutionSection

                        Divider()

                        dateOverlaySection
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

                Button("Create Video") {
                    selectDestination()
                    if options.destinationURL != nil {
                        onCreateVideo()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(beRealCount == 0)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    private static let cornerPositions: [OverlayPosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Content", systemImage: "photo.on.rectangle")
                .font(.headline)

            Picker("Content", selection: $options.imageContent) {
                ForEach(VideoImageContent.allCases) { content in
                    Text(content.rawValue).tag(content)
                }
            }
            .pickerStyle(.segmented)

            if options.imageContent == .combinedBackMain || options.imageContent == .combinedFrontMain {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overlay Position")
                        .font(.subheadline)
                    Picker("", selection: $options.overlayPosition) {
                        ForEach(Self.cornerPositions) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .animation(.default, value: options.imageContent)
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Speed", systemImage: "speedometer")
                .font(.headline)

            HStack {
                Text("1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $options.framesPerSecond, in: 1...30, step: 1)
                Text("30")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("\(Int(options.framesPerSecond)) photos/sec")
                    .font(.subheadline)
                Spacer()
                Text(estimatedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Resolution", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.headline)

            Picker("Resolution", selection: $options.resolution) {
                ForEach(VideoResolution.allCases) { res in
                    Text(res.rawValue).tag(res)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dateOverlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date Overlay", systemImage: "calendar.badge.clock")
                .font(.headline)

            Toggle(isOn: $options.showDateOverlay) {
                Text("Show date on each frame")
            }
        }
    }

    private func selectDestination() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "BeReal Time-Lapse.mp4"
        panel.message = "Choose where to save the time-lapse video"

        if panel.runModal() == .OK, let url = panel.url {
            options.destinationURL = url
        }
    }
}
