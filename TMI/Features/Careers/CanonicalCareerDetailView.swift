import SwiftUI

/// One career, read in full.
///
/// Named `CanonicalCareerDetailView` while the legacy `CareerDetailView`
/// still exists; the two cannot share a name in one module.
struct CanonicalCareerDetailView: View {
    let career: CareerRecord
    let match: CareerMatch?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.lg) {
                header

                if let match {
                    section("Why this is here") {
                        // The rationale is disclosed, never implied. A student
                        // can see the inputs and disagree with them.
                        ForEach(Array(match.reasons.enumerated()), id: \.offset) { _, reason in
                            Label(reason, systemImage: "sparkles")
                                .font(.subheadline)
                        }
                    }
                    .accessibilityIdentifier("careerDetail.rationale")
                }

                section("What this work is") {
                    Text(career.summary)
                        .font(.body)
                }

                section("Education and training") {
                    LabeledContent("Typical route", value: career.educationLevel.displayName)
                }

                section("Pay and outlook") {
                    if let salary = career.salary {
                        LabeledContent("Typical pay", value: salary.displayRange)
                        Text("\(salary.source), as of \(salary.asOf.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(TMIColors.textSecondary)
                    } else {
                        // Saying nothing is better than repeating a number
                        // nobody can stand behind.
                        Text("Pay and outlook are not published for this career yet.")
                            .font(.subheadline)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                    if let outlook = career.outlook {
                        Text(outlook.summary).font(.body)
                        Text("\(outlook.source), as of \(outlook.asOf.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                }
                .accessibilityIdentifier("careerDetail.payAndOutlook")

                section("Interests this draws on") {
                    Text(career.interestIDs.isEmpty
                        ? "Not linked to an interest yet."
                        : career.interestIDs.map(Self.readable).joined(separator: ", "))
                        .font(.body)
                }

                Label("Attaching a career to a plan arrives in Release 3.", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(TMIColors.textSecondary)
                    .accessibilityIdentifier("careerDetail.planAttachmentUnavailable")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TMISpacing.lg)
        }
        .navigationTitle(career.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("careerDetail.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
            Text(career.title)
                .font(.largeTitle.bold())
            Text(Self.readable(career.category))
                .font(.headline)
                .foregroundStyle(TMIColors.aubergine)
            if let subcategory = career.subcategory {
                Text(subcategory)
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.xs) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
    }

    static func readable(_ identifier: String) -> String {
        identifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

extension CareerEducationLevel {
    var displayName: String {
        switch self {
        case .highSchool: "High school"
        case .certificate: "Certificate or apprenticeship"
        case .associates: "Associate degree"
        case .bachelors: "Bachelor's degree"
        case .masters: "Master's degree"
        case .doctorate: "Doctorate"
        case .varies: "Varies"
        }
    }
}

extension CareerSalary {
    var displayRange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        let low = formatter.string(from: NSNumber(value: minimum)) ?? "\(minimum)"
        let high = formatter.string(from: NSNumber(value: maximum)) ?? "\(maximum)"
        return "\(low) – \(high)"
    }
}
