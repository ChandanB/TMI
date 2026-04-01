//
//  StudentListStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI
import Observation

@Observable
final class StudentListStateModel: BaseStateModel<[Student], IdentifiableError> {
    
    // Form and UI state
    var searchText = ""
    var selectedFilterOption: FilterOption = .all
    var showingAddStudent = false
    var selectedStudent: Student?
    var activePlans: [String: TMIPlan] = [:]
    
    // Dependencies
    private let studentService: StudentService
    private let tmiPlanService: TMIPlanService
    
    init(studentService: StudentService = StudentService(), tmiPlanService: TMIPlanService = TMIPlanService.shared) {
        self.studentService = studentService
        self.tmiPlanService = tmiPlanService
        super.init()
    }
    
    @MainActor
    override func fetch() async {
        updateState(.loading)
        
        do {
            // Fetch students and plans concurrently
            async let studentsTask = studentService.fetchStudents()
            async let plansTask = tmiPlanService.fetchPlans()
            
            let (students, plans) = try await (studentsTask, plansTask)
            
            // Map active plans to students
            var newActivePlans: [String: TMIPlan] = [:]
            for plan in plans {
                // Assuming a plan can have multiple students, map each student ID to this plan
                // If a student has multiple plans, the last one processed will be used (or we could sort by date)
                for student in plan.students {
                    if let studentId = student.id {
                        // Prefer more recently updated plans
                        if let existingPlan = newActivePlans[studentId] {
                            if plan.lastUpdated > existingPlan.lastUpdated {
                                newActivePlans[studentId] = plan
                            }
                        } else {
                            newActivePlans[studentId] = plan
                        }
                    }
                }
            }
            self.activePlans = newActivePlans
            
            updateState(.loaded(students))
        } catch is CancellationError {
            return
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to load students"
            )
            updateState(.error(identifiableError))
        }
    }
    
    @MainActor
    func addStudent(_ student: Student) async -> Bool {
        do {
            _ = try await studentService.addStudent(student)
            // Always refresh the list after adding a student to avoid duplicates
            await fetch()
            return true
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error,
                userFriendlyMessage: "Failed to add student"
            )
            updateState(.error(identifiableError))
            return false
        }
    }
    
    @MainActor
    func updateStudent(_ student: Student) async -> Bool {
        do {
            let updatedStudent = try await studentService.updateStudent(student)
            
            // Update the current state
            if case .loaded(var students) = state {
                if let index = students.firstIndex(where: { $0.id == updatedStudent.id }) {
                    students[index] = updatedStudent
                    updateState(.loaded(students))
                }
            }
            
            return true
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to update student"
            )
            updateState(.error(identifiableError))
            return false
        }
    }
    
    @MainActor
    func deleteStudent(_ student: Student) async -> Bool {
        do {
            try await studentService.deleteStudent(student)
            
            // Update the current state to remove the student
            if case .loaded(var students) = state {
                students.removeAll { $0.id == student.id }
                updateState(.loaded(students))
            }
            
            return true
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(
                error, 
                userFriendlyMessage: "Failed to delete student"
            )
            updateState(.error(identifiableError))
            return false
        }
    }
    
    // MARK: - Computed Properties
    
    var students: [Student] {
        if case .loaded(let students) = state {
            return students
        }
        return []
    }
    
    var filteredStudents: [Student] {
        students.filter { student in
            (searchText.isEmpty || student.name.localizedCaseInsensitiveContains(searchText))
                && (selectedFilterOption == .all || matchesFilter(student: student, filter: selectedFilterOption))
        }
    }
    
    private func matchesFilter(student: Student, filter: FilterOption) -> Bool {
        switch filter {
        case .all:
            return true
        case .active:
            return student.tmiPlans?.isEmpty == false
        case .inactive:
            return student.tmiPlans?.isEmpty ?? true
        case .highEngagement:
            return student.engagementScore >= 0.7
        case .lowEngagement:
            return student.engagementScore < 0.3
        }
    }
    
    // MARK: - UI Helpers
    
    func showAddStudent() {
        showingAddStudent = true
    }
    
    func hideAddStudent() {
        showingAddStudent = false
    }
    
    func selectStudent(_ student: Student) {
        selectedStudent = student
    }
    
    func clearSelectedStudent() {
        selectedStudent = nil
    }
}
