import Foundation
import Testing
@testable import TMI

@Suite("Canonical survey engine")
struct SurveyDefinitionTests {
    @Test("Every supported question type round-trips with a typed answer")
    func allQuestionTypesRoundTrip() throws {
        let definition = try surveyDefinition()
        let answers: [String: SurveyAnswer] = [
            "single": .single("science"),
            "multiple": .multiple(["building", "drawing"]),
            "text": .text("Robotics club"),
            "rating": .rating(4),
            "image": .image("forest"),
        ]

        try definition.validate(answers: answers, requireVisibleAnswers: true)
        let data = try JSONEncoder().encode(answers)
        let decoded = try JSONDecoder().decode(
            [String: SurveyAnswer].self,
            from: data
        )

        #expect(decoded == answers)
    }

    @Test("Published definitions use the canonical callable schema")
    func definitionCanonicalSchemaRoundTrip() throws {
        let definition = try surveyDefinition()
        let data = try JSONEncoder().encode(definition)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let questions = try #require(object["questions"] as? [[String: Any]])

        #expect(object["definitionID"] as? String == definition.id)
        #expect(object["state"] as? String == "published")
        #expect(questions.first?["type"] as? String == "singleChoice")
        #expect(questions.first?["required"] as? Bool == true)
        #expect(questions.first?["kind"] == nil)
        #expect(try JSONDecoder().decode(SurveyDefinition.self, from: data) == definition)
    }

    @Test("Visibility uses priority then stable rule ID and preserves question order")
    func deterministicBranching() throws {
        let definition = try surveyDefinition(branchRules: [
            SurveyBranchRule(
                id: "z-hide-details",
                sourceQuestionID: "single",
                targetQuestionID: "text",
                priority: 10,
                effect: .hide,
                predicate: .equals("science")
            ),
            SurveyBranchRule(
                id: "a-show-details",
                sourceQuestionID: "single",
                targetQuestionID: "text",
                priority: 10,
                effect: .show,
                predicate: .equals("science")
            ),
        ])

        let visible = try definition.visibleQuestionIDs(
            answers: ["single": .single("science")]
        )

        #expect(visible == ["single", "multiple", "text", "rating", "image"])
    }

    @Test("Unknown branch references and cycles fail closed")
    func invalidBranchGraphRejected() throws {
        #expect(throws: SurveyDefinitionError.unknownQuestionReference("missing")) {
            _ = try surveyDefinition(branchRules: [
                SurveyBranchRule(
                    id: "unknown",
                    sourceQuestionID: "missing",
                    targetQuestionID: "text",
                    predicate: .textIsNotEmpty
                ),
            ])
        }

        #expect(throws: SurveyDefinitionError.branchCycle) {
            _ = try surveyDefinition(branchRules: [
                SurveyBranchRule(
                    id: "one",
                    sourceQuestionID: "single",
                    targetQuestionID: "text",
                    predicate: .equals("science")
                ),
                SurveyBranchRule(
                    id: "two",
                    sourceQuestionID: "text",
                    targetQuestionID: "single",
                    predicate: .textIsNotEmpty
                ),
            ])
        }
    }

    @Test("Required validation applies only to visible questions")
    func requiredVisibleValidation() throws {
        let definition = try surveyDefinition(branchRules: [
            SurveyBranchRule(
                id: "show-text-for-science",
                sourceQuestionID: "single",
                targetQuestionID: "text",
                predicate: .equals("science")
            ),
        ])

        try definition.validate(
            answers: [
                "single": .single("art"),
                "multiple": .multiple(["drawing"]),
                "rating": .rating(3),
                "image": .image("city"),
            ],
            requireVisibleAnswers: true
        )

        #expect(throws: SurveyDefinitionError.requiredAnswerMissing("text")) {
            try definition.validate(
                answers: [
                    "single": .single("science"),
                    "multiple": .multiple(["building"]),
                    "rating": .rating(3),
                    "image": .image("forest"),
                ],
                requireVisibleAnswers: true
            )
        }
    }
}

@Suite("Survey repository")
struct SurveyRepositoryTests {
    @Test("Autosave is idempotent and resumes the exact scoped attempt")
    func autosaveAndResume() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let assignment = try surveyAssignment()
        let grant = try studentModeGrant(assignment: assignment)
        let definition = try surveyDefinition()

