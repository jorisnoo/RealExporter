import SwiftUI

struct DataSummaryView: View {
    let data: BeRealExport
    let onContinue: () -> Void
    let onBack: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Summary")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 20) {
                        userSection

                        Divider()

                        statsSection

                        if let range = data.dateRange {
                            Divider()
                            dateRangeSection(range)
                        }
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

                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var userSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.user.fullname)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("@\(data.user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

        }
    }

    private var statsSection: some View {
        HStack(spacing: 32) {
            statItem(
                icon: "camera.fill",
                value: "\(data.uniqueBeRealCount)",
                label: "BeReals"
            )

            statItem(
                icon: "bubble.left.and.bubble.right",
                value: "\(data.conversationImages.count)",
                label: "Chat Photos"
            )

            statItem(
                icon: "text.bubble",
                value: "\(data.comments.count)",
                label: "Comments"
            )
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func dateRangeSection(_ range: ClosedRange<Date>) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.accentColor)

            Text("Date range:")
                .foregroundColor(.secondary)

            Text("\(Self.dateFormatter.string(from: range.lowerBound)) - \(Self.dateFormatter.string(from: range.upperBound))")
                .fontWeight(.medium)
        }
    }
}
