import Foundation

/// The only catalog identifiers permitted by the canonical product contract.
nonisolated enum CatalogName: String, Codable, CaseIterable, Sendable {
    case careers
    case interests
    case globalResources
    case tmiModels
    case surveyDefinitions
}

/// Canonical Firestore path construction.
///
/// Production repositories use this district-scoped tree. Historical paths
/// belong in `Migration/LegacyFirestorePaths.swift` and are never added here.
nonisolated enum FirestorePaths {
    // MARK: - Personal profile

    static func privateProfile(userID: String) -> String {
        path("users", userID, "private", "profile")
    }

    static func preferences(userID: String) -> String {
        path("users", userID, "preferences", "settings")
    }

    // MARK: - District, schools, and membership

    static func district(districtID: String) -> String {
        path("districts", districtID)
    }

    static func schools(districtID: String) -> String {
        path(district(districtID: districtID), "schools")
    }

    static func school(districtID: String, schoolID: String) -> String {
        path(schools(districtID: districtID), schoolID)
    }

    static func members(districtID: String) -> String {
        path(district(districtID: districtID), "members")
    }

    static func member(districtID: String, userID: String) -> String {
        path(members(districtID: districtID), userID)
    }

    static func memberAcknowledgements(districtID: String, userID: String) -> String {
        path(member(districtID: districtID, userID: userID), "acknowledgements")
    }

    static func memberAcknowledgement(
        districtID: String,
        userID: String,
        acknowledgementID: String
    ) -> String {
        path(
            memberAcknowledgements(districtID: districtID, userID: userID),
            acknowledgementID
        )
    }

    // MARK: - Students

    static func students(districtID: String) -> String {
        path(district(districtID: districtID), "students")
    }

    static func student(districtID: String, studentID: String) -> String {
        path(students(districtID: districtID), studentID)
    }

    static func studentInterests(districtID: String, studentID: String) -> String {
        studentCollection("interests", districtID: districtID, studentID: studentID)
    }

    static func studentInterest(
        districtID: String,
        studentID: String,
        interestID: String
    ) -> String {
        path(studentInterests(districtID: districtID, studentID: studentID), interestID)
    }

    static func studentCareers(districtID: String, studentID: String) -> String {
        studentCollection("careers", districtID: districtID, studentID: studentID)
    }

    static func studentCareer(
        districtID: String,
        studentID: String,
        careerID: String
    ) -> String {
        path(studentCareers(districtID: districtID, studentID: studentID), careerID)
    }

    static func studentResources(districtID: String, studentID: String) -> String {
        studentCollection("resources", districtID: districtID, studentID: studentID)
    }

    static func studentResource(
        districtID: String,
        studentID: String,
        relationshipID: String
    ) -> String {
        path(studentResources(districtID: districtID, studentID: studentID), relationshipID)
    }

    static func studentSurveys(districtID: String, studentID: String) -> String {
        studentCollection("surveys", districtID: districtID, studentID: studentID)
    }

    static func studentSurvey(
        districtID: String,
        studentID: String,
        assignmentID: String
    ) -> String {
        path(studentSurveys(districtID: districtID, studentID: studentID), assignmentID)
    }

    static func studentResponses(districtID: String, studentID: String) -> String {
        studentCollection("responses", districtID: districtID, studentID: studentID)
    }

    static func studentResponse(
        districtID: String,
        studentID: String,
        responseID: String
    ) -> String {
        path(studentResponses(districtID: districtID, studentID: studentID), responseID)
    }

    static func studentNotes(districtID: String, studentID: String) -> String {
        studentCollection("notes", districtID: districtID, studentID: studentID)
    }

    static func studentNote(districtID: String, studentID: String, noteID: String) -> String {
        path(studentNotes(districtID: districtID, studentID: studentID), noteID)
    }

    static func studentRestrictedRecords(districtID: String, studentID: String) -> String {
        studentCollection("restrictedRecords", districtID: districtID, studentID: studentID)
    }

    static func studentRestrictedRecord(
        districtID: String,
        studentID: String,
        recordID: String
    ) -> String {
        path(
            studentRestrictedRecords(districtID: districtID, studentID: studentID),
            recordID
        )
    }

    static func studentConsents(districtID: String, studentID: String) -> String {
        studentCollection("consents", districtID: districtID, studentID: studentID)
    }

    static func studentConsent(
        districtID: String,
        studentID: String,
        consentID: String
    ) -> String {
        path(studentConsents(districtID: districtID, studentID: studentID), consentID)
    }

    static func studentProgress(districtID: String, studentID: String) -> String {
        studentCollection("progress", districtID: districtID, studentID: studentID)
    }

    static func studentProgressEntry(
        districtID: String,
        studentID: String,
        entryID: String
    ) -> String {
        path(studentProgress(districtID: districtID, studentID: studentID), entryID)
    }

    // MARK: - Plans

    static func plans(districtID: String) -> String {
        path(district(districtID: districtID), "plans")
    }

    static func plan(districtID: String, planID: String) -> String {
        path(plans(districtID: districtID), planID)
    }

    static func planGoals(districtID: String, planID: String) -> String {
        planCollection("goals", districtID: districtID, planID: planID)
    }

    static func planGoal(districtID: String, planID: String, goalID: String) -> String {
        path(planGoals(districtID: districtID, planID: planID), goalID)
    }

    static func planActions(districtID: String, planID: String) -> String {
        planCollection("actions", districtID: districtID, planID: planID)
    }

    static func planAction(districtID: String, planID: String, actionID: String) -> String {
        path(planActions(districtID: districtID, planID: planID), actionID)
    }

    static func planProgress(districtID: String, planID: String) -> String {
        planCollection("progress", districtID: districtID, planID: planID)
    }

    static func planProgressEntry(
        districtID: String,
        planID: String,
        entryID: String
    ) -> String {
        path(planProgress(districtID: districtID, planID: planID), entryID)
    }

    static func planApprovals(districtID: String, planID: String) -> String {
        planCollection("approvals", districtID: districtID, planID: planID)
    }

    static func planApproval(
        districtID: String,
        planID: String,
        approvalID: String
    ) -> String {
        path(planApprovals(districtID: districtID, planID: planID), approvalID)
    }

    static func planResources(districtID: String, planID: String) -> String {
        planCollection("resources", districtID: districtID, planID: planID)
    }

    static func planResource(
        districtID: String,
        planID: String,
        relationshipID: String
    ) -> String {
        path(planResources(districtID: districtID, planID: planID), relationshipID)
    }

    static func planForms(districtID: String, planID: String) -> String {
        planCollection("forms", districtID: districtID, planID: planID)
    }

    static func planForm(districtID: String, planID: String, assignmentID: String) -> String {
        path(planForms(districtID: districtID, planID: planID), assignmentID)
    }

    static func planRevisions(districtID: String, planID: String) -> String {
        planCollection("revisions", districtID: districtID, planID: planID)
    }

    static func planRevision(
        districtID: String,
        planID: String,
        revisionID: String
    ) -> String {
        path(planRevisions(districtID: districtID, planID: planID), revisionID)
    }

    // MARK: - District collaboration

    static func meetings(districtID: String) -> String {
        districtCollection("meetings", districtID: districtID)
    }

    static func meeting(districtID: String, meetingID: String) -> String {
        path(meetings(districtID: districtID), meetingID)
    }

    static func tasks(districtID: String) -> String {
        districtCollection("tasks", districtID: districtID)
    }

    static func task(districtID: String, taskID: String) -> String {
        path(tasks(districtID: districtID), taskID)
    }

    static func formTemplates(districtID: String) -> String {
        districtCollection("formTemplates", districtID: districtID)
    }

    static func formTemplate(districtID: String, templateID: String) -> String {
        path(formTemplates(districtID: districtID), templateID)
    }

    static func formAssignments(districtID: String) -> String {
        districtCollection("formAssignments", districtID: districtID)
    }

    static func formAssignment(districtID: String, assignmentID: String) -> String {
        path(formAssignments(districtID: districtID), assignmentID)
    }

    static func formAssignmentRespondents(
        districtID: String,
        assignmentID: String
    ) -> String {
        path(formAssignment(districtID: districtID, assignmentID: assignmentID), "respondents")
    }

    static func formAssignmentRespondent(
        districtID: String,
        assignmentID: String,
        respondentID: String
    ) -> String {
        path(
            formAssignmentRespondents(
                districtID: districtID,
                assignmentID: assignmentID
            ),
            respondentID
        )
    }

    static func resources(districtID: String) -> String {
        districtCollection("resources", districtID: districtID)
    }

    static func resource(districtID: String, resourceID: String) -> String {
        path(resources(districtID: districtID), resourceID)
    }

    static func notifications(districtID: String) -> String {
        districtCollection("notifications", districtID: districtID)
    }

    static func notification(districtID: String, notificationID: String) -> String {
        path(notifications(districtID: districtID), notificationID)
    }

    static func studentModeSessions(districtID: String) -> String {
        districtCollection("studentModeSessions", districtID: districtID)
    }

    static func studentModeSession(districtID: String, sessionID: String) -> String {
        path(studentModeSessions(districtID: districtID), sessionID)
    }

    static func auditEvents(districtID: String) -> String {
        districtCollection("auditEvents", districtID: districtID)
    }

    static func auditEvent(districtID: String, eventID: String) -> String {
        path(auditEvents(districtID: districtID), eventID)
    }

    static func metricSnapshots(districtID: String) -> String {
        districtCollection("metricSnapshots", districtID: districtID)
    }

    static func metricSnapshot(districtID: String, snapshotID: String) -> String {
        path(metricSnapshots(districtID: districtID), snapshotID)
    }

    // MARK: - Catalogs

    static func catalog(_ name: CatalogName) -> String {
        path("catalogs", name.rawValue)
    }

    static func catalogItems(_ name: CatalogName) -> String {
        path(catalog(name), "items")
    }

    static func catalogItem(_ name: CatalogName, itemID: String) -> String {
        path(catalogItems(name), itemID)
    }

    /// Auditable collection shapes used by rules, migration, and source tests.
    static let productionCollectionTemplates: Set<String> = [
        "users/{uid}/private",
        "users/{uid}/preferences",
        "districts/{districtId}/schools",
        "districts/{districtId}/members",
        "districts/{districtId}/members/{uid}/acknowledgements",
        "districts/{districtId}/students",
        "districts/{districtId}/students/{studentId}/interests",
        "districts/{districtId}/students/{studentId}/careers",
        "districts/{districtId}/students/{studentId}/resources",
        "districts/{districtId}/students/{studentId}/surveys",
        "districts/{districtId}/students/{studentId}/responses",
        "districts/{districtId}/students/{studentId}/notes",
        "districts/{districtId}/students/{studentId}/restrictedRecords",
        "districts/{districtId}/students/{studentId}/consents",
        "districts/{districtId}/students/{studentId}/progress",
        "districts/{districtId}/plans",
        "districts/{districtId}/plans/{planId}/goals",
        "districts/{districtId}/plans/{planId}/actions",
        "districts/{districtId}/plans/{planId}/progress",
        "districts/{districtId}/plans/{planId}/approvals",
        "districts/{districtId}/plans/{planId}/resources",
        "districts/{districtId}/plans/{planId}/forms",
        "districts/{districtId}/plans/{planId}/revisions",
        "districts/{districtId}/meetings",
        "districts/{districtId}/tasks",
        "districts/{districtId}/formTemplates",
        "districts/{districtId}/formAssignments",
        "districts/{districtId}/formAssignments/{assignmentId}/respondents",
        "districts/{districtId}/resources",
        "districts/{districtId}/notifications",
        "districts/{districtId}/studentModeSessions",
        "districts/{districtId}/auditEvents",
        "districts/{districtId}/metricSnapshots",
        "catalogs/{catalogName}/items",
    ]

    private static func districtCollection(_ name: String, districtID: String) -> String {
        path(district(districtID: districtID), name)
    }

    private static func studentCollection(
        _ name: String,
        districtID: String,
        studentID: String
    ) -> String {
        path(student(districtID: districtID, studentID: studentID), name)
    }

    private static func planCollection(
        _ name: String,
        districtID: String,
        planID: String
    ) -> String {
        path(plan(districtID: districtID, planID: planID), name)
    }

    private static func path(_ components: String...) -> String {
        components.joined(separator: "/")
    }
}
