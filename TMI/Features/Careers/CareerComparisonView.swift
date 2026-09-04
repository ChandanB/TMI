import SwiftUI

/// Two or three careers, side by side.
///
/// Comparison is the moment a student weighs one future against another, so
/// every row says the same thing about each career — including when the
/// answer is that nobody has published it.
struct CareerComparisonView: View {
    let careers: [CareerRecord]
    let matches: [String: CareerMatch]
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .topLeading, horizontalSpacing: TMISpacing.lg, verticalSpacing: TMISpacing.md) {
                    GridRow {
                        Text("")
                            .gridColumnAlignment(.leading)
                        ForEach(careers) { career in
                            Text(career.title)
                                .font(.headline)
                                .frame(minWidth: 160, alignment: .leading)
                        }
                    }
                    Divider()
                    row("Field") { Text(CanonicalCareerDetailView.readable($0.category)) }
                    row("Education") { Text($0.educationLevel.displayName) }
                    row("Pay") { career in
                        if let salary = career.salary {
                            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                Text(salary.displayRange)
                                Text(salary.source)
                                    .font(.caption)
                                    .foregroundStyle(TMIColors.textSecondary)
                            }
                        } else {
                            Text("Not published")
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                    }
                    row("Why it is here") { career in
                        if let reasons = matches[career.id]?.reasons, !reasons.isEmpty {
                            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                                    Text(reason).font(.caption)
                                }
                            }
                        } else {
                            Text("You searched for it")
                                .font(.caption)
                                .foregroundStyle(TMIColors.textSecondary)
                        }
                    }
                    row("What it is") { Text($0.summary).font(.caption) }
                }
                .padding(TMISpacing.lg)
            }
            .navigationTitle("Compare careers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .accessibilityIdentifier("careerComparison.screen")
        }
    }

    @ViewBuilder
    private func row(
        _ label: String,
        @ViewBuilder value: @escaping (CareerRecord) -> some View
    ) -> some View {
        GridRow {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TMIColors.textSecondary)
                .gridColumnAlignment(.leading)
            ForEach(careers) { career in
                value(career)
                    .frame(minWidth: 160, alignment: .leading)
            }
        }
        Divider()
    }
}
