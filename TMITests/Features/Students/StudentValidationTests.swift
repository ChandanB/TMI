import Foundation
import Testing
@testable import TMI

@Suite("Canonical student validation")
struct StudentValidationTests {
    @Test("Draft normalization trims and collapses user-entered values")
    func draftNormalization() {
        let draft = StudentDraft(
            displayName: "  Ava   Stone\n",
            schoolID: " school-a ",
            grade: "  7  ",
            studentIdentifier: " 0012 ",
            dateOfBirth: nil,
            pronouns: "  she   / her ",
            assignedMemberIDs: [" teacher-a ", "teacher-b"]
        )

        let normalized = draft.normalized

        #expect(normalized.displayName == "Ava Stone")
        #expect(normalized.schoolID == "school-a")
        #expect(normalized.grade == "7")
        #expect(normalized.studentIdentifier == "0012")
        #expect(normalized.pronouns == "she / her")
        #expect(normalized.assignedMemberIDs == ["teacher-a", "teacher-b"])
    }

    @Test("District, school, display name, and grade are required")
    func requiredFields() {
        let draft = StudentDraft(
            displayName: "  ",
            schoolID: "",
            grade: "\n",
            studentIdentifier: nil,
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: []
        )

        let fields = Set(
            StudentValidation.issues(
                for: draft,
                districtID: "",
                policy: .standard
            )
                .map(\.field)
        )

        #expect(fields.contains(.districtID))
        #expect(fields.contains(.schoolID))
        #expect(fields.contains(.displayName))
        #expect(fields.contains(.grade))
    }

