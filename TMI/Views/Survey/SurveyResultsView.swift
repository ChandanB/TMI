import SwiftUI

struct SurveyResultsView: View {
    let definition: SurveyDefinition
    let response: SurveyResponse
    let onAskForHelp: () async -> Bool
    let onFinish: () -> Void
    @State private var helpRequested = false
    @State private var helpError = false
    @State private var isRequestingHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: TMISpacing.xl) {
                Image(systemName: "sparkles")
                    .font(.largeTitle.bold())
                    .foregroundStyle(TMIColors.teal)
                    .accessibilityHidden(true)
                Text("Nice work!").font(.largeTitle.bold())
                Text("Here are some things you said you enjoy.")
                    .font(.title3)
                    .foregroundStyle(TMIColors.textSecondary)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    ForEach(studentSafeAnswers, id: \.questionID) { item in
                        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                            Text(item.prompt).font(.subheadline).foregroundStyle(TMIColors.textSecondary)
                            Text(item.answer).font(.headline).foregroundStyle(TMIColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(TMISpacing.md)
                        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.lg))
                    }
                }
                .frame(maxWidth: 680)
                Button("Ask for help", systemImage: "hand.raised.fill") {
                    Task { @MainActor in
                        guard !isRequestingHelp, !helpRequested else { return }
                        isRequestingHelp = true
                        defer { isRequestingHelp = false }
                        helpRequested = await onAskForHelp()
                        helpError = !helpRequested
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isRequestingHelp || helpRequested)
                .accessibilityHint("Lets your educator know you would like a non-emergency check-in.")
                .accessibilityIdentifier("studentSurvey.help")
                if helpRequested {
                    Text("Your educator will check in with you.")
                        .font(.headline)
                        .foregroundStyle(TMIColors.infoText)
                }
                if helpError {
                    Text("We couldn’t send that yet. Please tell your educator directly.")
                        .font(.headline)
                        .foregroundStyle(TMIColors.errorText)
                }
                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("studentSurvey.finish")
            }
            .frame(maxWidth: .infinity)
            .padding(TMISpacing.xl)
        }
        .accessibilityIdentifier("studentSurvey.results")
    }

    private var studentSafeAnswers: [(questionID: String, prompt: String, answer: String)] {
        definition.questions.compactMap { question in
            guard let answer = response.answers[question.id] else { return nil }
            let labels = Dictionary(uniqueKeysWithValues: question.options.map { ($0.id, $0.label) })
            let value: String
            switch answer {
            case .single(let id), .image(let id): value = labels[id] ?? id
            case .multiple(let ids): value = ids.sorted().map { labels[$0] ?? $0 }.joined(separator: ", ")
            case .text(let text): value = text
            case .rating(let rating): value = "\(rating)"
            }
            return (question.id, question.prompt, value)
        }
    }
}

struct StaffSurveyInterestReviewView: View {
    let definition: SurveyDefinition
    let response: SurveyResponse
    let analysis: InterestAnalysisResult
    let onClose: () -> Void

    @State private var selectedInterestIDs: Set<String>
    @State private var operationID = "interest-approval-\(UUID().uuidString)"
    @State private var isApproving = false
    @State private var approvalMessage: String?
    @State private var approvalFailed = false

    init(
        definition: SurveyDefinition,
        response: SurveyResponse,
        analysis: InterestAnalysisResult,
        onClose: @escaping () -> Void
    ) {
        self.definition = definition
        self.response = response
        self.analysis = analysis
        self.onClose = onClose
        _selectedInterestIDs = State(initialValue: Set(analysis.proposedInterests.map(\.interestID)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.xl) {
                Text("Review survey interests")
                    .font(.largeTitle.bold())
                Text("Review the submitted answers and deterministic proposals before adding interests to the student record.")
                    .foregroundStyle(.secondary)

                reviewSection("Submitted responses") {
                    ForEach(responseRows, id: \.questionID) { row in
                        LabeledContent(row.prompt, value: row.answer)
                    }
                }

                reviewSection("Proposed interests") {
                    ForEach(analysis.proposedInterests) { interest in
                        Toggle(isOn: selectionBinding(for: interest.interestID)) {
                            VStack(alignment: .leading) {
                                Text(interest.name)
                                Text("\(interest.category.capitalized) · score \(interest.score) · rank \(interest.rank)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                reviewSection("Analysis rationale") {
                    ForEach(analysis.rationale, id: \.self) { rationale in
                        Label(rationale, systemImage: "list.number")
                    }
                    Text("Algorithm version \(analysis.algorithmVersion); survey definition \(analysis.definitionID) v\(analysis.definitionVersion).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                reviewSection("Student projection") {
                    Text(selectedNames.isEmpty ? "No interests selected." : selectedNames.joined(separator: ", "))
                        .font(.headline)
                    Text("Only approved items will appear in the student’s interest profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let approvalMessage {
                    Text(approvalMessage)
                        .foregroundStyle(approvalFailed ? TMIColors.errorText : TMIColors.infoText)
                }

                HStack {
                    Button("Reject proposals") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Closes this review without changing the submitted survey or student interests.")
                    Spacer()
                    Button("Approve selected interests") {
                        Task { await approve() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedInterestIDs.isEmpty || isApproving || !isApprovable)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(TMISpacing.xl)
        }
    }

    private var isApprovable: Bool {
        response.state == .submitted || response.state == .reviewed
    }

    private var selectedNames: [String] {
        analysis.proposedInterests
            .filter { selectedInterestIDs.contains($0.interestID) }
            .map(\.name)
    }

    private var responseRows: [(questionID: String, prompt: String, answer: String)] {
        definition.questions.compactMap { question in
            guard let answer = response.answers[question.id] else { return nil }
            let labels = Dictionary(uniqueKeysWithValues: question.options.map { ($0.id, $0.label) })
            let text: String
            switch answer {
            case .single(let id), .image(let id): text = labels[id] ?? id
            case .multiple(let ids): text = ids.sorted().map { labels[$0] ?? $0 }.joined(separator: ", ")
            case .text(let value): text = value
            case .rating(let value): text = String(value)
            }
            return (question.id, question.prompt, text)
        }
    }

    @ViewBuilder
    private func reviewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text(title).font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TMISpacing.lg)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.lg))
    }

    private func selectionBinding(for interestID: String) -> Binding<Bool> {
        Binding(
            get: { selectedInterestIDs.contains(interestID) },
            set: { selected in
                if selected {
                    selectedInterestIDs.insert(interestID)
                } else {
                    selectedInterestIDs.remove(interestID)
                }
            }
        )
    }

    @MainActor
    private func approve() async {
        guard !isApproving else { return }
        isApproving = true
        approvalMessage = nil
        defer { isApproving = false }
        do {
            let approved = try await StudentInterestService.shared.approve(
                StudentInterestApproval(
                    districtID: response.districtID,
                    studentID: response.studentID,
                    response: response,
                    analysis: analysis,
                    interestIDs: selectedInterestIDs,
                    operationID: operationID
                )
            )
            approvalFailed = false
            approvalMessage = "Approved \(approved.count) canonical interests."
        } catch {
            approvalFailed = true
            approvalMessage = error.localizedDescription
        }
    }
}
