import SwiftUI

struct StudentInterestsSection: View {
    let districtID: String
    let studentID: String
    var schoolID: String? = nil
    var studentName: String = "the child"
    var observationRecorder: (any InterestObservationRecording)? = nil

    @Environment(\.programContext) private var programContext
    @State private var isRecordingObservation = false
    @State private var isCollectingFamilyInput = false
    @State private var familyOperationID = UUID().uuidString
    @State private var familyInputs: [FamilyInputSummary] = []
    @State private var observationOperationID = UUID().uuidString

    @State private var interests: [StudentInterest] = []
    @State private var pendingReviews: [StudentInterestReview] = []
    @State private var reviewInProgress: StudentInterestReview?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text(isObservationProgram ? "Observed interests" : "Approved interests")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                if isObservationProgram {
                    Button("Record observation", systemImage: "eye") {
                        observationOperationID = UUID().uuidString
                        isRecordingObservation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TMIColors.teal)
                    .accessibilityIdentifier("studentInterests.recordObservation")
                }
            }

            if isObservationProgram {
                familySection
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
                    isObservationProgram ? "No observed interests yet" : "No approved interests",
                    systemImage: isObservationProgram ? "eye" : "star",
                    description: Text(isObservationProgram
                        ? "Record what you see the child choose during free play. Picture Choice results appear here after staff approval."
                        : "Survey proposals appear here after staff approval.")
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
        .sheet(isPresented: $isRecordingObservation) {
            InterestObservationSheet(childName: studentName) { draft in
                let recorder = observationRecorder ?? FirebaseInterestObservationRecorder()
                try await recorder.record(
                    draft,
                    districtID: districtID,
                    studentID: studentID,
                    operationID: observationOperationID
                )
                await load()
            }
        }
        .sheet(isPresented: $isCollectingFamilyInput) {
            FamilyInputSheet(childName: studentName) { draft in
                try await FirebaseFamilyInputRecorder().record(
                    draft,
                    districtID: districtID,
                    studentID: studentID,
                    operationID: familyOperationID
                )
                await loadFamilyInputs()
            }
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

    private var familySection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack {
                Text("Family input")
                    .font(.headline)
                Spacer()
                Button("Add family input", systemImage: "house") {
                    familyOperationID = UUID().uuidString
                    isCollectingFamilyInput = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("studentInterests.familyInput")
            }
            if familyInputs.isEmpty {
                Text("Invite the family to share what their child loves, what comforts them, and their routines at home.")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            }
            ForEach(familyInputs) { input in
                VStack(alignment: .leading, spacing: TMISpacing.xs) {
                    Text("\(input.relationship ?? "Family") · \(input.submittedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline.weight(.semibold))
                    ForEach(FamilyInputDraft.questions.filter { input.answers[$0.id] != nil }) { question in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(question.prompt).font(.caption).foregroundStyle(TMIColors.textSecondary)
                            Text(input.answers[question.id] ?? "").font(.body)
                        }
                    }
                }
                .padding(TMISpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
                .accessibilityElement(children: .combine)
            }
        }
        .task(id: "\(districtID)/\(studentID)/family") { await loadFamilyInputs() }
    }

    @MainActor
    private func loadFamilyInputs() async {
        guard isObservationProgram else { return }
        familyInputs = (try? await FamilyInputReader.load(districtID: districtID, studentID: studentID)) ?? []
    }

    private var isObservationProgram: Bool {
        !programContext.profile(forSchoolID: schoolID).learnerSelfReports
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
