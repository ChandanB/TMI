
//
//  StudentDetailStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
class StudentDetailStateModel {
    struct Summary: Equatable, Sendable {
        enum FollowUpStatus: Equatable, Sendable {
            case surveyPending
            case planNeeded
            case planFollowUp
            case engagementCheckIn
            case onTrack

            var title: String {
                switch self {
                case .surveyPending:
                    return "Complete the interest survey"
                case .planNeeded:
                    return "Create the first TMI plan"
                case .planFollowUp:
                    return "Follow up on current intervention"
                case .engagementCheckIn:
                    return "Check in on engagement"
                case .onTrack:
                    return "Keep momentum going"
                }
            }

            var detail: String {
                switch self {
                case .surveyPending:
                    return "The student still needs a completed interest survey."
                case .planNeeded:
                    return "The interest survey is complete, but the student still needs a plan."
                case .planFollowUp:
                    return "There is plan work waiting on review, approval, or revision."
                case .engagementCheckIn:
                    return "Recent engagement is low enough to warrant a teacher touchpoint."
                case .onTrack:
                    return "Survey, plan, and current engagement all look covered."
                }
            }

            var symbolName: String {
                switch self {
                case .surveyPending:
                    return "list.clipboard"
                case .planNeeded:
                    return "doc.badge.plus"
                case .planFollowUp:
                    return "checklist"
                case .engagementCheckIn:
                    return "figure.teacher"
                case .onTrack:
                    return "checkmark.circle"
                }
            }
        }

        var activePlanCount: Int
        var assignedNextStepCount: Int
        var needsFollowUp: Bool
        var followUpStatus: FollowUpStatus
    }

    enum State {
        case idle
        case loading
        case loaded
        case error(Error)
    }

    var state: State = .loading
    var student: Student?
    var tmiPlans: [TMIPlan] = []
    var errorMessage: String?
    var summary: Summary {
        let hasCompletedSurvey = student?.surveyResults?.contains(where: { $0.isComplete }) ?? false
        let hasPlans = !tmiPlans.isEmpty
        let plansNeedingFollowUp = tmiPlans.filter {
            $0.approvalStatus == .draft
                || $0.approvalStatus == .pendingApproval
                || $0.approvalStatus == .changesRequested
        }.count
        let needsEngagementCheckIn = (student?.engagementScore ?? 1) < 0.3

        let followUpStatus: Summary.FollowUpStatus
        if !hasCompletedSurvey {
            followUpStatus = .surveyPending
        } else if !hasPlans {
            followUpStatus = .planNeeded
        } else if plansNeedingFollowUp > 0 {
            followUpStatus = .planFollowUp
        } else if needsEngagementCheckIn {
            followUpStatus = .engagementCheckIn
        } else {
            followUpStatus = .onTrack
        }

        var assignedNextStepCount = plansNeedingFollowUp
        if !hasCompletedSurvey {
            assignedNextStepCount += 1
        } else if !hasPlans {
            assignedNextStepCount += 1
        }
        if needsEngagementCheckIn {
            assignedNextStepCount += 1
        }

        return Summary(
            activePlanCount: tmiPlans.count,
            assignedNextStepCount: assignedNextStepCount,
            needsFollowUp: followUpStatus != .onTrack,
            followUpStatus: followUpStatus
        )
    }

    private let studentId: String
    private let studentService = StudentService.shared
    private let planService = TMIPlanService.shared
    nonisolated(unsafe) private var studentListener: ListenerRegistration?

    init(studentId: String) {
        self.studentId = studentId
    }

    deinit {
        stopListening()
    }

    func startListening() {
        print("[StudentDetailStateModel] Starting listener for student: \(studentId)")
        state = .loading

        studentListener = studentService.listenToStudent(id: studentId) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let student):
                    print("[StudentDetailStateModel] Student updated: \(student.name)")
                    self.student = student
                    self.state = .loaded
                    self.errorMessage = nil

                    // Fetch TMI plans when student loads
                    await self.fetchTMIPlans()

                case .failure(let error):
                    print("[StudentDetailStateModel] Error: \(error)")
                    self.state = .error(error)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    nonisolated func stopListening() {
        print("[StudentDetailStateModel] Stopping listener for student: \(studentId)")
        studentListener?.remove()
        studentListener = nil
    }

    func refreshTMIPlans() async {
        do {
            tmiPlans = try await planService.getPlansForStudent(studentId)
            print("[StudentDetailStateModel] Fetched \(tmiPlans.count) TMI plans")
        } catch {
            print("[StudentDetailStateModel] Failed to fetch TMI plans: \(error)")
            // Don't override the main state - student data is still valid
            // Just log the error
        }
    }

    private func fetchTMIPlans() async {
        await refreshTMIPlans()
    }
}
