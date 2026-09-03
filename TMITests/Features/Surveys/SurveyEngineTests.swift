import Foundation
import FirebaseFunctions
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

    @Test("Shared v1 fixture round-trips canonical definition and response fields")
    func sharedSchemaFixtureRoundTrip() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("firebase/fixtures/survey-v1.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixtureData = try Data(contentsOf: fixtureURL)
        let fixture = try decoder.decode(
            SurveySchemaFixture.self,
            from: fixtureData
        )

        #expect(fixture.definition.id == "interest-discovery")
        #expect(fixture.definition.questions.last?.options.first?.imageReference == "survey/forest")
        #expect(fixture.response.response.recordVersion == 1)
        #expect(fixture.response.response.syncState == .synced)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseObject = try #require(
            JSONSerialization.jsonObject(
                with: try encoder.encode(fixture.response)
            ) as? [String: Any]
        )
        let fixtureObject = try #require(
            JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
        )
        let expectedResponse = try #require(
            fixtureObject["response"] as? [String: Any]
        )
        #expect(responseObject as NSDictionary == expectedResponse as NSDictionary)
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

    @Test("Definition limits accept exact boundaries and reject overflow")
    func canonicalDefinitionLimits() throws {
        let contract = try surveyDefinitionContract()
        #expect(SurveyDefinition.maximumQuestionCount == contract.maximumQuestionCount)
        #expect(SurveyDefinition.maximumBranchRuleCount == contract.maximumBranchRuleCount)
        #expect(SurveyDefinition.maximumOptionCount == contract.maximumOptionCount)
        #expect(SurveyDefinition.maximumTextLength == contract.maximumTextLength)
        #expect(
            SurveyDefinition.maximumIdentifierUTF8Bytes ==
                contract.maximumIdentifierUTF8Bytes
        )
        #expect(SurveyDefinition.maximumPromptUTF8Bytes == contract.maximumPromptUTF8Bytes)
        #expect(SurveyDefinition.maximumLabelUTF8Bytes == contract.maximumLabelUTF8Bytes)
        #expect(
            SurveyDefinition.maximumImageReferenceUTF8Bytes ==
                contract.maximumImageReferenceUTF8Bytes
        )
        let boundaryOptionID = String(
            repeating: "é",
            count: contract.maximumIdentifierUTF8Bytes / 2
        )
        let options = (0..<contract.maximumOptionCount).map { index in
            SurveyOption(
                id: index == 0 ? boundaryOptionID : "option-\(index)",
                label: index == 0
                    ? String(repeating: "é", count: contract.maximumLabelUTF8Bytes / 2)
                    : "Option \(index)",
                imageReference: index == 0
                    ? String(
                        repeating: "é",
                        count: contract.maximumImageReferenceUTF8Bytes / 2
                    )
                    : "survey/option-\(index)"
            )
        }
        var questions = (0..<contract.maximumQuestionCount).map { index in
            SurveyQuestion(
                id: "question-\(index)",
                prompt: "Question \(index)",
                kind: .shortText(maxLength: contract.maximumTextLength),
                isRequired: false
            )
        }
        questions[0] = SurveyQuestion(
            id: "question-0",
            prompt: String(
                repeating: "é",
                count: contract.maximumPromptUTF8Bytes / 2
            ),
            kind: .imageChoice,
            isRequired: false,
            options: options
        )
        questions[contract.maximumQuestionCount - 1] = SurveyQuestion(
            id: String(
                repeating: "é",
                count: contract.maximumIdentifierUTF8Bytes / 2
            ),
            prompt: "Boundary identifier",
            kind: .shortText(maxLength: contract.maximumTextLength),
            isRequired: false
        )
        let rules = (0..<contract.maximumBranchRuleCount).map { index in
            SurveyBranchRule(
                id: index == 0
                    ? String(
                        repeating: "é",
                        count: contract.maximumIdentifierUTF8Bytes / 2
                    )
                    : "rule-\(index)",
                sourceQuestionID: "question-0",
                targetQuestionID: "question-1",
                predicate: .equals(boundaryOptionID)
            )
        }
        _ = try SurveyDefinition(
            id: String(
                repeating: "é",
                count: contract.maximumIdentifierUTF8Bytes / 2
            ),
            version: 1,
            title: "Boundary definition",
            publishedAt: Date(timeIntervalSince1970: 1_000),
            questions: questions,
            branchRules: rules
        )

        #expect(throws: SurveyDefinitionError.self) {
            _ = try boundedDefinition(
                questions: (0...contract.maximumQuestionCount).map {
                    textQuestion(id: "question-\($0)")
                }
            )
        }
        #expect(throws: SurveyDefinitionError.self) {
            _ = try boundedDefinition(
                questions: [choiceQuestion(), textQuestion(id: "target")],
                branchRules: (0...contract.maximumBranchRuleCount).map {
                    branchRule(id: "rule-\($0)")
                }
            )
        }
        #expect(throws: SurveyDefinitionError.self) {
            _ = try boundedDefinition(questions: [choiceQuestion(
                options: (0...contract.maximumOptionCount).map {
                    SurveyOption(id: "option-\($0)", label: "Option")
                }
            )])
        }
        #expect(throws: SurveyDefinitionError.self) {
            _ = try boundedDefinition(questions: [SurveyQuestion(
                id: "multi",
                prompt: "Multi",
                kind: .multiSelect(maxSelections: 3),
                isRequired: false,
                options: [
                    SurveyOption(id: "one", label: "One"),
                    SurveyOption(id: "two", label: "Two"),
                ]
            )])
        }
        #expect(throws: SurveyDefinitionError.self) {
            _ = try boundedDefinition(questions: [textQuestion(
                id: "text",
                maxLength: contract.maximumTextLength + 1
            )])
        }
    }

    @Test("Definition strings share Firebase UTF-8 and normalization rules")
    func canonicalDefinitionStrings() throws {
        let contract = try surveyDefinitionContract()
        let invalidIdentifiers = [
            ".",
            "..",
            " padded",
            "path/segment",
            "control\u{0000}",
            String(repeating: "é", count: contract.maximumIdentifierUTF8Bytes / 2 + 1),
        ]
        for identifier in invalidIdentifiers {
            #expect(throws: SurveyDefinitionError.self) {
                _ = try boundedDefinition(id: identifier)
            }
        }
        for prompt in [
            " padded",
            "control\u{0000}",
            String(repeating: "é", count: contract.maximumPromptUTF8Bytes / 2 + 1),
        ] {
            #expect(throws: SurveyDefinitionError.self) {
                _ = try boundedDefinition(questions: [SurveyQuestion(
                    id: "choice",
                    prompt: prompt,
                    kind: .singleChoice,
                    isRequired: false,
                    options: [SurveyOption(id: "one", label: "One")]
                )])
            }
        }
        for label in [
            " padded",
            "control\u{0000}",
            String(repeating: "é", count: contract.maximumLabelUTF8Bytes / 2 + 1),
        ] {
            #expect(throws: SurveyDefinitionError.self) {
                _ = try boundedDefinition(questions: [choiceQuestion(
                    options: [SurveyOption(id: "one", label: label)]
                )])
            }
        }
        for imageReference in [
            " padded",
            "control\u{0000}",
            String(
                repeating: "é",
                count: contract.maximumImageReferenceUTF8Bytes / 2 + 1
            ),
        ] {
            #expect(throws: SurveyDefinitionError.self) {
                _ = try boundedDefinition(questions: [SurveyQuestion(
                    id: "image",
                    prompt: "Image",
                    kind: .imageChoice,
                    isRequired: false,
                    options: [SurveyOption(
                        id: "one",
                        label: "One",
                        imageReference: imageReference
                    )]
                )])
            }
        }
    }
}

