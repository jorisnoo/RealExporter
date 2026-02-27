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

    private var filteredConversationCount: Int {
        data.filteredConversationImages(startDate: startDate, endDate: endDate).count
    }

    private var filteredCommentCount: Int {
        data.filteredComments(startDate: startDate, endDate: endDate).count
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
                value: "\(filteredConversationCount)",
                label: "Chat Photos"
            )

            statItem(
                icon: "video.fill",
                value: "\(data.uniqueVideoCount)",
                label: "Videos"
            )

            statItem(
                icon: "text.bubble",
                value: "\(filteredCommentCount)",
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
    private static let snapThreshold: CGFloat = 0.02

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

    private func yearBoundaries(in range: ClosedRange<Date>) -> [(position: CGFloat, year: Int)] {
        let cal = Calendar.current
        let startYear = cal.component(.year, from: range.lowerBound)
        let endYear = cal.component(.year, from: range.upperBound)
        var result: [(position: CGFloat, year: Int)] = []
        for year in (startYear + 1)...endYear {
            var comps = DateComponents()
            comps.year = year
            comps.month = 1
            comps.day = 1
            guard let jan1 = cal.date(from: comps) else { continue }
            let pos = normalizedPosition(for: jan1, in: range)
            if pos > 0 && pos < 1 {
                result.append((position: pos, year: year))
            }
        }
        return result
    }

    private func snapped(_ position: CGFloat, to boundaries: [(position: CGFloat, year: Int)]) -> CGFloat {
        for b in boundaries {
            if abs(position - b.position) < Self.snapThreshold {
                return b.position
            }
        }
        return position
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
                let boundaries = yearBoundaries(in: range)

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: Self.trackHeight)

                    // Year boundary tick marks
                    ForEach(boundaries, id: \.year) { boundary in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 1, height: 10)
                            .offset(x: boundary.position * trackWidth - 0.5)
                    }

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
                                    let raw = min(max(0, value.location.x / trackWidth), highNorm)
                                    let clamped = snapped(raw, to: boundaries)
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
                                    let raw = min(max(lowNorm, value.location.x / trackWidth), 1)
                                    let clamped = snapped(raw, to: boundaries)
                                    endDate = date(forNormalized: clamped, in: range)
                                }
                        )
                }
                .frame(height: Self.thumbDiameter)
            }
            .frame(height: Self.thumbDiameter)

            // Year labels
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let boundaries = yearBoundaries(in: range)
                ZStack(alignment: .leading) {
                    ForEach(boundaries, id: \.year) { boundary in
                        Text(verbatim: "\(boundary.year)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize()
                            .position(x: boundary.position * trackWidth, y: 6)
                    }
                }
            }
            .frame(height: 12)

            HStack {
                Text(Self.dateFormatter.string(from: startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(Self.dateFormatter.string(from: endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(filteredCount) BeReals, \(filteredConversationCount) chat photos, \(filteredCommentCount) comments in selected range")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
