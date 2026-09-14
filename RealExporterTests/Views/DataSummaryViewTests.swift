import Foundation
import SwiftUI
import Testing
@testable import RealExporter

struct DataSummaryViewTests {
    @Test(arguments: [0, 1, 365 * 2])
    func yearBoundariesHandleShortAndMultiYearArchives(days: Int) throws {
        let calendar = Calendar.current
        let start = try #require(calendar.date(from: DateComponents(year: 2024, month: 3, day: 1)))
        let end = try #require(calendar.date(byAdding: .day, value: days, to: start))
        let view = DataSummaryView(
            data: TestFixtures.makeBeRealExport(), startDate: .constant(start),
            endDate: .constant(end), dateRange: start...end, onContinue: {}, onBack: {}
        )
        let boundaries = view.yearBoundaries(in: start...end)
        #expect(boundaries.map(\.year) == (days < 365 ? [] : [2025, 2026]))
        #expect(boundaries.allSatisfy { $0.position > 0 && $0.position < 1 })
    }
}
