import SwiftUI
import UniformTypeIdentifiers

struct VideoOptionsView: View {
    let frames: [VideoGenerator.FrameItem]
    @Binding var options: VideoOptions
    let onCreateVideo: () -> Void
    let onBack: () -> Void

    private var beRealCount: Int { frames.count }

    /// The options that change how a frame looks.
    private nonisolated struct PreviewOptions: Equatable, Sendable {
        let imageContent: VideoImageContent
        let overlayPosition: OverlayPosition
        let showDateOverlay: Bool
    }

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
            FittingScrollView {
                VStack(spacing: 24) {
                    Text("Video Options")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    previewSection
                        .padding(24)
                        .cardStyle()

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
                    .cardStyle()
                }
                .padding(.screenPadding)
            }

            Divider()

            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Create Video") {
                    #if os(macOS)
                    selectDestination()
                    #else
                    // Written to a temporary file, then shared or saved from the result screen.
                    options.destinationURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("BeReal Time-Lapse.mp4")
                    #endif
                    if options.destinationURL != nil {
                        onCreateVideo()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(beRealCount == 0)
            }
            .padding(20)
        }
    }

    private var previewSection: some View {
        PreviewSection(
            frames: frames,
            options: PreviewOptions(
                imageContent: options.imageContent,
                overlayPosition: options.overlayPosition,
                showDateOverlay: options.showDateOverlay
            ),
            imageHeight: 240,
            render: { frame, options in
                let image = try VideoGenerator.render(
                    frame,
                    imageContent: options.imageContent,
                    overlayPosition: options.overlayPosition,
                    showDateOverlay: options.showDateOverlay,
                    targetSize: CGSize(width: 600, height: 600)
                )
                return [PreviewImage(id: "frame", caption: nil, image: image)]
            },
            footer: { frame in
                frame.date.formatted(date: .complete, time: .shortened)
            }
        )
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
            .compactPickerStyle()
            .labelsHidden()

            if options.imageContent == .combinedBackMain || options.imageContent == .combinedFrontMain {
                Label("Overlay Position", systemImage: "pip.enter")
                    .font(.headline)
                    .padding(.top, 4)
                Picker("", selection: $options.overlayPosition) {
                    ForEach(Self.cornerPositions) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .compactPickerStyle()
                .labelsHidden()
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

    #if os(macOS)
    private func selectDestination() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "BeReal Time-Lapse.mp4"
        panel.message = "Choose where to save the time-lapse video"

        if panel.runModal() == .OK, let url = panel.url {
            options.destinationURL = url
        }
    }
    #endif
}
