import SwiftUI

/// One rendered preview image, with an optional caption under it.
nonisolated struct PreviewImage: Identifiable, Sendable {
    let id: String
    let caption: String?
    let image: CGImage
}

/// Shows a BeReal rendered with the current options, so the result can be
/// checked before exporting. Starts at the most recent BeReal in the range;
/// the arrows step through the others.
struct PreviewSection<Options: Equatable & Sendable>: View {
    let frames: [VideoGenerator.FrameItem]
    let options: Options
    var imageHeight: CGFloat = 180
    let render: @Sendable (VideoGenerator.FrameItem, Options) throws -> [PreviewImage]
    let footer: (VideoGenerator.FrameItem) -> String

    @State private var position: Int?
    @State private var images: [PreviewImage] = []
    @State private var isRendering = false
    @State private var failed = false

    private var index: Int? {
        guard !frames.isEmpty else { return nil }
        return min(position ?? frames.count - 1, frames.count - 1)
    }

    private struct RenderID: Equatable {
        let index: Int?
        let options: Options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Preview", systemImage: "eye")
                    .font(.headline)

                Spacer()

                if let index {
                    stepper(index)
                }
            }

            if let index {
                imageStrip

                Text(footer(frames[index]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            } else {
                Text("No BeReals in the selected date range.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: RenderID(index: index, options: options)) {
            await renderCurrent()
        }
    }

    private func width(of image: CGImage) -> CGFloat {
        imageHeight * CGFloat(image.width) / CGFloat(max(image.height, 1))
    }

    /// Wraps into rows rather than scrolling sideways, which a mouse can't do.
    private var imageStrip: some View {
        let columnWidth = images.first.map { width(of: $0.image) } ?? imageHeight
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: columnWidth), spacing: 12, alignment: .top)],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(images) { item in
                let width = width(of: item.image)
                VStack(spacing: 6) {
                    Image(decorative: item.image, scale: 1)
                        .resizable()
                        .frame(width: width, height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    if let caption = item.caption {
                        Text(caption)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: width)
                    }
                }
            }
        }
        .frame(minHeight: imageHeight, alignment: .top)
        .opacity(isRendering ? 0.5 : 1)
        .overlay {
            if failed {
                Label("This BeReal couldn't be rendered", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if images.isEmpty {
                ProgressView()
            }
        }
        .animation(.easeOut(duration: 0.15), value: isRendering)
    }

    private func stepper(_ index: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                position = index - 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(index == 0)
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .help("Previous BeReal (⌘←)")

            Text("\(index + 1) of \(frames.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                position = index + 1
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(index == frames.count - 1)
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .help("Next BeReal (⌘→)")

            Button {
                position = Int.random(in: frames.indices)
            } label: {
                Image(systemName: "shuffle")
            }
            .help("Random BeReal")
        }
        .buttonStyle(.borderless)
    }

    private func renderCurrent() async {
        guard let index else {
            images = []
            return
        }
        let frame = frames[index]
        let options = options
        let render = render

        isRendering = true
        let rendered = try? await Task.detached(priority: .userInitiated) {
            try render(frame, options)
        }.value
        // A newer render took over while this one ran.
        guard !Task.isCancelled else { return }

        images = rendered ?? []
        failed = rendered == nil
        isRendering = false
    }
}

/// The preview and the settings that change it, side by side on the Mac so
/// each change shows without scrolling. Stacked on iOS.
struct PreviewAndSettings<Preview: View, Settings: View>: View {
    @ViewBuilder var preview: Preview
    @ViewBuilder var settings: Settings

    var body: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 20) {
            preview
                .padding(24)
                .frame(width: 380)
                .cardStyle()

            settings
                .padding(24)
                .frame(minWidth: 340)
                .cardStyle()
        }
        #else
        VStack(spacing: 24) {
            preview
                .padding(24)
                .cardStyle()

            settings
                .padding(24)
                .cardStyle()
        }
        #endif
    }
}
