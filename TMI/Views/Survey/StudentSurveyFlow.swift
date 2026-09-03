import SwiftUI

enum SurveyContext { case studentDetail; case planDetail(planId: String) }

struct StudentSurveyFlow: View {
    let assignment: SurveyAssignment?
    let definition: SurveyDefinition?
    let grant: StudentModeGrant?
    let repository: SurveyRepository?
    var onActivity: () -> Void = {}
    var onSaveForLater: () -> Void = {}
    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var response: SurveyResponse?
    @State private var visibleQuestionIDs: [String] = []
    @State private var questionIndex = 0
    @State private var phase: Phase = .welcome
    @State private var isSaving = false
    @State private var message: String?

    private enum Phase { case welcome, questions, review, paused, results }

    init(
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant,
        repository: SurveyRepository,
        onActivity: @escaping () -> Void = {},
        onSaveForLater: @escaping () -> Void = {},
        onFinish: @escaping () -> Void = {}
    ) {
        self.assignment = assignment
        self.definition = definition
        self.grant = grant
        self.repository = repository
        self.onActivity = onActivity
        self.onSaveForLater = onSaveForLater
        self.onFinish = onFinish
    }

    // Legacy staff sheets no longer host a second survey engine.
    init(studentId: String, context: SurveyContext = .studentDetail, showCancelButton: Bool = true) {
        assignment = nil
        definition = nil
        grant = nil
        repository = nil
    }

    var body: some View {
        Group {
            if let assignment, let definition, let grant, let repository {
                canonicalContent(
                    assignment: assignment,
                    definition: definition,
                    grant: grant,
                    repository: repository
                )
            } else {
                ContentUnavailableView(
                    "Use Student Mode",
                    systemImage: "lock.shield",
                    description: Text("Ask an educator to launch your assigned activity in Student Mode.")
                )
            }
        }
        .task { await resumeDraft() }
    }

    @ViewBuilder
    private func canonicalContent(
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant,
        repository: SurveyRepository
    ) -> some View {
        switch phase {
        case .welcome:
            welcome(definition: definition)
        case .questions:
            questions(definition: definition)
        case .review:
            review(definition: definition, assignment: assignment, grant: grant, repository: repository)
        case .paused:
            paused
        case .results:
            if let response {
                SurveyResultsView(
                    definition: definition,
                    response: response,
                    onAskForHelp: {
                        onActivity()
                        do {
                            try await repository.requestHelp(
                                operationID: UUID().uuidString,
                                grant: grant
                            )
                            return true
                        } catch {
                            return false
                        }
                    },
                    onFinish: onFinish
                )
            }
        }
    }

    private func welcome(definition: SurveyDefinition) -> some View {
        VStack(spacing: TMISpacing.xl) {
            Image(systemName: "hand.wave.fill")
                .font(.largeTitle)
                .foregroundStyle(TMIColors.teal)
                .accessibilityHidden(true)
            Text("Let’s learn what you like")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("There are no wrong answers. Pick what feels most like you, and you can go back anytime.")
                .font(.title3)
                .foregroundStyle(TMIColors.textSecondary)
                .multilineTextAlignment(.center)
            Text("Activity version \(definition.version)")
                .font(.caption)
                .foregroundStyle(TMIColors.textSecondary)
            Button("Start", systemImage: "arrow.right") {
                onActivity()
                phase = .questions
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("studentSurvey.begin")
        }
        .frame(maxWidth: 680)
        .padding(TMISpacing.xl)
    }

    private func questions(definition: SurveyDefinition) -> some View {
        VStack(spacing: 0) {
            progress
            ScrollView {
                if let question = currentQuestion(in: definition) {
                    SurveyQuestionView(
                        question: question,
                        answer: response?.answers[question.id],
                        onAnswer: { answer in autosave(answer, for: question.id) }
                    )
                    .padding(TMISpacing.xl)
                }
            }
            controls(definition: definition)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
            Text("Step \(questionIndex + 1) of \(max(visibleQuestionIDs.count, 1))")
                .font(.headline)
            ProgressView(value: Double(questionIndex + 1), total: Double(max(visibleQuestionIDs.count, 1)))
                .tint(TMIColors.teal)
        }
        .padding(.horizontal, TMISpacing.xl)
        .padding(.top, TMISpacing.md)
        .accessibilityIdentifier("studentSurvey.progress")
    }

    private func controls(definition: SurveyDefinition) -> some View {
        VStack(spacing: TMISpacing.sm) {
            if let message { Text(message).font(.subheadline).foregroundStyle(TMIColors.infoText) }
            HStack(spacing: TMISpacing.md) {
                Button("Back", systemImage: "chevron.left") { moveBack() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(questionIndex == 0 || isSaving)
                    .accessibilityIdentifier("studentSurvey.back")
                Button("Next", systemImage: "chevron.right") { moveNext(definition: definition) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canContinue(definition: definition) || isSaving)
                    .accessibilityIdentifier("studentSurvey.next")
            }
            Button("Save and finish later") {
                Task { await saveForLater() }
            }
            .controlSize(.large)
            .disabled(isSaving)
            .accessibilityIdentifier("studentSurvey.saveLater")
        }
        .padding(TMISpacing.md)
        .frame(maxWidth: .infinity)
        .background(TMIColors.surface)
    }

    private func review(
        definition: SurveyDefinition,
        assignment: SurveyAssignment,
        grant: StudentModeGrant,
        repository: SurveyRepository
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.lg) {
                Text("Check your answers").font(.largeTitle.bold())
                Text("Take a look before you send them. After you send them, they cannot be changed.")
                    .font(.title3).foregroundStyle(TMIColors.textSecondary)
                ForEach(visibleQuestionIDs, id: \.self) { id in
                    if let question = definition.questions.first(where: { $0.id == id }) {
                        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                            Text(question.prompt).font(.headline)
                            Text(reviewText(for: question)).foregroundStyle(TMIColors.textSecondary)
                        }
                        .padding(TMISpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.lg))
                    }
                }
                HStack {
                    Button("Back to answers") { phase = .questions }
                        .buttonStyle(.bordered).controlSize(.large)
                    Button("Send my answers") {
                        Task { await submit(assignment: assignment, definition: definition, grant: grant, repository: repository) }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(isSaving)
                    .accessibilityIdentifier("studentSurvey.submit")
                }
                if let message { Text(message).foregroundStyle(TMIColors.errorText) }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(TMISpacing.xl)
        }
    }

