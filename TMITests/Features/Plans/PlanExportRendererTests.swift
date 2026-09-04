import Foundation
import Testing
@testable import TMI

@Suite("Plan export rendering")
struct PlanExportRendererTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Every page says what it is, even separated from the rest")
    func everyPageCarriesItsClassification() {
        // A page that ends up on its own — printed, photocopied, dropped in a
        // folder — still has to declare what it carries and which export made
        // it.
        let pages = PlanExportRenderer.pages(for: document(goalCount: 40))

        #expect(pages.count > 1)
        for page in pages {
            #expect(page.footer.contains("Confidential student record"))
            #expect(page.footer.contains("audit-42"))
            #expect(page.heading == PlanExportKind.professionalPlan.title)
        }
    }

    @Test("The same document always renders the same pages")
    func renderingIsDeterministic() {
        let first = PlanExportRenderer.pages(for: document(goalCount: 12))
        let second = PlanExportRenderer.pages(for: document(goalCount: 12))

        #expect(first == second)
        // Dates are formatted fixed rather than by locale, so an export does
        // not change shape depending on who produced it.
        #expect(first.flatMap(\.lines).contains { $0.contains("2023-11-14") })
    }

    @Test("Pages are numbered against a real total")
    func pagesAreNumbered() {
        let pages = PlanExportRenderer.pages(for: document(goalCount: 40))

        #expect(pages.map(\.pageNumber) == Array(1...pages.count))
        #expect(pages.allSatisfy { $0.pageCount == pages.count })
    }

    @Test("An export with nothing to say still produces a page")
    func emptyDocumentStillRenders() {
        // A file that renders zero pages is indistinguishable from a failed
        // export, which is worse than a page saying there is nothing.
        let pages = PlanExportRenderer.pages(for: document(goalCount: 0, includeProgress: false))

        #expect(pages.count == 1)
        #expect(pages[0].footer.contains("audit-42"))
    }

    @Test("The renderer can only draw what the projection authorized")
    func rendererOnlySeesAuthorizedContent() throws {
        // The unauthorized reader's document is built without the staff-only
        // line, so it cannot appear in the rendering. There is nothing here to
        // redact — it was never present.
        let material = PlanExportMaterial(
            planID: "plan-1",
            studentID: "student-1",
            studentDisplayName: "Ava Stone",
            model: .chaseYourSpace,
            rationale: ["A staff member identified Belonging."],
            goals: [],
            actions: [],
            progress: [
                ProgressRecord(
                    id: "p1", planID: "plan-1", studentID: "student-1",
                    source: .goal, sourceID: "goal-1", measuredValue: nil,
                    note: "Staff-only concern noted.", visibility: .staffOnly,
                    authorID: "teacher-1", recordedAt: now
                ),
                ProgressRecord(
                    id: "p2", planID: "plan-1", studentID: "student-1",
                    source: .goal, sourceID: "goal-1", measuredValue: nil,
                    note: "Tried something new today.", visibility: .sharedWithStudent,
                    authorID: "teacher-1", recordedAt: now
                ),
            ],
            restrictedNotes: []
        )
        let restricted = try PlanExportProjection.document(
            kind: .progressReport,
            material: material,
            capabilities: [.reportExport, .studentReadDetail],
            auditID: "audit-42"
        )

        let text = PlanExportRenderer.pages(for: restricted).flatMap(\.lines).joined(separator: "\n")
        #expect(!text.contains("Staff-only concern noted."))
        #expect(text.contains("Tried something new today."))
    }

    @Test("A PDF is produced and starts with a PDF header")
    func pdfIsProduced() throws {
        let data = try #require(PlanExportRenderer.pdfData(for: document(goalCount: 3)))

        #expect(data.count > 0)
        #expect(data.prefix(5) == Data("%PDF-".utf8))
    }

    // MARK: - Fixture

    private func document(
        goalCount: Int,
        includeProgress: Bool = true
    ) -> PlanExportDocument {
        PlanExportDocument(
            kind: .professionalPlan,
            planID: "plan-1",
            studentDisplayName: "Ava Stone",
            model: .chaseYourSpace,
            rationale: ["A staff member identified Belonging."],
            goals: (0..<goalCount).map { index in
                PlanExportGoal(
                    title: "Goal \(index)",
                    baseline: "Sits alone",
                    target: "Sits with a peer",
                    dueDate: now,
                    status: .inProgress
                )
            },
            progress: includeProgress
                ? [PlanExportProgressLine(recordedAt: now, summary: "Observed.")]
                : [],
            completionPercentage: 50,
            classification: "Confidential student record",
            auditID: "audit-42"
        )
    }
}