@Suite("Survey repository")
struct SurveyRepositoryTests {
    @Test("The active grant loads its stored assignment and exact published definition")
    func loadsCanonicalActivity() async throws {
        let assignment = try surveyAssignment()
        let definition = try surveyDefinition()
        let repository = SurveyRepository(
            loadActivity: { _, _ in SurveyActivity(assignment: assignment, definition: definition) },
            requestHelp: { _, _ in },
            draftStore: .memory,
            synchronizeDraft: { $0.response },
            submitResponse: { $0.response },
            reviewResponse: { $0.response },
            isOnline: { true }
        )
        let activity = try await repository.activity(grant: studentModeGrant(assignment: assignment))
        #expect(activity.assignment.attemptID == assignment.attemptID)
        #expect(activity.definition.id == assignment.definitionID)
        #expect(activity.definition.version == assignment.definitionVersion)
    }

    @Test("Help requests require scoped authorization and report backend success")
    func scopedHelpRequest() async throws {
        let assignment = try surveyAssignment()
        let called = SurveyHelpSpy()
        let repository = SurveyRepository(
            loadActivity: { _, _ in throw SurveyRepositoryError.unavailable },
            requestHelp: { request, _ in await called.record(request) },
            draftStore: .memory,
            synchronizeDraft: { $0.response },
            submitResponse: { $0.response },
            reviewResponse: { $0.response },
            isOnline: { true }
        )
        let grant = try studentModeGrant(assignment: assignment)
        try await repository.requestHelp(operationID: "help-1", grant: grant)
        #expect(await called.operationID == "help-1")
    }

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