    @Test("A trusted district policy can require a student identifier")
    func requiredInstitutionalIdentifierPolicy() {
        let fields = Set(
            StudentValidation.issues(
                for: validDraft(studentIdentifier: nil),
                districtID: "district-a",
                policy: StudentValidationPolicy(requiresStudentIdentifier: true)
            )
            .map(\.field)
        )

        #expect(fields.contains(.studentIdentifier))
        #expect(
            !StudentValidation.issues(
                for: validDraft(studentIdentifier: nil),
                districtID: "district-a",
                policy: StudentValidationPolicy(requiresStudentIdentifier: false)
            )
            .contains { $0.field == .studentIdentifier }
        )
    }

    @Test("Future birth dates and overlong pronouns are rejected")
    func optionalFieldLimits() {
        let draft = validDraft(
            dateOfBirth: Date(timeIntervalSince1970: 2_000),
            pronouns: String(repeating: "p", count: StudentValidation.maximumPronounLength + 1)
        )

        let fields = Set(
            StudentValidation.issues(
                for: draft,
                districtID: "district-a",
                policy: .standard,
                now: Date(timeIntervalSince1970: 1_000)
            )
            .map(\.field)
        )

        #expect(fields.contains(.dateOfBirth))
        #expect(fields.contains(.pronouns))
    }

    @Test("Institutional identifiers are normalized and length bounded")
    func institutionalIdentifierValidation() {
        let draft = validDraft(
            studentIdentifier: "  \(String(repeating: "1", count: StudentValidation.maximumStudentIdentifierLength + 1))  "
        )

        let normalized = draft.normalized
        let issues = StudentValidation.issues(
            for: normalized,
            districtID: "district-a",
            policy: .standard
        )

        #expect(normalized.studentIdentifier?.first == "1")
        #expect(normalized.studentIdentifier?.last == "1")
        #expect(issues.contains { $0.field == .studentIdentifier })

        let controlIssues = StudentValidation.issues(
            for: validDraft(studentIdentifier: "00\n12"),
            districtID: "district-a",
            policy: .standard
        )
        #expect(controlIssues.contains { $0.field == .studentIdentifier })
    }

    @Test("Unsafe controls and oversized Unicode payloads are rejected")
    func unsafeTextAndPayloadSizeValidation() {
        let oversizedName = "A" + String(
            repeating: "\u{0301}",
            count: StudentValidation.maximumDisplayNameUTF8Length
        )
        let draft = validDraft(
            displayName: oversizedName,
            pronouns: "she\u{0000}her"
        )

        let fields = Set(
            StudentValidation.issues(
                for: draft,
                districtID: "district-a",
                policy: .standard
            )
                .map(\.field)
        )

        #expect(fields.contains(.displayName))
        #expect(fields.contains(.pronouns))
    }

    @Test("Duplicate candidates use same-school normalized name, grade, and identifier")
    func duplicateUsesSchoolNameGradeAndIdentifier() {
        let draft = validDraft(
            displayName: "  Ava  Stone ",
            schoolID: "school-a",
            grade: " 7 ",
            studentIdentifier: " 0012 "
        )
        let candidates = [
            record(id: "match", schoolID: "school-a", identifier: "0012"),
            record(id: "other-school", schoolID: "school-b", identifier: "0012"),
            record(id: "other-id", schoolID: "school-a", identifier: "0099"),
        ]

        #expect(
            StudentDuplicatePolicy.candidates(
                for: draft,
                in: candidates,
                districtID: "district-a"
            )
                == ["match"]
        )
    }

    @Test("Duplicate candidate order is stable and archived records remain visible")
    func duplicateOrderIsDeterministic() {
        let draft = validDraft(studentIdentifier: nil)
        let candidates = [
            record(id: "student-z", identifier: nil, isArchived: true),
            record(id: "student-a", identifier: nil),
        ]

        #expect(
            StudentDuplicatePolicy.candidates(
                for: draft,
                in: candidates,
                districtID: "district-a"
            )
                == ["student-a", "student-z"]
        )
    }

    @Test("An edit excludes its own record without hiding another duplicate")
    func editExcludesCurrentRecord() {
        let draft = validDraft(studentIdentifier: "0012")
        let candidates = [
            record(id: "student-current", identifier: "0012"),
            record(id: "student-duplicate", identifier: "0012"),
        ]

        #expect(
            StudentDuplicatePolicy.candidates(
                for: draft,
                in: candidates,
                districtID: "district-a",
                excludingRecordID: "student-current"
            ) == ["student-duplicate"]
        )
    }

    @Test("Name duplicate matching is case and diacritic insensitive")
    func duplicateNameNormalization() {
        let draft = validDraft(displayName: "  JOSÉ   Stone ", studentIdentifier: nil)
        let candidates = [
            StudentRecord(
                id: "match",
                districtID: "district-a",
                schoolID: "school-a",
                displayName: "Jose Stone",
                grade: "7",
                studentIdentifier: "different-id",
                dateOfBirth: nil,
                pronouns: nil,
                assignedMemberIDs: [],
                isArchived: false,
                metadata: record(id: "metadata", identifier: nil).metadata
            ),
        ]

        #expect(
            StudentDuplicatePolicy.candidates(
                for: draft,
                in: candidates,
                districtID: "district-a"
            ) == ["match"]
        )
    }

    @Test("Duplicate candidates never cross the trusted district boundary")
    func duplicateCandidatesAreDistrictScoped() {
        let draft = validDraft(studentIdentifier: "0012")
        let candidates = [
            record(id: "same-district", identifier: "0012"),
            record(id: "other-district", districtID: "district-b", identifier: "0012"),
        ]

        #expect(
            StudentDuplicatePolicy.candidates(
                for: draft,
                in: candidates,
                districtID: "district-a"
            ) == ["same-district"]
        )
    }

    @Test("Canonical records preserve metadata and focused optional fields")
    func recordRoundTrip() throws {
        let original = record(
            id: "student-a",
            identifier: "0012",
            dateOfBirth: Date(timeIntervalSince1970: 100),
            pronouns: "she / her"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StudentRecord.self, from: data)

        #expect(decoded == original)
        #expect(decoded.metadata.recordVersion == 3)
    }

    private func validDraft(
        displayName: String = "Ava Stone",
        schoolID: String = "school-a",
        grade: String = "7",
        studentIdentifier: String? = "0012",
        dateOfBirth: Date? = nil,
        pronouns: String? = nil
    ) -> StudentDraft {
        StudentDraft(
            displayName: displayName,
            schoolID: schoolID,
            grade: grade,
            studentIdentifier: studentIdentifier,
            dateOfBirth: dateOfBirth,
            pronouns: pronouns,
            assignedMemberIDs: ["teacher-a"]
        )
    }

    private func record(
        id: String,
        districtID: String = "district-a",
        schoolID: String = "school-a",
        identifier: String?,
        isArchived: Bool = false,
        dateOfBirth: Date? = nil,
        pronouns: String? = nil
    ) -> StudentRecord {
        StudentRecord(
            id: id,
            districtID: districtID,
            schoolID: schoolID,
            displayName: "Ava Stone",
            grade: "7",
            studentIdentifier: identifier,
            dateOfBirth: dateOfBirth,
            pronouns: pronouns,
            assignedMemberIDs: ["teacher-a"],
            isArchived: isArchived,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 3,
                createdAt: Date(timeIntervalSince1970: 10),
                createdBy: "teacher-a",
                updatedAt: Date(timeIntervalSince1970: 20),
                updatedBy: "teacher-a"
            )
        )
    }
}
