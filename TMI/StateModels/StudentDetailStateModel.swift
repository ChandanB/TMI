
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

    private func fetchTMIPlans() async {
        do {
            tmiPlans = try await planService.getPlansForStudent(studentId)
            print("[StudentDetailStateModel] Fetched \(tmiPlans.count) TMI plans")
        } catch {
            print("[StudentDetailStateModel] Failed to fetch TMI plans: \(error)")
            // Don't override the main state - student data is still valid
            // Just log the error
        }
    }
}
