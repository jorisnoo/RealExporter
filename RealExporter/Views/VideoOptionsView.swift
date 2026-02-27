import SwiftUI
import UniformTypeIdentifiers

struct VideoOptionsView: View {
    let data: BeRealExport
    @Binding var options: VideoOptions
    let onCreateVideo: () -> Void
    let onBack: () -> Void

    @State private var showPositionOptions = false

    private var dateRange: ClosedRange<Date> {
        data.dateRange ?? Date()...Date()
    }

    private var filteredCount: Int {
        let start = options.startDate ?? dateRange.lowerBound
        let end = options.endDate ?? dateRange.upperBound
        return VideoGenerator.frameCount(data: data, startDate: start, endDate: end)
    }

    private var estimatedDuration: String {
        let seconds = Double(filteredCount) / options.framesPerSecond
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
                        dateRangeSection

                        Divider()

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
                .disabled(filteredCount == 0)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            if options.startDate == nil {
                options.startDate = dateRange.lowerBound
            }
            if options.endDate == nil {
                options.endDate = dateRange.upperBound
            }
        }
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date Range", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { options.startDate ?? dateRange.lowerBound },
                            set: { options.startDate = $0 }
                        ),
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { options.endDate ?? dateRange.upperBound },
                            set: { options.endDate = $0 }
                        ),
                        in: dateRange,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                Spacer()
            }

            Text("\(filteredCount) BeReals in selected range")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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

            if options.imageContent == .combined {
                DisclosureGroup(
                    isExpanded: $showPositionOptions,
                    content: {
                        Picker("", selection: $options.overlayPosition) {
                            ForEach(Self.cornerPositions) { position in
                                Text(position.rawValue).tag(position)
                            }
                        }
                        .pickerStyle(.segmented)
                    },
                    label: {
                        Text("Overlay Position: \(options.overlayPosition.rawValue)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation { showPositionOptions.toggle() } }
                    }
                )
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
                Slider(value: $options.framesPerSecond, in: 1...10, step: 1)
                Text("10")
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