        let first = try await repository.autosave(
            answer: .single("science"),
            for: "single",
            operationID: "save-1",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let repeated = try await repository.autosave(
            answer: .single("science"),
            for: "single",
            operationID: "save-1",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let resumed = try await repository.resume(
            assignment: assignment,
            grant: grant
        )

        #expect(first.recordVersion == 1)
        #expect(repeated.recordVersion == 1)
        #expect(resumed == repeated)
        #expect(resumed?.syncState == .pending)
        #expect(resumed?.hasPendingChanges == true)
        #expect(await harness.saveCount == 1)
    }

    @Test("Cross-student scope is rejected")
    func correctStudentScope() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let assignment = try surveyAssignment(studentID: "student-2")
        let grant = try studentModeGrant(assignment: try surveyAssignment())

        await #expect(throws: SurveyRepositoryError.authorization) {
            _ = try await repository.autosave(
                answer: .single("science"),
                for: "single",
                operationID: "wrong-student",
                assignment: assignment,
                definition: try surveyDefinition(),
                grant: grant
            )
        }
    }

    @Test("Reassignment creates a new immutable attempt identity")
    func reassignmentCreatesNewAttempt() throws {
        let original = try surveyAssignment()
        let reassigned = try original.reassigned(
            assignmentID: "assignment-2",
            attemptID: "attempt-2"
        )

        #expect(reassigned.attemptID != original.attemptID)
        #expect(reassigned.definitionID == original.definitionID)
        #expect(reassigned.definitionVersion == original.definitionVersion)
        #expect(original.assignmentID == "assignment-1")
    }

    @Test("Revocation visibly quarantines queued work")
    func revokedQueueIsQuarantined() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let active = try surveyAssignment()
        let grant = try studentModeGrant(assignment: active)
        _ = try await repository.autosave(
            answer: .single("science"),
            for: "single",
            operationID: "save-before-revoke",
            assignment: active,
            definition: try surveyDefinition(),
            grant: grant
        )

        await #expect(throws: SurveyRepositoryError.revoked) {
            _ = try await repository.synchronize(
                assignment: active.revoked(),
                definition: try surveyDefinition(),
                grant: grant
            )
        }

        let stored = await harness.storedResponse
        #expect(stored?.syncState == .quarantined(.assignmentRevoked))
        #expect(stored?.hasPendingChanges == true)
        #expect(await harness.quarantineCount == 1)
    }

    @Test("Submission is online-only, idempotent, and immutable")
    func onlineImmutableSubmission() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let assignment = try surveyAssignment()
        let grant = try studentModeGrant(assignment: assignment)
        let definition = try surveyDefinition()
        try await completeDraft(
            repository: repository,
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        await harness.setOnline(false)

        await #expect(throws: SurveyRepositoryError.offline) {
            _ = try await repository.submit(
                operationID: "submit-1",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }

        await harness.setOnline(true)
        let submitted = try await repository.submit(
            operationID: "submit-1",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let retried = try await repository.submit(
            operationID: "submit-1",
            assignment: assignment,
            definition: definition,
            grant: grant
        )

        #expect(submitted.state == .submitted)
        #expect(submitted.submittedAt != nil)
        #expect(retried == submitted)
        #expect(await harness.submitCount == 1)
        await #expect(throws: SurveyRepositoryError.immutableResponse) {
            _ = try await repository.autosave(
                answer: .single("art"),
                for: "single",
                operationID: "edit-after-submit",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
    }

    @Test("Review changes only state and review metadata")
    func staffReviewPreservesAnswers() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let assignment = try surveyAssignment()
        let grant = try studentModeGrant(assignment: assignment)
        let definition = try surveyDefinition()
        try await completeDraft(
            repository: repository,
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let submitted = try await repository.submit(
            operationID: "submit-review",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let reviewed = try await repository.review(
            response: submitted,
            operationID: "review-1",
            staffIdentity: grant.staffIdentity
        )

        #expect(reviewed.state == .reviewed)
        #expect(reviewed.answers == submitted.answers)
        #expect(reviewed.frozenDefinition == submitted.frozenDefinition)
    }
}

private func surveyDefinition(
    branchRules: [SurveyBranchRule] = []
) throws -> SurveyDefinition {
    try SurveyDefinition(
        id: "interest-discovery",
        version: 3,
        title: "Interest discovery",
        publishedAt: Date(timeIntervalSince1970: 1_000),
        questions: [
            SurveyQuestion(
                id: "single",
                prompt: "Pick one",
                kind: .singleChoice,
                isRequired: true,
                options: [
                    SurveyOption(id: "science", label: "Science"),
                    SurveyOption(id: "art", label: "Art"),
                ]
            ),
            SurveyQuestion(
                id: "multiple",
                prompt: "Pick several",
                kind: .multiSelect(maxSelections: 2),
                isRequired: true,
                options: [
                    SurveyOption(id: "building", label: "Building"),
                    SurveyOption(id: "drawing", label: "Drawing"),
                ]
            ),
            SurveyQuestion(
                id: "text",
                prompt: "Tell us more",
                kind: .shortText(maxLength: 120),
                isRequired: true
            ),
            SurveyQuestion(
                id: "rating",
                prompt: "Rate it",
                kind: .rating(minimum: 1, maximum: 5),
                isRequired: true
            ),
            SurveyQuestion(
                id: "image",
                prompt: "Pick a place",
                kind: .imageChoice,
                isRequired: true,
                options: [
                    SurveyOption(
                        id: "forest",
                        label: "Forest",
                        imageReference: "survey/forest"
                    ),
                    SurveyOption(
                        id: "city",
                        label: "City",
                        imageReference: "survey/city"
                    ),
                ]
            ),
        ],
        branchRules: branchRules
    )
}

private func surveyAssignment(
    studentID: String = "student-1"
) throws -> SurveyAssignment {
    try SurveyAssignment(
        assignmentID: "assignment-1",
        attemptID: "attempt-1",
        districtID: "district-1",
        studentID: studentID,
        definitionID: "interest-discovery",
        definitionVersion: 3,
        state: .active,
        assignedAt: Date(timeIntervalSince1970: 2_000)
    )
}

private func studentModeGrant(
    assignment: SurveyAssignment
) throws -> StudentModeGrant {
    let scope = try StudentModeScope(
        districtID: "district-1",
        studentID: "student-1",
        assignmentIDs: [assignment.assignmentID],
        allowedOperations: StudentModeOperation.surveyAssignment
    )
    return StudentModeGrant(
        sessionID: "session-1",
        scope: scope,
        recordVersion: 1,
        issuedAt: Date(timeIntervalSince1970: 2_000),
        expiresAt: Date(timeIntervalSince1970: 9_000),
        staffIdentity: StudentModeStaffIdentity(
            userID: "staff-1",
            districtID: "district-1",
            membershipVersion: 1
        )
    )
}

private func completeDraft(
    repository: SurveyRepository,
    assignment: SurveyAssignment,
    definition: SurveyDefinition,
    grant: StudentModeGrant
) async throws {
    let answers: [(String, SurveyAnswer)] = [
        ("single", .single("art")),
        ("multiple", .multiple(["drawing"])),
        ("text", .text("Art club")),
        ("rating", .rating(4)),
        ("image", .image("city")),
    ]
    for (index, entry) in answers.enumerated() {
        _ = try await repository.autosave(
            answer: entry.1,
            for: entry.0,
            operationID: "answer-\(index)",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
    }
}

private actor SurveyRepositoryHarness {
    private(set) var storedResponse: SurveyResponse?
    private(set) var saveCount = 0
    private(set) var submitCount = 0
    private(set) var quarantineCount = 0
    private var online = true

    nonisolated func repository() -> SurveyRepository {
        SurveyRepository(
            loadDraft: { [weak self] key in
                await self?.load(key: key)
            },
            saveDraft: { [weak self] response in
                await self?.save(response)
            },
            quarantineDraft: { [weak self] response in
                await self?.quarantine(response)
            },
            synchronizeDraft: { [weak self] request in
                try await self?.synchronize(request) ?? request.response
            },
            submitResponse: { [weak self] request in
                try await self?.submit(request) ?? request.response
            },
            reviewResponse: { [weak self] request in
                try await self?.review(request) ?? request.response
            },
            isOnline: { [weak self] in
                await self?.online ?? false
            }
        )
    }

    func setOnline(_ value: Bool) {
        online = value
    }

    private func load(key: SurveyAttemptKey) -> SurveyResponse? {
        guard storedResponse?.attemptKey == key else { return nil }
        return storedResponse
    }

    private func save(_ response: SurveyResponse) {
        storedResponse = response
        saveCount += 1
    }

    private func quarantine(_ response: SurveyResponse) {
        storedResponse = response
        quarantineCount += 1
    }

    private func synchronize(
        _ request: SurveyDraftSyncRequest
    ) throws -> SurveyResponse {
        var response = request.response
        response.markSynchronized(serverRecordVersion: response.recordVersion)
        storedResponse = response
        return response
    }

    private func submit(
        _ request: SurveySubmissionRequest
    ) throws -> SurveyResponse {
        submitCount += 1
        var response = request.response
        try response.markSubmitted(
            operationID: request.operationID,
            submittedAt: Date(timeIntervalSince1970: 3_000),
            serverRecordVersion: response.recordVersion + 1,
            definition: request.definition,
            sessionID: request.sessionID
        )
        storedResponse = response
        return response
    }

    private func review(
        _ request: SurveyReviewRequest
    ) throws -> SurveyResponse {
        var response = request.response
        try response.markReviewed(
            operationID: request.operationID,
            reviewerID: request.staffIdentity.userID,
            reviewedAt: Date(timeIntervalSince1970: 4_000),
            serverRecordVersion: response.recordVersion + 1
        )
        storedResponse = response
        return response
    }
}
