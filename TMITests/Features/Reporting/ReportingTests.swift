import CoreGraphics
import Foundation
import Testing
@testable import TMI

struct ReportingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func windowsAreInclusiveLocalDays() {
        var filter = ReportFilter()
        filter.window = .last30
        #expect(filter.range(today: date(2026, 9, 22), calendar: calendar) == ("2026-08-24", "2026-09-22"))
        filter.window = .last90
        #expect(filter.range(today: date(2026, 9, 22), calendar: calendar) == ("2026-06-25", "2026-09-22"))
    }

    @Test func schoolYearStartsInAugust() {
        var filter = ReportFilter()
        filter.window = .schoolYear
        #expect(filter.range(today: date(2026, 9, 22), calendar: calendar).from == "2026-08-01")
        #expect(filter.range(today: date(2027, 3, 1), calendar: calendar).from == "2026-08-01")
    }

    @Test func customWindowOrdersDates() {
        var filter = ReportFilter()
        filter.window = .custom
        filter.customStart = date(2026, 9, 10)
        filter.customEnd = date(2026, 9, 1)
        #expect(filter.range(calendar: calendar) == ("2026-09-01", "2026-09-01"))
    }

    @Test func formatsValuesAndSuppression() {
        let rate = ReportMetric(id: "r", value: 0.256, numerator: 32, denominator: 125, status: .ok)
        let suppressed = ReportMetric(id: "r", value: nil, numerator: nil, denominator: nil, status: .insufficientSample)
        let definition = MetricDefinition(id: "r", label: "Rate", unit: .rate, window: .current, numerator: "A", denominator: "B")
        #expect(MetricFormatting.value(suppressed, unit: .rate) == "Withheld")
        #expect(MetricFormatting.caption(rate, definition: definition, minimumSample: 5) == "32 of 125")
        #expect(MetricFormatting.caption(suppressed, definition: definition, minimumSample: 5) == "Fewer than 5 in the group")
        #expect(definition.formula == "A ÷ B")
        #expect(MetricFormatting.value(ReportMetric(id: "d", value: 2.5, numerator: nil, denominator: 4, status: .ok), unit: .days).hasSuffix("days"))
    }

    @Test func decodesServerReport() throws {
        let json = """
        {"report":{"dictionaryVersion":1,"scope":{"districtID":"d1","schoolIDs":["s"],"isDistrictWide":true,"from":"2026-06-25","to":"2026-09-22","timeZone":"UTC","grade":null,"staffUserID":null},
        "computedAt":"2026-09-22T12:00:00.000Z","isPartial":false,"includesEarlyChildhood":true,
        "metrics":[{"id":"students.served","value":8,"numerator":8,"denominator":null,"status":"ok"}],
        "plansByStatus":{"active":1},"plansByModel":{},"trend":[{"week":"2026-09-21","surveysSubmitted":1,"plansApproved":0,"tasksCompleted":2,"observations":1}],
        "sites":[]},
        "definitions":[{"id":"students.served","label":"Students served","unit":"count","window":"current","numerator":"n","denominator":null},
                       {"id":"ec.observations","label":"Observations","unit":"count","window":"window","numerator":"n","denominator":null,"earlyChildhoodOnly":true}],
        "minimumSample":5}
        """
        let result = try JSONDecoder().decode(DistrictReportResult.self, from: Data(json.utf8))
        #expect(result.report.metric("students.served")?.value == 8)
        #expect(result.definition("ec.observations")?.earlyChildhoodOnly == true)
        #expect(result.report.trend.first?.date != .distantPast)
        #expect(result.report.computedDate != nil)
    }

    @MainActor
    @Test func pdfRendersPages() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "report-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try ReportPDFRenderer.render(result: InMemoryReportingRepository.result(), organizationName: "Unified", to: url)
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 3)
    }
}
