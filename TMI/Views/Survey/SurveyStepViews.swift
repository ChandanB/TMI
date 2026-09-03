import SwiftUI

struct SurveyQuestionView: View {
    let question: SurveyQuestion
    let answer: SurveyAnswer?
    let onAnswer: (SurveyAnswer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            Text(question.prompt)
                .font(.title2.bold())
                .foregroundStyle(TMIColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            switch question.kind {
            case .singleChoice, .imageChoice:
                optionGrid(allowsMultiple: false)
            case .multiSelect:
                optionGrid(allowsMultiple: true)
            case .rating(let minimum, let maximum):
                HStack(spacing: TMISpacing.sm) {
                    ForEach(minimum...maximum, id: \.self) { value in
                        Button("\(value)") { onAnswer(.rating(value)) }
                            .buttonStyle(.borderedProminent)
                            .tint(isRatingSelected(value) ? TMIColors.teal : TMIColors.interactiveBorder)
                            .frame(minWidth: 52, minHeight: 52)
                            .accessibilityIdentifier("studentSurvey.rating.\(value)")
                    }
                }
            case .shortText(let maximumLength):
                TextField("Type your answer here", text: textBinding, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("studentSurvey.textAnswer")
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private func optionGrid(allowsMultiple: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: TMISpacing.md) {
            ForEach(question.options, id: \.id) { option in
                let selected = isSelected(option.id)
                Button {
                    choose(option.id, allowsMultiple: allowsMultiple)
                } label: {
                    HStack(spacing: TMISpacing.md) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .accessibilityHidden(true)
                        Text(option.label)
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if selected {
                            Text("Selected")
                                .font(.caption.weight(.bold))
                                .accessibilityIdentifier(
                                    "studentSurvey.selected.\(option.id)"
                                )
                        }
                    }
                    .foregroundStyle(selected ? TMIColors.infoText : TMIColors.textPrimary)
                    .padding(TMISpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(selected ? TMIColors.infoSurface : TMIColors.surface,
                                in: RoundedRectangle(cornerRadius: TMIRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: TMIRadius.lg)
                            .stroke(selected ? TMIColors.teal : TMIColors.interactiveBorder,
                                    lineWidth: selected ? 3 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityLabel(
                    selected ? "\(option.label), Selected" : option.label
                )
                .accessibilityIdentifier("studentSurvey.option.\(option.id)")
            }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                guard case .text(let value) = answer else { return "" }
                return value
            },
            set: { onAnswer(.text(String($0.prefix(maximumTextLength)))) }
        )
    }

    private var maximumTextLength: Int {
        guard case .shortText(let maximumLength) = question.kind else { return 0 }
        return maximumLength
    }

    private func isSelected(_ optionID: String) -> Bool {
        switch answer {
        case .single(let value), .image(let value): value == optionID
        case .multiple(let values): values.contains(optionID)
        default: false
        }
    }

    private func isRatingSelected(_ value: Int) -> Bool {
        guard case .rating(let selected) = answer else { return false }
        return selected == value
    }

    private func choose(_ optionID: String, allowsMultiple: Bool) {
        guard allowsMultiple else {
            onAnswer(question.kind == .imageChoice ? .image(optionID) : .single(optionID))
            return
        }
        var values: Set<String> = []
        if case .multiple(let selected) = answer { values = selected }
        if values.contains(optionID) { values.remove(optionID) } else { values.insert(optionID) }
        if case .multiSelect(let maximum) = question.kind,
           let maximum, values.count > maximum { return }
        onAnswer(.multiple(values))
    }
}
