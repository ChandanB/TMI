import Foundation
import Testing
@testable import TMI

@Suite("Survey document identity")
struct SurveyIdentityTests {
    @Test("Document identity is never persisted inside the survey payload")
    func encodingExcludesDocumentIdentity() throws {
        let survey = Survey(
            id: "stale-document-id",
            title: "Interest survey",
            studentId: "student-1",
            date: Date(timeIntervalSince1970: 1_000),
            questions: [],
            completed: false,
            surveyType: .interests
        )

        let data = try JSONEncoder().encode(survey)
        let payload = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let decoded = try JSONDecoder().decode(Survey.self, from: data)

        #expect(payload["id"] == nil)
        #expect(decoded.id == nil)
    }


}