        #expect(first.recordVersion == 0)
        #expect(first.localRevision == 1)
        #expect(repeated.recordVersion == 0)
        #expect(repeated.localRevision == 1)
        #expect(resumed == repeated)
        #expect(resumed?.syncState == .pending)
        #expect(resumed?.hasPendingChanges == true)
        #expect(await harness.saveCount == 1)
    }

    @Test("Concurrent autosaves retain every answer and persist in order")
    func concurrentAutosavesRetainEveryAnswer() async throws {
        let store = DelayedSurveyDraftStore()
        let repository = SurveyRepository(
            loadDraft: { key in await store.load(key) },
            saveDraft: { response in try await store.save(response) },
            quarantineDraft: { _ in },
            synchronizeDraft: { $0.response },
            submitResponse: { $0.response },
            reviewResponse: { $0.response },
            isOnline: { true }
        )
        let assignment = try surveyAssignment()
        let definition = try surveyDefinition()
        let grant = try studentModeGrant(assignment: assignment)

        async let first = repository.autosave(
            answer: .single("art"),
            for: "single",
            operationID: "concurrent-1",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        async let second = repository.autosave(
            answer: .text("Art club"),
            for: "text",
            operationID: "concurrent-2",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        _ = try await (first, second)

        let resumed = try await repository.resume(assignment: assignment, grant: grant)
        let persisted = await store.response
        #expect(resumed?.answers["single"] == .single("art"))
        #expect(resumed?.answers["text"] == .text("Art club"))
        #expect(persisted?.answers == resumed?.answers)
        #expect(await store.saveCount == 2)
    }

    @Test("Autosave queue recovers after one local persistence failure")
    func autosaveQueueRecoversAfterFailure() async throws {
        let store = DelayedSurveyDraftStore(failFirstSave: true)
        let repository = SurveyRepository(
            loadDraft: { key in await store.load(key) },
            saveDraft: { response in try await store.save(response) },
            quarantineDraft: { _ in },
            synchronizeDraft: { $0.response },
            submitResponse: { $0.response },
            reviewResponse: { $0.response },
            isOnline: { true }
        )
        let assignment = try surveyAssignment()
        let definition = try surveyDefinition()
        let grant = try studentModeGrant(assignment: assignment)

        await #expect(throws: SurveyRepositoryError.unavailable) {
            _ = try await repository.autosave(
                answer: .single("art"),
                for: "single",
                operationID: "fail-once-1",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
        _ = try await repository.autosave(
            answer: .text("Art club"),
            for: "text",
            operationID: "fail-once-2",
            assignment: assignment,
            definition: definition,
            grant: grant
        )

        #expect(await store.response?.answers["single"] == .single("art"))
        #expect(await store.response?.answers["text"] == .text("Art club"))
        #expect(await store.saveAttempts == 2)
    }

    @Test("Purge closes the attempt before a late autosave can recreate it")
    func purgeBlocksOverlappingAutosave() async throws {
        let store = DelayedSurveyDraftStore(saveDelay: .milliseconds(100))
        let draftStore = SurveyDraftStore(
            load: { key in
                if let response = await store.load(key) { return .draft(response) }
                return .missing
            },
            save: { response in try await store.save(response) },
            quarantine: { response in try await store.save(response) },
            purge: { _ in await store.purge() }
        )
        let repository = SurveyRepository(
            draftStore: draftStore,
            synchronizeDraft: { $0.response },
            submitResponse: { $0.response },
            reviewResponse: { $0.response },
            isOnline: { true }
        )
        let assignment = try surveyAssignment()
        let definition = try surveyDefinition()
        let grant = try studentModeGrant(assignment: assignment)

        let firstSave = Task {
            try await repository.autosave(
                answer: .single("art"),
                for: "single",
                operationID: "purge-race-1",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
        try await Task.sleep(for: .milliseconds(20))
        let purge = Task { try await repository.purge(assignment: assignment) }
        try await Task.sleep(for: .milliseconds(20))
        await #expect(throws: SurveyRepositoryError.revoked) {
            _ = try await repository.autosave(
                answer: .text("late"),
                for: "text",
                operationID: "purge-race-2",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
        await #expect(throws: SurveyRepositoryError.revoked) {
            _ = try await firstSave.value
        }
        try await purge.value
        #expect(await store.response == nil)
    }

    @Test("Multiple offline edits synchronize once against the last server version")
    func multipleOfflineEditsUseAuthoritativeServerVersion() async throws {
        let server = SurveyServerCounter()
        let harness = SurveyRepositoryHarness(serverCounter: server)
        let repository = harness.repository()
        let assignment = try surveyAssignment()
        let grant = try studentModeGrant(assignment: assignment)
        let definition = try surveyDefinition()

        _ = try await repository.autosave(
            answer: .single("science"),
            for: "single",
            operationID: "offline-1",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let local = try await repository.autosave(
            answer: .multiple(["building"]),
            for: "multiple",
            operationID: "offline-2",
            assignment: assignment,
            definition: definition,
            grant: grant
        )
        let synchronized = try await repository.synchronize(
            assignment: assignment,
            definition: definition,
            grant: grant
        )

        #expect(local.recordVersion == 0)
        #expect(local.localRevision == 2)
        #expect(synchronized.recordVersion == 1)
        #expect(synchronized.localRevision == 2)
        #expect(await server.expectedVersions == [0])
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

    @Test("Expired sessions are typed failures and definition errors stay validation failures")
    func typedAuthorizationAndValidationErrors() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let assignment = try surveyAssignment()
        let activeGrant = try studentModeGrant(assignment: assignment)
        _ = try await repository.autosave(
            answer: .single("science"),
            for: "single",
            operationID: "before-expiry",
            assignment: assignment,
            definition: try surveyDefinition(),
            grant: activeGrant
        )
        await #expect(throws: SurveyRepositoryError.validation) {
            _ = try await repository.autosave(
                answer: .rating(4),
                for: "single",
                operationID: "wrong-answer-type",
                assignment: assignment,
                definition: try surveyDefinition(),
                grant: activeGrant
            )
        }
        let expiredGrant = try studentModeGrant(
            assignment: assignment,
            expiresAt: .distantPast
        )
        await #expect(throws: SurveyRepositoryError.expired) {
            _ = try await repository.resume(
                assignment: assignment,
                grant: expiredGrant
            )
        }
        #expect(
            await harness.storedResponse?.syncState ==
                .quarantined(.authorizationRejected)
        )

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

    @Test("Resume of revoked work quarantines it and purge removes history")
    func revokedResumeQuarantinesAndPurges() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SurveyDraftStore.localFiles(directory: directory)
        let repository = SurveyRepository(
            draftStore: store,
            synchronizeDraft: { request in request.response },
            submitResponse: { request in request.response },
            reviewResponse: { request in request.response },
            isOnline: { true }
        )
        let assignment = try surveyAssignment()
        let grant = try studentModeGrant(assignment: assignment)
        _ = try await repository.autosave(
            answer: .single("science"),
            for: "single",
            operationID: "queued",
            assignment: assignment,
            definition: try surveyDefinition(),
            grant: grant
        )

        await #expect(throws: SurveyRepositoryError.revoked) {
            _ = try await repository.resume(
                assignment: assignment.revoked(),
                grant: grant
            )
        }
        #expect(
            await store.load(assignment.attemptKey) ==
                .quarantined(.assignmentRevoked)
        )
        try await store.purge(assignment.attemptKey)
        #expect(await store.load(assignment.attemptKey) == .missing)
    }

    @Test("Local filenames cannot collide and mismatched embedded scope is denied")
    func localDraftKeyIsolation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SurveyDraftStore.localFiles(directory: directory)
        let definition = try surveyDefinition()
        let firstAssignment = try SurveyAssignment(
            assignmentID: "assignment",
            attemptID: "attempt",
            districtID: "a",
            studentID: "b--c",
            definitionID: definition.id,
            definitionVersion: definition.version,
            state: .active,
            assignedAt: Date()
        )
        let secondAssignment = try SurveyAssignment(
            assignmentID: "assignment",
            attemptID: "attempt",
            districtID: "a--b",
            studentID: "c",
            definitionID: definition.id,
            definitionVersion: definition.version,
            state: .active,
            assignedAt: Date()
        )
        let first = SurveyResponse(
            assignment: firstAssignment,
            definition: definition
        )
        let second = SurveyResponse(
            assignment: secondAssignment,
            definition: definition
        )
        try await store.save(first)
        let activeDirectory = directory.appendingPathComponent(
            "active",
            isDirectory: true
        )
        let firstFile = try #require(
            FileManager.default.contentsOfDirectory(
                at: activeDirectory,
                includingPropertiesForKeys: nil
            ).first
        )
        try await store.save(second)

        #expect(await store.load(first.attemptKey) == .draft(first))
        #expect(await store.load(second.attemptKey) == .draft(second))

        let files = try FileManager.default.contentsOfDirectory(
            at: activeDirectory,
            includingPropertiesForKeys: nil
        )
        let secondFile = try #require(files.first { $0 != firstFile })
        try Data(contentsOf: secondFile).write(to: firstFile, options: .atomic)
        let firstLoad = await store.load(first.attemptKey)
        #expect(firstLoad == .scopeMismatch)
    }

    @Test("Operation history and identifier length are bounded")
    func operationHistoryBounds() async throws {
        var response = SurveyResponse(
            assignment: try surveyAssignment(),
            definition: try surveyDefinition()
        )
        for index in 0..<SurveyResponse.maximumOperationCount {
            _ = try response.apply(
                answer: .text("\(index)"),
                questionID: "text",
                operationID: "operation-\(index)"
            )
        }
        #expect(throws: SurveyResponseMutationError.historyLimitReached) {
            _ = try response.apply(
                answer: .text("overflow"),
                questionID: "text",
                operationID: "overflow"
            )
        }
        #expect(throws: SurveyResponseMutationError.invalidOperationID) {
            _ = try response.apply(
                answer: .text("large"),
                questionID: "text",
                operationID: String(repeating: "x", count: 129)
            )
        }
        for reserved in [".", ".."] {
            #expect(throws: SurveyResponseMutationError.invalidOperationID) {
                _ = try response.apply(
                    answer: .text("reserved"),
                    questionID: "text",
                    operationID: reserved
                )
            }
        }
        #expect(throws: SurveyResponseMutationError.historyLimitReached) {
            try response.markSubmitted(
                operationID: "submit-overflow",
                submittedAt: Date(timeIntervalSince1970: 3_000),
                serverRecordVersion: 1,
                definition: try surveyDefinition(),
                sessionID: "session-1"
            )
        }

        var submitted = SurveyResponse(
            assignment: try surveyAssignment(),
            definition: try surveyDefinition()
        )
        for index in 0..<(SurveyResponse.maximumOperationCount - 1) {
            _ = try submitted.apply(
                answer: .text("\(index)"),
                questionID: "text",
                operationID: "review-history-\(index)"
            )
        }
        try submitted.markSubmitted(
            operationID: "submit-at-limit",
            submittedAt: Date(timeIntervalSince1970: 3_000),
            serverRecordVersion: 1,
            definition: try surveyDefinition(),
            sessionID: "session-1"
        )
        #expect(throws: SurveyResponseMutationError.historyLimitReached) {
            try submitted.markReviewed(
                operationID: "review-overflow",
                reviewerID: "teacher-1",
                reviewedAt: Date(timeIntervalSince1970: 4_000),
                serverRecordVersion: 2
            )
        }
    }

    @Test("Repository reports local and Firebase history exhaustion actionably")
    func repositoryHistoryErrorsAreTyped() async throws {
        let harness = SurveyRepositoryHarness()
        let repository = harness.repository()
        let assignment = try surveyAssignment()
        let definition = try surveyDefinition()
        let grant = try studentModeGrant(assignment: assignment)
        for index in 0..<SurveyResponse.maximumOperationCount {
            _ = try await repository.autosave(
                answer: .text("\(index)"),
                for: "text",
                operationID: "history-\(index)",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
        await #expect(throws: SurveyRepositoryError.historyLimitReached) {
            _ = try await repository.autosave(
                answer: .text("overflow"),
                for: "text",
                operationID: "history-overflow",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
        await #expect(throws: SurveyRepositoryError.historyLimitReached) {
            _ = try await repository.submit(
                operationID: "submit-history-overflow",
                assignment: assignment,
                definition: definition,
                grant: grant
            )
        }
        #expect(await harness.submitCount == 0)

        let firebaseError = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.resourceExhausted.rawValue
        )
        #expect(
            SurveyFirebaseErrorMapper.map(firebaseError) ==
                .historyLimitReached
        )
        for (kind, expected) in [
            ("survey-session-expired", SurveyRepositoryError.expired),
            ("survey-session-revoked", SurveyRepositoryError.revoked),
            ("survey-assignment-revoked", SurveyRepositoryError.revoked),
        ] {
            let error = NSError(
                domain: FunctionsErrorDomain,
                code: FunctionsErrorCode.failedPrecondition.rawValue,
                userInfo: [FunctionsErrorDetailsKey: ["kind": kind]]
            )
            #expect(SurveyFirebaseErrorMapper.map(error) == expected)
        }
    }

    @Test("Server revocation and expiry quarantine pending work with distinct errors")
    func serverRevocationAndExpiryQuarantine() async throws {
        for (error, reason) in [
            (SurveyRepositoryError.revoked, SurveyQuarantineReason.assignmentRevoked),
            (SurveyRepositoryError.expired, SurveyQuarantineReason.authorizationRejected),
        ] {
            for endpoint in ["synchronize", "submit"] {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                defer { try? FileManager.default.removeItem(at: directory) }
                let store = SurveyDraftStore.localFiles(directory: directory)
                let repository = SurveyRepository(
                    draftStore: store,
                    synchronizeDraft: { request in
                        if endpoint == "synchronize" {
                            throw error
                        }
                        var response = request.response
                        response.markSynchronized(
                            serverRecordVersion: response.recordVersion + 1
                        )
                        return response
                    },
                    submitResponse: { request in
                        if endpoint == "submit" {
                            throw error
                        }
                        return request.response
                    },
                    reviewResponse: { request in request.response },
                    isOnline: { true }
                )
                let assignment = try surveyAssignment()
                let definition = try surveyDefinition()
                let grant = try studentModeGrant(assignment: assignment)
                if endpoint == "submit" {
                    try await completeDraft(
                        repository: repository,
                        assignment: assignment,
                        definition: definition,
                        grant: grant
                    )
                } else {
                    _ = try await repository.autosave(
                        answer: .single("science"),
                        for: "single",
                        operationID: "queued-\(reason.rawValue)",
                        assignment: assignment,
                        definition: definition,
                        grant: grant
                    )
                }

                await #expect(throws: error) {
                    if endpoint == "submit" {
                        _ = try await repository.submit(
                            operationID: "submit-server-denial",
                            assignment: assignment,
                            definition: definition,
                            grant: grant
                        )
                    } else {
                        _ = try await repository.synchronize(
                            assignment: assignment,
                            definition: definition,
                            grant: grant
                        )
                    }
                }
                #expect(
                    await store.load(assignment.attemptKey) ==
                        .quarantined(reason)
                )
                let resumeError: SurveyRepositoryError = reason == .assignmentRevoked
                    ? .revoked
                    : .expired
                await #expect(throws: resumeError) {
                    _ = try await repository.resume(
                        assignment: assignment,
                        grant: grant
                    )
                }
            }
        }
    }

    @Test("Swift staff operation sends trusted assignment mutations and accepts server attempts")
    func staffAssignmentMutation() async throws {
        let recorder = SurveyAssignmentMutationRecorder()
        let harness = SurveyRepositoryHarness(
            assignmentRecorder: recorder
        )
        let repository = harness.repository()
        let request = SurveyAssignmentMutationRequest(
            action: .create,
            assignmentID: "assignment-created",
            studentID: "student-1",
            definitionID: "interest-discovery",
            definitionVersion: 3,
            expectedRecordVersion: 0,
            operationID: "assignment-create-1",
            reasonCode: "educator-survey-assignment"
        )
        let assignment = try await repository.mutateAssignment(
            request,
            districtID: "district-1"
        )

        #expect(assignment.attemptID == "server-attempt")
        #expect(await recorder.requests == [request])
    }

    @Test("Swift assignment callable result validates the exact trusted schema")
    func strictAssignmentCallableResult() throws {
        let request = SurveyAssignmentMutationRequest(
            action: .create,
            assignmentID: "assignment-created",
            studentID: "student-1",
            definitionID: "interest-discovery",
            definitionVersion: 3,
            expectedRecordVersion: 0,
            operationID: "assignment-create-1",
            reasonCode: "educator-survey-assignment"
        )
        let assignment: [String: Any] = [
            "schemaVersion": 1,
            "recordVersion": 1,
            "assignmentID": request.assignmentID,
            "attemptID": "server-attempt",
            "districtID": "district-1",
            "studentID": request.studentID,
            "definitionID": request.definitionID,
            "definitionVersion": request.definitionVersion,
            "state": "active",
            "assignedAt": "2026-08-03T12:00:00Z",
            "revokedAt": NSNull(),
        ]
        let result: [String: Any] = [
            "operationID": request.operationID,
            "recordVersion": 1,
            "replayed": false,
            "assignment": assignment,
        ]

        let decoded = try SurveyAssignmentMutationResultDecoder.decode(
            result,
            request: request,
            districtID: "district-1"
        )
        #expect(decoded.attemptID == "server-attempt")

        for malformed in [
            result.merging(["operationID": "wrong-operation"]) { _, new in new },
            result.merging([
                "assignment": assignment.merging(["studentID": "student-2"]) { _, new in new },
            ]) { _, new in new },
            result.merging([
                "assignment": assignment.merging(["revokedAt": "2026-08-03T12:01:00Z"]) { _, new in new },
            ]) { _, new in new },
        ] {
            #expect(throws: SurveyRepositoryError.malformedResponse) {
                _ = try SurveyAssignmentMutationResultDecoder.decode(
                    malformed,
                    request: request,
                    districtID: "district-1"
                )
            }
        }
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

    @Test("Review result uses only canonical backend reviewer attribution")
    func canonicalReviewerAttribution() async throws {
        let definition = try surveyDefinition()
        var submitted = SurveyResponse(
            assignment: try surveyAssignment(),
            definition: definition
        )
        try submitted.markSubmitted(
            operationID: "submit-review-decoder",
            submittedAt: Date(timeIntervalSince1970: 3_000),
            serverRecordVersion: 1,
            definition: definition,
            sessionID: "session-1"
        )
        let request = SurveyReviewRequest(
            response: submitted,
            operationID: "review-decoder",
            staffIdentity: StudentModeStaffIdentity(
                userID: "stale-injected-reviewer",
                districtID: submitted.districtID,
                membershipVersion: 1
            )
        )
        let result: [String: Any] = [
            "operationID": request.operationID,
            "recordVersion": 2,
            "replayed": false,
            "reviewedAt": "2026-08-03T12:00:00Z",
            "reviewerUserID": "authenticated-reviewer",
        ]

        let reviewed = try SurveyReviewCallableResultDecoder.decode(
            result,
            request: request
        )
        #expect(reviewed.serverMetadata?.reviewedBy == "authenticated-reviewer")
        #expect(reviewed.serverMetadata?.reviewedBy != request.staffIdentity.userID)

        let storage = SurveyReviewStorage()
        let repository = SurveyRepository(
            loadDraft: { _ in nil },
            saveDraft: { response in await storage.save(response) },
            quarantineDraft: { _ in },
            synchronizeDraft: { request in request.response },
            submitResponse: { request in request.response },
            reviewResponse: { request in
                try SurveyReviewCallableResultDecoder.decode(
                    [
                        "operationID": request.operationID,
                        "recordVersion": request.response.recordVersion + 1,
                        "replayed": false,
                        "reviewedAt": "2026-08-03T12:00:00Z",
                        "reviewerUserID": "authenticated-reviewer",
                    ],
                    request: request
                )
            },
            isOnline: { true }
        )
        _ = try await repository.review(
            response: submitted,
            operationID: request.operationID,
            staffIdentity: request.staffIdentity
        )
        #expect(
            await storage.response?.serverMetadata?.reviewedBy ==
                "authenticated-reviewer"
        )

        for malformed in [
            result.filter { $0.key != "reviewerUserID" },
            result.merging(["reviewerUserID": " injected"]) { _, new in new },
            result.merging(["operationID": "wrong-review"]) { _, new in new },
            result.merging(["recordVersion": 3]) { _, new in new },
        ] {
            #expect(throws: SurveyRepositoryError.malformedResponse) {
                _ = try SurveyReviewCallableResultDecoder.decode(
                    malformed,
                    request: request
                )
            }
        }
    }
}

