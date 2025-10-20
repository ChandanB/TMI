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
    var school = ""
    var dateOfBirth = Date()
    var interests: [Interest] = []
    // Note: Hobbies are now included in interests
    
    // UI state
    var isLoading = false
    var showingAlert = false
    var alertMessage = ""
    var errorMessage: String?
    var showingInterestPicker = false
    // Note: Hobby picker removed - now using unified interest picker
    
    // Edit state
    private var student: Student?
    var isEditing: Bool { student != nil }
    
    // Validation state
    var nameError: String?
    var gradeError: String?
    var schoolError: String?
    
    // Dependencies
    private let studentService: StudentService
    
    init(student: Student? = nil, studentService: StudentService = StudentService(), currentSchool: String? = nil) {
        self.student = student
        self.studentService = studentService
        if let student = student {
            self.name = student.name
            self.grade = student.grade
            self.studentID = student.studentID ?? ""
            self.school = student.school
            self.dateOfBirth = student.dateOfBirth
            self.interests = student.interests
            // Note: Hobbies are now included in interests
        } else if let currentSchool = currentSchool {
            self.school = currentSchool
        }
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
        
        let studentToSave = Student(
            id: student?.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            grade: grade.trimmingCharacters(in: .whitespacesAndNewlines),
            school: school.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            studentID: studentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : studentID.trimmingCharacters(in: .whitespacesAndNewlines),
            interests: interests,
            // Note: Hobbies are now included in interests
        )
        
        do {
            let savedStudent: Student
            if isEditing {
                print("[DEBUG] Updating student: \(studentToSave.name)")
                savedStudent = try await studentService.updateStudent(studentToSave)
                print("[DEBUG] Student updated successfully: \(savedStudent.name)")
            } else {
                print("[DEBUG] Adding student: \(studentToSave.name)")
                savedStudent = try await studentService.addStudent(studentToSave)
                print("[DEBUG] Student added successfully: \(savedStudent.name)")
            }
            isLoading = false
            print("[DEBUG] Save operation completed successfully")
            return savedStudent
        } catch {
            isLoading = false
            print("[DEBUG] Save failed with error: \(error)")
            print("[DEBUG] Error type: \(type(of: error))")
            print("[DEBUG] Error localized description: \(error.localizedDescription)")
            errorMessage = "Failed to save student: \(error.localizedDescription)"
            showingAlert = true
            return nil
        }
    }
    
    // MARK: - UI Helpers
    
    func showInterestPicker() {
        showingInterestPicker = true
    }
    
    func hideInterestPicker() {
        showingInterestPicker = false
    }
    
    // Note: showHobbyPicker removed - now using showInterestPicker
    
    // Note: hideHobbyPicker removed - now using hideInterestPicker
    
    func addInterest(_ interest: Interest) {
        if !interests.contains(interest) {
            interests.append(interest)
        }
    }
    
    func removeInterest(_ interest: Interest) {
        interests.removeAll { $0.id == interest.id }
    }
    
    // Note: Hobby functionality has been merged into interests
    
    // MARK: - Computed Properties
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var selectedInterestCount: Int {
        interests.count
    }
    
    // Note: Hobby count is now included in selectedInterestCount
}