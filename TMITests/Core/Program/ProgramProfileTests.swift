import Foundation
import Testing
@testable import TMI

@Suite("Program profiles")
struct ProgramProfileTests {
    private func organization(
        defaultProgram: ProgramType,
        overrides: [String: ProgramType?]
    ) -> OrganizationProfile {
        OrganizationProfile(
            organizationID: "org",
            name: "Org",
            kind: .schoolDistrict,
            defaultProgram: defaultProgram,
            sites: overrides.keys.sorted().map { id in
                OrganizationProfile.Site(id: id, name: "Site \(id)", programOverride: overrides[id] ?? nil)
            }
        )
    }

    @Test("Sites inherit the organization program unless they override it")
    func siteResolution() {
        let org = organization(defaultProgram: .k12, overrides: ["a": nil, "b": .earlyChildhood])
        #expect(org.program(forSchoolID: "a") == .k12)
        #expect(org.program(forSchoolID: "b") == .earlyChildhood)
        #expect(org.program(forSchoolID: "unknown") == .k12)
        #expect(org.siteName("b") == "Site b")
        #expect(org.siteName("unknown") == "unknown")
    }

    @Test("Organization-wide screens use early childhood only when every site is")
    func shellProgram() {
        #expect(organization(defaultProgram: .k12, overrides: ["a": nil, "b": .earlyChildhood]).shellProgram == .k12)
        #expect(organization(defaultProgram: .earlyChildhood, overrides: ["a": nil]).shellProgram == .earlyChildhood)
        #expect(organization(defaultProgram: .k12, overrides: ["a": .earlyChildhood]).shellProgram == .earlyChildhood)
    }

    @Test("Early childhood turns off careers and self-report and requires a birth date")
    func switches() {
        let profile = ProgramProfile.for(.earlyChildhood)
        #expect(!profile.showsCareers)
        #expect(!profile.learnerSelfReports)
        #expect(profile.requiresDateOfBirth)
        #expect(profile.usesFamilyIntake)
        #expect(profile.gradeChoices == AgeGroup.allCases.map(\.rawValue))
        #expect(ProgramProfile.for(.k12).showsCareers)
        #expect(ProgramProfile.for(.k12).gradeChoices.contains("12"))
    }

    @Test("Terminology describes grades per program")
    func terminology() {
        #expect(Terminology.k12.gradeDescription("7") == "Grade 7")
        #expect(Terminology.earlyChildhood.gradeDescription("Toddler") == "Toddler")
        #expect(Terminology.earlyChildhood.learners == "Children")
        #expect(Terminology.earlyChildhood.site == "Center")
    }

    @Test("Age groups are suggested from date of birth")
    func ageGroups() throws {
        let calendar = Calendar(identifier: .gregorian)
        let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        func born(monthsAgo: Int) throws -> Date {
            try #require(calendar.date(byAdding: .month, value: -monthsAgo, to: reference))
        }
        #expect(AgeGroup.suggested(forDateOfBirth: try born(monthsAgo: 6), on: reference, calendar: calendar) == .infant)
        #expect(AgeGroup.suggested(forDateOfBirth: try born(monthsAgo: 18), on: reference, calendar: calendar) == .toddler)
        #expect(AgeGroup.suggested(forDateOfBirth: try born(monthsAgo: 30), on: reference, calendar: calendar) == .twos)
        #expect(AgeGroup.suggested(forDateOfBirth: try born(monthsAgo: 40), on: reference, calendar: calendar) == .preschool3)
        #expect(AgeGroup.suggested(forDateOfBirth: try born(monthsAgo: 50), on: reference, calendar: calendar) == .preK4)
        #expect(AgeGroup.suggested(forDateOfBirth: try born(monthsAgo: 60), on: reference, calendar: calendar) == .transitionalK)
        #expect(!AgeGroup.twos.supportsPictureChoice)
        #expect(AgeGroup.preschool3.supportsPictureChoice)
        #expect(AgeGroup.allCases.allSatisfy { $0.rawValue.count <= StudentValidation.maximumGradeLength })
    }

