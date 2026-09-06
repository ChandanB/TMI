import SwiftUI

/// One career, read in full.
///
/// Named `CanonicalCareerDetailView` while the legacy `CareerDetailView`
/// still exists; the two cannot share a name in one module.
struct CanonicalCareerDetailView: View {
    let career: CareerRecord
    let match: CareerMatch?
    var studentContext: CareerPlanAttachmentContext?
    var onViewed: @MainActor () async -> Void = {}

    @State private var attachmentShown = false

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

                ShareLink(item: shareText) {
                    Label("Share career", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("careerDetail.share")

                if studentContext != nil {
                    Button("Attach to a plan", systemImage: "link") {
                        attachmentShown = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("careerDetail.planAttachment")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TMISpacing.lg)
        }
        .navigationTitle(career.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("careerDetail.screen")
        .task { await onViewed() }
        .sheet(isPresented: $attachmentShown) {
            if let studentContext {
                CareerPlanAttachmentSheet(
                    studentID: studentContext.studentID,
                    studentName: studentContext.studentName,
                    career: career,
                    member: studentContext.member,
                    repository: studentContext.planRepository,
                    attacher: studentContext.planAttacher ?? FirebaseCareerPlanAttacher(),
                    onAttached: studentContext.onAttached
                )
            }
        }
    }

    private var shareText: String {
        "\(career.title)\n\n\(career.summary)\n\nEducation: \(career.educationLevel.displayName)"
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

@MainActor
struct CareerPlanAttachmentContext {
    let studentID: String
    let studentName: String
    let member: MembershipContext
    let planRepository: any PlanRecordRepository
    var planAttacher: (any CareerPlanAttaching)?
    var onAttached: @MainActor () async -> Void = {}
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
