import SwiftUI

/// A compact, read-only strip surfacing recommendations for a plan's
/// student. Generation and dismissal are out of scope here — this view
/// only reads whatever `RecommendationsStateModel` already has.
struct PlanRecommendationsStrip: View {
    let studentID: String
    let planID: String

    @State private var recommendationsStateModel = RecommendationsStateModel()

    var body: some View {
        content(model: recommendationsStateModel)
            .task(id: "\(studentID):\(planID)") {
                await recommendationsStateModel.setContext(studentId: studentID, planId: planID)
            }
    }

    @ViewBuilder
    private func content(model: RecommendationsStateModel) -> some View {
        switch model.state {
        case .idle, .loading:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading recommendations…")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            }
        case .error:
            Text("Recommendations unavailable right now.")
                .font(.subheadline)
                .foregroundStyle(TMIColors.textSecondary)
                .accessibilityIdentifier("planRecommendations.error")
        case .loaded(let recommendations):
            if recommendations.isEmpty {
                Text("No recommendations yet.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("planRecommendations.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: TMISpacing.md) {
                        ForEach(recommendations) { recommendation in
                            RecommendationCard(recommendation: recommendation)
                        }
                    }
                    .padding(.vertical, TMISpacing.xxs)
                }
                .accessibilityIdentifier("planRecommendations.list")
            }
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                priorityBadge
            }

            let detail = recommendation.description.isEmpty
                ? recommendation.rationale
                : recommendation.description
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(TMIColors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(TMISpacing.sm)
        .frame(width: 220, alignment: .leading)
        .background(TMIColors.background, in: RoundedRectangle(cornerRadius: TMIRadius.sm))
        .accessibilityIdentifier("planRecommendations.card.\(recommendation.id)")
    }

    private var priorityBadge: some View {
        Text(recommendation.priority.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, TMISpacing.xs)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.15), in: Capsule())
            .foregroundStyle(priorityColor)
    }

    private var priorityColor: Color {
        switch recommendation.priority {
        case .low: return .secondary
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}
