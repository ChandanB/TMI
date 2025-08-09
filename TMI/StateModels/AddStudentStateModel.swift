//
//  AddStudentStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI
import Observation

@Observable
final class AddStudentStateModel {
    
    // Form state
    var name = ""
    var grade = ""
    var studentID = ""
    var dateOfBirth = Date()
    var interests: [Interest] = []
    var hobbies: [Hobby] = []
    
    // UI state
    var isLoading = false
    var showingAlert = false
    var alertMessage = ""
    var errorMessage: String?
    var showingInterestPicker = false
    var showingHobbyPicker = false
    
    // Validation state
    var nameError: String?
    var gradeError: String?
    
    // Dependencies
    private let studentService: StudentService
    
    init(studentService: StudentService = StudentService()) {
        self.studentService = studentService
    }
    
    // MARK: - Validation
    
    func validateForm() -> Bool {
        var isValid = true
        
        // Reset errors
        nameError = nil
        gradeError = nil
        
        // Validate name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = "Name is required"
            isValid = false
        }
        
        // Validate grade
        if grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            gradeError = "Grade is required"
            isValid = false
        }
        
        return isValid
    }
    
    // MARK: - Actions
    
    @MainActor
    func saveStudent() async -> Student? {
        guard validateForm() else {
            errorMessage = "Please fix the errors above"
            showingAlert = true
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        let student = Student(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            grade: grade.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            studentID: studentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : studentID.trimmingCharacters(in: .whitespacesAndNewlines),
            interests: interests,
            hobbies: hobbies
        )
        
        do {
            let savedStudent = try await studentService.addStudent(student)
            isLoading = false
            return savedStudent
        } catch {
            isLoading = false
            errorMessage = "Failed to save student: \(error.localizedDescription)"
            showingAlert = true
            return nil
        }
    }
    
    @MainActor
    func addStudent(onSuccess: @escaping (Student) -> Void) async {
        if let savedStudent = await saveStudent() {
            onSuccess(savedStudent)
        }
    }
    
    // MARK: - UI Helpers
    
    func showInterestPicker() {
        showingInterestPicker = true
    }
    
    func hideInterestPicker() {
        showingInterestPicker = false
    }
    
    func showHobbyPicker() {
        showingHobbyPicker = true
    }
    
    func hideHobbyPicker() {
        showingHobbyPicker = false
    }
    
    func addInterest(_ interest: Interest) {
        if !interests.contains(interest) {
            interests.append(interest)
        }
    }
    
    func removeInterest(_ interest: Interest) {
        interests.removeAll { $0.id == interest.id }
    }
    
    func addHobby(_ hobby: Hobby) {
        if !hobbies.contains(hobby) {
            hobbies.append(hobby)
        }
    }
    
    func removeHobby(_ hobby: Hobby) {
        hobbies.removeAll { $0.id == hobby.id }
    }
    
    // MARK: - Computed Properties
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var selectedInterestCount: Int {
        interests.count
    }
    
    var selectedHobbyCount: Int {
        hobbies.count
    }
}