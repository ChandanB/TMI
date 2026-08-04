//
//  SurveyStepViews.swift
//  TMI
//
//  Individual survey step components for different question types
//

import SwiftUI

// MARK: - Intro Step

struct IntroStepView: View {
    let step: SurveyStep

    var body: some View {
        VStack(spacing: TMISpacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.tmiPrimary)
                .symbolEffect(.bounce, value: true)

            // Title
            Text(step.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.tmiTextPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TMISpacing.xl)
            }

            // Estimated time
            HStack(spacing: TMISpacing.sm) {
                Image(systemName: "clock")
                    .foregroundColor(.tmiTextTertiary)
                Text("10-12 minutes")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextTertiary)
            }
            .padding(.top, TMISpacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Multi-Select Step

struct MultiSelectStepView: View {
    let step: SurveyStep
    @Binding var selectedOptions: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Title
            Text(step.title)
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

            // Options Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMISpacing.md) {
                ForEach(step.options) { option in
                    MultiSelectOption(
                        option: option,
                        isSelected: selectedOptions.contains(option.id),
                        onTap: {
                            if selectedOptions.contains(option.id) {
                                selectedOptions.remove(option.id)
                            } else {
                                selectedOptions.insert(option.id)
                            }
                            TMIHaptics.lightImpact()
                        }
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }
}

struct MultiSelectOption: View {
    let option: LegacySurveyOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: TMISpacing.sm) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.tmiPrimary.opacity(0.2) : Color.tmiSurface)
                        .frame(width: 60, height: 60)

                    Image(systemName: option.icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .tmiPrimary : .tmiTextSecondary)
                }

                // Text
                Text(option.text)
                    .font(.tmiCaption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .tmiPrimary : .tmiTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(isSelected ? Color.tmiPrimary.opacity(0.1) : Color.tmiSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .strokeBorder(isSelected ? Color.tmiPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Single Select Step

struct SingleSelectStepView: View {
    let step: SurveyStep
    @Binding var selectedOption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Title
            Text(step.title)
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

            // Options List
            VStack(spacing: TMISpacing.md) {
                ForEach(step.options) { option in
                    SingleSelectOption(
                        option: option,
                        isSelected: selectedOption == option.id,
                        onTap: {
                            selectedOption = option.id
                            TMIHaptics.lightImpact()
                        }
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }
}

struct SingleSelectOption: View {
    let option: LegacySurveyOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TMISpacing.md) {
                // Radio button
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.tmiPrimary : Color.tmiTextTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.tmiPrimary)
                            .frame(width: 12, height: 12)
                    }
                }

                // Icon
                Image(systemName: option.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .tmiPrimary : .tmiTextSecondary)
                    .frame(width: 40)

                // Text
                Text(option.text)
                    .font(.tmiBody)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(isSelected ? Color.tmiPrimary.opacity(0.1) : Color.tmiSurface)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scale Step

struct ScaleStepView: View {
    let step: SurveyStep
    @Binding var selectedScale: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xl) {
            // Title
            Text(step.title)
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

            Spacer()

            // Scale selector
            VStack(spacing: TMISpacing.lg) {
                HStack(spacing: TMISpacing.md) {
                    ForEach(1...5, id: \.self) { value in
                        ScaleButton(
                            value: value,
                            isSelected: selectedScale == value,
                            onTap: {
                                selectedScale = value
                                TMIHaptics.mediumImpact()
                            }
                        )
                    }
                }

                // Labels
                HStack {
                    Text("Not important")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextTertiary)
                    Spacer()
                    Text("Very important")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextTertiary)
                }
            }
            .padding(.horizontal, TMISpacing.md)

            Spacer()
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }
}

struct ScaleButton: View {
    let value: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isSelected ? .white : .tmiTextPrimary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(isSelected ? Color.tmiPrimary : Color.tmiSurface)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Open-Ended Step

struct OpenEndedStepView: View {
    let step: SurveyStep
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Title
            Text(step.title)
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

            // Text editor
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Share your thoughts here...")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $text)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(4)
            }
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(Color.tmiSurface)
            )

            // Character count
            HStack {
                Spacer()
                Text("\(text.count) characters")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }
}

// MARK: - Dream Job Step

struct DreamJobStepView: View {
    let step: SurveyStep
    @Binding var dreamJob: String

    @State private var suggestions = [
        "Podcaster", "Game Developer", "Graphic Designer",
        "Chef", "Athlete", "Entrepreneur", "Teacher",
        "Doctor", "Engineer", "Artist", "Musician"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Title
            Text(step.title)
                .font(.tmiTitle1)
                .foregroundColor(.tmiTextPrimary)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

            // Input field
            TextField("Type your dream job...", text: $dreamJob)
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .fill(Color.tmiSurface)
                )

            // Suggestions
            Text("Or choose from these:")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
                .padding(.top, TMISpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TMISpacing.sm) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            dreamJob = suggestion
                            TMIHaptics.lightImpact()
                        }) {
                            Text(suggestion)
                                .font(.tmiCaption)
                                .foregroundColor(dreamJob == suggestion ? .white : .tmiPrimary)
                                .padding(.horizontal, TMISpacing.md)
                                .padding(.vertical, TMISpacing.sm)
                                .background(
                                    Capsule()
                                        .fill(dreamJob == suggestion ? Color.tmiPrimary : Color.tmiPrimary.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, TMISpacing.screenPadding)
    }
}
