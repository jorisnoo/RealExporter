import SwiftUI

struct HubView: View {
    let beRealCount: Int
    let onExportPhotos: () -> Void
    let onCreateVideo: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text("What would you like to do?")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                #if os(macOS)
                HStack(spacing: 20) { actionCards }
                #else
                // Side by side on iPad, stacked on a phone.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) { actionCards }
                    VStack(spacing: 16) { actionCards }
                }
                #endif
            }
            .padding(.screenPadding)

            Spacer()

            Divider()

            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(20)
        }
        .windowMinSize(width: 500, height: 400)
    }

    @ViewBuilder
    private var actionCards: some View {
        actionCard(
            icon: "photo.on.rectangle.angled",
            title: "Export Photos",
            subtitle: "Save \(beRealCount) BeReals as image files",
            action: onExportPhotos
        )

        actionCard(
            icon: "film.stack",
            title: "Create Time-Lapse",
            subtitle: "Generate a video from \(beRealCount) BeReals",
            action: onCreateVideo
        )
    }

    private func actionCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
