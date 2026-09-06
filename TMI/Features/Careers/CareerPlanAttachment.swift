@preconcurrency import FirebaseFunctions
import Foundation
import Observation
import SwiftUI

nonisolated struct CareerPlanAttachmentRequest: Sendable, Equatable {
    let districtID: String
    let studentID: String
    let careerID: String
    let planID: String
}

@MainActor
protocol CareerPlanAttaching: Sendable {
    func attach(_ request: CareerPlanAttachmentRequest) async throws -> CareerPlanAttachmentRequest
}

nonisolated enum CareerPlanAttachmentError: Error, Equatable, Sendable {
    case permissionDenied
    case unavailable
    case invalidResponse
}

@MainActor
final class FirebaseCareerPlanAttacher: CareerPlanAttaching {
    typealias Callable = @MainActor (CareerPlanAttachmentRequest) async throws -> CareerPlanAttachmentRequest

    private let call: Callable

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.call = { request in
            let result = try await functions.httpsCallable("attachCareerToPlan").call([
                "districtID": request.districtID,
                "studentID": request.studentID,
                "careerID": request.careerID,
                "planID": request.planID,
            ])
            return try Self.decode(result.data, expected: request)
        }
    }

    init(call: @escaping Callable) {
        self.call = call
    }

    func attach(_ request: CareerPlanAttachmentRequest) async throws -> CareerPlanAttachmentRequest {
        do {
            return try await self.call(request)
        } catch {
            if let attachmentError = error as? CareerPlanAttachmentError {
                throw attachmentError
            }
            let functionsError = error as NSError
            guard functionsError.domain == FunctionsErrorDomain else {
                throw CareerPlanAttachmentError.unavailable
            }
            switch FunctionsErrorCode(rawValue: functionsError.code) {
            case .permissionDenied, .unauthenticated:
                throw CareerPlanAttachmentError.permissionDenied
            case .notFound, .unavailable, .deadlineExceeded:
                throw CareerPlanAttachmentError.unavailable
            default:
                throw CareerPlanAttachmentError.invalidResponse
            }
        }
    }

    nonisolated static func decode(
        _ data: Any,
        expected request: CareerPlanAttachmentRequest
    ) throws -> CareerPlanAttachmentRequest {
        guard let response = data as? [String: Any],
              let districtID = response["districtID"] as? String,
              let studentID = response["studentID"] as? String,
              let careerID = response["careerID"] as? String,
              let planID = response["planID"] as? String else {
            throw CareerPlanAttachmentError.invalidResponse
        }
        let returned = CareerPlanAttachmentRequest(
            districtID: districtID,
            studentID: studentID,
            careerID: careerID,
            planID: planID
        )
        guard returned == request else {
            throw CareerPlanAttachmentError.invalidResponse
        }
        return returned
    }
}

@MainActor
@Observable
final class CareerPlanAttachmentState {
    private(set) var plans: [PlanRecord] = []
    private(set) var isLoading = false
    private(set) var isAttaching = false
    private(set) var errorMessage: String?
    private(set) var confirmation: String?