    @Test("Early-childhood validation requires a birth date and uses child vocabulary")
    func validation() {
        let draft = StudentDraft(
            displayName: "",
            schoolID: "center-1",
            grade: "Toddler",
            studentIdentifier: "",
            dateOfBirth: nil,
            pronouns: "",
            assignedMemberIDs: ["staff-1"]
        )
        let policy = StudentValidationPolicy.standard.applying(.earlyChildhood)
        let issues = StudentValidation.issues(for: draft, districtID: "org", policy: policy)
        #expect(issues.contains { $0.field == .dateOfBirth })
        let nameIssue = issues.first { $0.field == .displayName }
        #expect(nameIssue?.message(using: .earlyChildhood) == "Child name is required.")
        #expect(!StudentValidation.issues(for: draft, districtID: "org", policy: .standard).contains { $0.field == .dateOfBirth })
    }

    @Test("Plan wizard wording follows the program")
    @MainActor
    func planWizardWording() {
        #expect(PlanEditorState.Step.interestsAndCareers.title(for: .earlyChildhood) == "Interests & play")
        #expect(PlanEditorState.Step.interestsAndCareers.title(for: .k12) == "Interests & careers")
        #expect(PlanEditorState.Step.studentVoiceAndFamily.title(for: .earlyChildhood) == "Child's voice & family partnership")
        #expect(PlanEditorState.SubmissionIssue.studentVoiceRequired.message(for: .earlyChildhood).contains("observed"))
        #expect(PlanEditorState.SubmissionIssue.studentVoiceRequired.message(for: .k12) == "Record the student's voice in their own words.")
    }

    @Test("Early-childhood model guidance and availability follow age groups")
    func modelGuidance() {
        #expect(TMIPlanModel.chaseYourSpace.description(for: .earlyChildhood) != TMIPlanModel.chaseYourSpace.description)
        #expect(TMIPlanModel.chaseYourSpace.description(for: .k12) == TMIPlanModel.chaseYourSpace.description)
        #expect(!TMIPlanModel.chaseYourSpace.description(for: .earlyChildhood).localizedCaseInsensitiveContains("career"))
        #expect(TMIPlanModel.available(for: .earlyChildhood, grade: "Infant") == [.acknowledgeInterests])
        #expect(TMIPlanModel.available(for: .earlyChildhood, grade: "Pre-K 4s") == TMIPlanModel.allCases)
        #expect(TMIPlanModel.available(for: .k12, grade: "Infant") == TMIPlanModel.allCases)
        #expect(ActionAudience.choices(for: .earlyChildhood) == [.staff, .family])
        #expect(ActionAudience.choices(for: .k12) == [.staff, .student])
    }

    @Test("Tabs use program vocabulary")
    func tabs() {
        #expect(AppTab.students.title(for: .earlyChildhood) == "Children")
        #expect(AppTab.district.title(for: .earlyChildhood) == "Reports")
        #expect(AppTab.students.title(for: .k12) == "Students")
    }

    @Test("Legacy school and district models decode canonical documents")
    @MainActor
    func canonicalDecoding() throws {
        let school = try JSONDecoder().decode(School.self, from: Data(#"{"schoolID":"s1","districtID":"d1","name":"Sunshine East","programType":"earlyChildhood"}"#.utf8))
        #expect(school.name == "Sunshine East")
        #expect(school.districtId == "d1")
        #expect(school.programType == .earlyChildhood)
        let bare = try JSONDecoder().decode(School.self, from: Data(#"{"schoolID":"s2","districtID":"d1"}"#.utf8))
        #expect(bare.name == "s2")
        #expect(bare.programType == nil)
        let district = try JSONDecoder().decode(District.self, from: Data(#"{"districtID":"d1","name":"Sunshine","programType":"earlyChildhood","organizationKind":"earlyLearningProvider"}"#.utf8))
        #expect(district.programType == .earlyChildhood)
        #expect(district.organizationKind == .earlyLearningProvider)
    }
}