private actor SurveyHelpSpy {
    private(set) var operationID: String?
    func record(_ request: SurveyHelpRequest) { operationID = request.operationID }
}

private actor DelayedSurveyDraftStore {
    private(set) var response: SurveyResponse?
    private(set) var saveCount = 0
    private(set) var saveAttempts = 0
    private var shouldFailNextSave: Bool
    private let saveDelay: Duration

    init(
        failFirstSave: Bool = false,
        saveDelay: Duration = .milliseconds(20)
    ) {
        shouldFailNextSave = failFirstSave
        self.saveDelay = saveDelay
    }

    func load(_ key: SurveyAttemptKey) async -> SurveyResponse? {
        try? await Task.sleep(for: .milliseconds(20))
        guard response?.attemptKey == key else { return nil }
        return response
    }

    func save(_ response: SurveyResponse) async throws {
        try await Task.sleep(for: saveDelay)
        saveAttempts += 1
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw SurveyRepositoryError.unavailable
        }
        self.response = response
        saveCount += 1
    }

    func purge() {
        response = nil
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

private struct SurveySchemaFixture: Decodable {
    let definition: SurveyDefinition
    let response: SurveyStoredResponseDocument
}

private struct SurveyDefinitionContract: Decodable {
    let maximumQuestionCount: Int
    let maximumBranchRuleCount: Int
    let maximumOptionCount: Int
    let maximumTextLength: Int
    let maximumIdentifierUTF8Bytes: Int
    let maximumPromptUTF8Bytes: Int
    let maximumLabelUTF8Bytes: Int
    let maximumImageReferenceUTF8Bytes: Int
}

private func surveyDefinitionContract() throws -> SurveyDefinitionContract {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("firebase/fixtures/survey-contract-v1.json")
    return try JSONDecoder().decode(
        SurveyDefinitionContract.self,
        from: Data(contentsOf: url)
    )
}

private func boundedDefinition(
    id: String = "bounded-definition",
    questions: [SurveyQuestion] = [textQuestion(id: "text")],
    branchRules: [SurveyBranchRule] = []
) throws -> SurveyDefinition {
    try SurveyDefinition(
        id: id,
        version: 1,
        title: "Bounded definition",
        publishedAt: Date(timeIntervalSince1970: 1_000),
        questions: questions,
        branchRules: branchRules
    )
}

private func textQuestion(
    id: String,
    maxLength: Int = 120
) -> SurveyQuestion {
    SurveyQuestion(
        id: id,
        prompt: "Text",
        kind: .shortText(maxLength: maxLength),
        isRequired: false
    )
}

private func choiceQuestion(
    options: [SurveyOption] = [SurveyOption(id: "one", label: "One")]
) -> SurveyQuestion {
    SurveyQuestion(
        id: "choice",
        prompt: "Choice",
        kind: .singleChoice,
        isRequired: false,
        options: options
    )
}

private func branchRule(id: String) -> SurveyBranchRule {
    SurveyBranchRule(
        id: id,
        sourceQuestionID: "choice",
        targetQuestionID: "target",
        predicate: .equals("one")
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
    assignment: SurveyAssignment,
    expiresAt: Date = .distantFuture
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
        expiresAt: expiresAt,
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
    private let serverCounter: SurveyServerCounter?
    private let synchronizationError: SurveyRepositoryError?
    private let assignmentRecorder: SurveyAssignmentMutationRecorder?

    init(
        serverCounter: SurveyServerCounter? = nil,
        synchronizationError: SurveyRepositoryError? = nil,
        assignmentRecorder: SurveyAssignmentMutationRecorder? = nil
    ) {
        self.serverCounter = serverCounter
        self.synchronizationError = synchronizationError
        self.assignmentRecorder = assignmentRecorder
    }

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
            mutateAssignment: { [weak self] request, districtID in
                guard let recorder = await self?.assignmentRecorder else {
                    throw SurveyRepositoryError.unavailable
                }
                return try await recorder.mutate(
                    request,
                    districtID: districtID
                )
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
    ) async throws -> SurveyResponse {
        if let synchronizationError {
            throw synchronizationError
        }
        var response = request.response
        let version = if let serverCounter {
            await serverCounter.synchronize(expectedVersion: response.recordVersion)
        } else {
            response.recordVersion
        }
        response.markSynchronized(serverRecordVersion: version)
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

private actor SurveyServerCounter {
    private(set) var expectedVersions: [Int] = []

    func synchronize(expectedVersion: Int) -> Int {
        expectedVersions.append(expectedVersion)
        return expectedVersion + 1
    }
}

private actor SurveyReviewStorage {
    private(set) var response: SurveyResponse?

    func save(_ response: SurveyResponse) {
        self.response = response
    }
}

private actor SurveyAssignmentMutationRecorder {
    private(set) var requests: [SurveyAssignmentMutationRequest] = []

    func mutate(
        _ request: SurveyAssignmentMutationRequest,
        districtID: String
    ) throws -> SurveyAssignment {
        requests.append(request)
        return try SurveyAssignment(
            assignmentID: request.assignmentID,
            attemptID: "server-attempt",
            districtID: districtID,
            studentID: request.studentID,
            definitionID: request.definitionID,
            definitionVersion: request.definitionVersion,
            state: request.action == .revoke ? .revoked : .active,
            recordVersion: request.expectedRecordVersion + 1,
            assignedAt: Date(timeIntervalSince1970: 5_000),
            revokedAt: request.action == .revoke
                ? Date(timeIntervalSince1970: 6_000)
                : nil
        )
    }
}