    private var paused: some View {
        VStack(spacing: TMISpacing.lg) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(TMIColors.teal)
            Text("Your answers are saved.").font(.title.bold())
            Text("You can come back and keep going when you’re ready.")
                .font(.title3).foregroundStyle(TMIColors.textSecondary)
            Button("Keep going") { phase = .questions }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("studentSurvey.resume")
        }
        .padding(TMISpacing.xl)
    }

    private func currentQuestion(in definition: SurveyDefinition) -> SurveyQuestion? {
        guard visibleQuestionIDs.indices.contains(questionIndex) else { return nil }
        let id = visibleQuestionIDs[questionIndex]
        return definition.questions.first { $0.id == id }
    }

    private func autosave(_ answer: SurveyAnswer, for questionID: String) {
        guard let assignment, let definition, let grant, let repository else { return }
        onActivity()
        isSaving = true
        message = "Saving…"
        Task { @MainActor in
            do {
                response = try await repository.autosave(
                    answer: answer,
                    for: questionID,
                    operationID: UUID().uuidString,
                    assignment: assignment,
                    definition: definition,
                    grant: grant
                )
                visibleQuestionIDs = (try? definition.visibleQuestionIDs(answers: response?.answers ?? [:])) ?? []
                message = response?.hasPendingChanges == true ? "Saved on this device" : "Saved"
            } catch { message = friendly(error) }
            isSaving = false
        }
    }

    private func resumeDraft() async {
        guard let assignment, let definition, let grant, let repository else { return }
        do {
            response = try await repository.resume(assignment: assignment, grant: grant)
            visibleQuestionIDs = try definition.visibleQuestionIDs(answers: response?.answers ?? [:])
        } catch { message = friendly(error) }
    }

    private func saveForLater() async {
        guard let assignment, let definition, let grant, let repository else { return }
        onActivity()
        isSaving = true
        do {
            response = try await repository.synchronize(assignment: assignment, definition: definition, grant: grant)
            phase = .paused
            onSaveForLater()
        } catch SurveyRepositoryError.offline {
            // Local autosave is already durable and intentionally supports interruption.
            phase = .paused
            onSaveForLater()
        } catch { message = friendly(error) }
        isSaving = false
    }

    private func submit(
        assignment: SurveyAssignment,
        definition: SurveyDefinition,
        grant: StudentModeGrant,
        repository: SurveyRepository
    ) async {
        onActivity()
        isSaving = true
        do {
            response = try await repository.submit(
                operationID: UUID().uuidString,
                assignment: assignment,
                definition: definition,
                grant: grant
            )
            phase = .results
        } catch { message = friendly(error) }
        isSaving = false
    }

    private func moveBack() {
        onActivity()
        transition { questionIndex -= 1 }
    }
    private func moveNext(definition: SurveyDefinition) {
        onActivity()
        if questionIndex + 1 < visibleQuestionIDs.count {
            transition { questionIndex += 1 }
        } else { transition { phase = .review } }
    }
    private func transition(_ changes: () -> Void) {
        if reduceMotion { changes() } else { withAnimation(.easeInOut(duration: 0.2), changes) }
    }
    private func canContinue(definition: SurveyDefinition) -> Bool {
        guard let question = currentQuestion(in: definition) else { return false }
        return !question.isRequired || response?.answers[question.id]?.isMeaningful == true
    }
    private func reviewText(for question: SurveyQuestion) -> String {
        guard let answer = response?.answers[question.id] else { return "Skipped" }
        let labels = Dictionary(uniqueKeysWithValues: question.options.map { ($0.id, $0.label) })
        switch answer {
        case .single(let id), .image(let id): return labels[id] ?? id
        case .multiple(let ids): return ids.sorted().map { labels[$0] ?? $0 }.joined(separator: ", ")
        case .text(let text): return text
        case .rating(let value): return "\(value)"
        }
    }
    private func friendly(_ error: Error) -> String {
        switch error {
        case SurveyRepositoryError.offline: "You’re offline. Your answers stay saved here; connect before sending."
        case SurveyRepositoryError.revoked: "This activity is no longer available. Please ask your educator."
        case SurveyRepositoryError.expired, SurveyRepositoryError.authorization: "This activity ended. Please ask your educator."
        default: "We couldn’t save that yet. Please try again."
        }
    }
}
