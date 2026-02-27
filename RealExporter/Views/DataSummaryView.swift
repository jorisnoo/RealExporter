import SwiftUI

struct DataSummaryView: View {
    let data: BeRealExport
    @Binding var startDate: Date
    @Binding var endDate: Date
    let dateRange: ClosedRange<Date>?
    let onContinue: () -> Void
    let onBack: () -> Void

    private var filteredCount: Int {
        VideoGenerator.frameCount(data: data, startDate: startDate, endDate: endDate)
    }

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

                        if let range = dateRange {
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
        VStack(alignment: .leading, spacing: 4) {
            Text(data.user.fullname)
                .font(.title2)
                .fontWeight(.semibold)

            Text("@\(data.user.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                icon: "video.fill",
                value: "\(data.uniqueVideoCount)",
                label: "Videos"
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

    private static let trackHeight: CGFloat = 4
    private static let thumbDiameter: CGFloat = 18

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private func normalizedPosition(for date: Date, in range: ClosedRange<Date>) -> CGFloat {
        let total = range.upperBound.timeIntervalSince(range.lowerBound)
        guard total > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(range.lowerBound) / total)
    }

    private func date(forNormalized position: CGFloat, in range: ClosedRange<Date>) -> Date {
        let total = range.upperBound.timeIntervalSince(range.lowerBound)
        return range.lowerBound.addingTimeInterval(total * Double(position))
    }

    private func dateRangeSection(_ range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date Range", systemImage: "calendar")
                .font(.headline)

            GeometryReader { geo in
                let trackWidth = geo.size.width
                let lowNorm = normalizedPosition(for: startDate, in: range)
                let highNorm = normalizedPosition(for: endDate, in: range)
                let halfThumb = Self.thumbDiameter / 2

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: Self.trackHeight)

                    // Active range
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(
                            width: max(0, (highNorm - lowNorm) * trackWidth),
                            height: Self.trackHeight
                        )
                        .offset(x: lowNorm * trackWidth)

                    // Start thumb
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                        .shadow(radius: 1)
                        .offset(x: lowNorm * trackWidth - halfThumb)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let clamped = min(max(0, value.location.x / trackWidth), highNorm)
                                    startDate = date(forNormalized: clamped, in: range)
                                }
                        )

                    // End thumb
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
                        .shadow(radius: 1)
                        .offset(x: highNorm * trackWidth - halfThumb)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let clamped = min(max(lowNorm, value.location.x / trackWidth), 1)
                                    endDate = date(forNormalized: clamped, in: range)
                                }
                        )
                }
                .frame(height: Self.thumbDiameter)
            }
            .frame(height: Self.thumbDiameter)

            HStack {
                Text(Self.dateFormatter.string(from: startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(Self.dateFormatter.string(from: endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(filteredCount) BeReals in selected range")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