    static func eligiblePlans(
        from plans: [PlanRecord],
        studentID: String,
        member: MembershipContext
    ) -> [PlanRecord] {
        guard member.isActive,
              member.capabilities.contains(.studentWriteDetail),
              member.assignedStudentIDs.contains(studentID) else {
            return []
        }
        return plans.filter { plan in
            plan.districtID == member.districtID
                && !plan.schoolIDs.isDisjoint(with: member.schoolIDs)
                && plan.studentIDs.contains(studentID)
                && plan.assignedMemberIDs.contains(member.userID)
                && plan.status.isEditable
        }
        .sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func load(
        studentID: String,
        member: MembershipContext,
        repository: any PlanRecordRepository
    ) async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            let records = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                try await repository.plans(member: member)
            }
            self.plans = Self.eligiblePlans(from: records, studentID: studentID, member: member)
        } catch {
            self.plans = []
            self.errorMessage = "Plans could not be loaded. Check your connection and try again."
        }
        self.isLoading = false
    }

    func attach(
        planID: String,
        careerID: String,
        careerTitle: String,
        studentID: String,
        member: MembershipContext,
        repository: any PlanRecordRepository,
        attacher: any CareerPlanAttaching
    ) async {
        guard let selectedPlan = self.plans.first(where: { $0.id == planID }) else {
            self.errorMessage = "That plan is no longer available for editing."
            self.confirmation = nil
            return
        }
        self.isAttaching = true
        self.errorMessage = nil
        self.confirmation = nil
        do {
            let request = CareerPlanAttachmentRequest(
                districtID: member.districtID,
                studentID: studentID,
                careerID: careerID,
                planID: planID
            )
            _ = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                try await attacher.attach(request)
            }
        } catch {
            self.errorMessage = Self.attachmentMessage(for: error)
            self.isAttaching = false
            return
        }

        do {
            let records = try await withTimeout(seconds: 10) { @MainActor @Sendable in
                try await repository.plans(member: member)
            }
            self.plans = Self.eligiblePlans(from: records, studentID: studentID, member: member)
            self.confirmation = "\(careerTitle) was attached to \(selectedPlan.title)."
        } catch {
            self.errorMessage = "The career was attached, but the updated plan list could not be refreshed. Try loading it again."
        }
        self.isAttaching = false
    }

    private static func attachmentMessage(for error: Error) -> String {
        switch error {
        case CareerPlanAttachmentError.permissionDenied:
            "You no longer have permission to edit this plan."
        case CareerPlanAttachmentError.unavailable, ConcurrencyError.timeout:
            "The attachment service is unavailable. Check your connection and try again."
        default:
            "The career could not be attached. Try again."
        }
    }
}

struct CareerPlanAttachmentSheet: View {
    let studentID: String
    let studentName: String
    let career: CareerRecord
    let member: MembershipContext
    let repository: any PlanRecordRepository
    let attacher: any CareerPlanAttaching
    let onAttached: @MainActor () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state = CareerPlanAttachmentState()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: TMISpacing.md) {
                Text("\(career.title) for \(studentName)")
                    .font(.headline)
                    .accessibilityIdentifier("careerAttachment.context")

                if state.isLoading {
                    ProgressView("Loading plans…")
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("careerAttachment.loading")
                } else if let errorMessage = state.errorMessage, state.plans.isEmpty {
                    ContentUnavailableView(
                        "Plans unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    Button("Retry") {
                        Task { @MainActor in await self.load() }
                    }
                    .accessibilityIdentifier("careerAttachment.retry")
                } else if state.plans.isEmpty {
                    ContentUnavailableView(
                        "No editable plans",
                        systemImage: "doc.badge.ellipsis",
                        description: Text("No draft or changes-requested plan for \(studentName) is assigned to you.")
                    )
                    .accessibilityIdentifier("careerAttachment.empty")
                } else {
                    List(state.plans) { plan in
                        Button {
                            Task { @MainActor in await self.attach(to: plan.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                Text(plan.title)
                                Text(plan.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(TMIColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(state.isAttaching)
                        .accessibilityIdentifier("careerAttachment.plan.\(plan.id)")
                    }
                    .listStyle(.plain)
                }

                if let errorMessage = state.errorMessage, !state.plans.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(TMIColors.errorText)
                        .accessibilityIdentifier("careerAttachment.error")
                }
                if let confirmation = state.confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(TMIColors.successText)
                        .accessibilityIdentifier("careerAttachment.confirmation")
                }
            }
            .padding(TMISpacing.lg)
            .navigationTitle("Attach to a plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { self.dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .task(id: studentID) { await self.load() }
        .accessibilityIdentifier("careerAttachment.sheet")
    }

    private func load() async {
        await self.state.load(studentID: self.studentID, member: self.member, repository: self.repository)
    }

    private func attach(to planID: String) async {
        await self.state.attach(
            planID: planID,
            careerID: self.career.id,
            careerTitle: self.career.title,
            studentID: self.studentID,
            member: self.member,
            repository: self.repository,
            attacher: self.attacher
        )
        guard self.state.confirmation != nil else { return }
        await self.onAttached()
    }
}
