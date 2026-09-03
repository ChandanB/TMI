import SwiftUI

struct StudentInterestsSection: View {
    let districtID: String
    let studentID: String

    @State private var interests: [StudentInterest] = []
    @State private var pendingReviews: [StudentInterestReview] = []
    @State private var reviewInProgress: StudentInterestReview?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Approved interests")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // A submission only becomes interests once a reviewer approves it,
            // so the review lives where the interests it produces are read.
            ForEach(pendingReviews) { review in
                Button {
                    reviewInProgress = review
                } label: {
                    HStack {
                        Label(
                            "\(review.analysis.proposedInterests.count) proposed from \(review.definition.title)",
                            systemImage: "checklist"
                        )
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("studentInterests.review")
            }

            if let errorMessage {
                ContentUnavailableView(
                    "Interests unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                Button("Try Again") {
                    Task { await load() }
                }
                .buttonStyle(.bordered)
            } else if interests.isEmpty, !isLoading {
                ContentUnavailableView(
                    "No approved interests",
                    systemImage: "star",
                    description: Text("Survey proposals appear here after staff approval.")
                )
            } else {
                ForEach(interests) { interest in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                            Text(interest.name ?? interest.interestId)
                                .font(.headline)
                            Text(interest.category.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Strength \(interest.strength) of 5")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(TMISpacing.md)
                    .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .task(id: "\(districtID)/\(studentID)") {
            await load()
        }
        .sheet(item: $reviewInProgress) { review in
            StaffSurveyInterestReviewView(
                definition: review.definition,
                response: review.response,
                analysis: review.analysis
            ) {
                reviewInProgress = nil
                Task { await load() }
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            interests = try await StudentInterestService.shared.getStudentInterests(
                districtID: districtID,
                studentID: studentID
            )
            pendingReviews = try await StudentInterestService.shared.pendingInterestReviews(
                districtID: districtID,
                studentID: studentID
            )
        } catch {
            interests = []
            pendingReviews = []
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    StudentInterestsSection(districtID: "district-preview", studentID: "student-preview")
        .padding()
}
