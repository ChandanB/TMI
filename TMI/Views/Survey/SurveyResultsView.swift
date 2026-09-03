import SwiftUI

struct SurveyResultsView: View {
    let definition: SurveyDefinition
    let response: SurveyResponse
    let onAskForHelp: () async -> Bool
    let onFinish: () -> Void
    @State private var helpRequested = false
    @State private var helpError = false

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
                        helpRequested = await onAskForHelp()
                        helpError = !helpRequested
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
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
