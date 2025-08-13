
//
//  StudentDetailStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import Foundation
import Observation

@Observable
class StudentDetailStateModel {
    enum State {
        case idle
        case loading
        case loaded
        case error(Error)
    }
    
    var state: State = .idle
    var tmiPlans: [TMIPlan] = []
    
    private let student: Student
    private let planService = TMIPlanService()
    
    init(student: Student) {
        self.student = student
    }
    
    @MainActor
    func fetchTMIPlans() async {
        state = .loading
        do {
            if let studentId = student.id {
                tmiPlans = try await planService.getPlansForStudent(studentId)
            }
            state = .loaded
        } catch {
            state = .error(error)
        }
    }
}
