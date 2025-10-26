//
//  AddStudentView.swift
//  TMI
//
//  Simplified 3-field student creation flow
//

import SwiftUI

struct AddStudentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authStateModel) private var authStateModel
    let onComplete: () -> Void

    // Required fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedGrade = "9"
    @State private var school = ""
    @State private var isEditingSchool = false

    // Student Information
    @State private var dateOfBirth = Date()
    @State private var studentID = ""

    // Guardian Information
    @State private var guardianName = ""
    @State private var guardianPhone = ""
    @State private var guardianEmail = ""
    @State private var relationship = "Parent"

    // Additional Information
    @State private var behavioralNotes = ""
    @State private var emergencyContact = ""
    @State private var emergencyPhone = ""

    // Workflow options
    @State private var launchSurveyImmediately = true

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var currentStep = 1
    @State private var showingSurvey = false
    @State private var createdStudentId: String?

    private let studentService = StudentService()

    let grades = Array(1...12).map { String($0) } + ["Pre-K", "K"]

    var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let relationshipOptions = ["Parent", "Legal Guardian", "Foster Parent", "Relative", "Other"]

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    // Header with progress indicator
                    VStack(spacing: TMISpacing.md) {
                        Text("New Student Intake")
                            .font(.tmiTitle1)
                            .foregroundColor(.tmiTextPrimary)

                        Text("Complete student profile for comprehensive support")
                            .font(.tmiBody)
                            .foregroundColor(.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, TMISpacing.lg)

                    // Student Information Section
                    VStack(alignment: .leading, spacing: TMISpacing.md) {
                        sectionHeader(title: "Student Information", icon: "person.fill")

                        VStack(spacing: TMISpacing.md) {
                            // First and Last Name
                            HStack(spacing: TMISpacing.md) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name *")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)

                                    TextField("", text: $firstName, prompt: Text("First").foregroundColor(.tmiTextTertiary))
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)
                                        .padding(TMISpacing.md)
                                        .background(Color.tmiSurface)
                                        .cornerRadius(TMIRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                                .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.words)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name *")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)

                                    TextField("", text: $lastName, prompt: Text("Last").foregroundColor(.tmiTextTertiary))
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)
                                        .padding(TMISpacing.md)
                                        .background(Color.tmiSurface)
                                        .cornerRadius(TMIRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                                .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.words)
                                }
                            }

                            // Student ID
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Student ID")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                TextField("", text: $studentID, prompt: Text("School-issued ID (optional)").foregroundColor(.tmiTextTertiary))
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)
                                    .padding(TMISpacing.md)
                                    .background(Color.tmiSurface)
                                    .cornerRadius(TMIRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: TMIRadius.sm)
                                            .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            // Date of Birth
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                DatePicker(
                                    "",
                                    selection: $dateOfBirth,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(.tmiPrimary)
                                .padding(TMISpacing.sm)
                                .background(Color.tmiSurface)
                                .cornerRadius(TMIRadius.sm)
                            }
                        }
                        .tmiCard()
                    }

                    // Academic Information Section
                    VStack(alignment: .leading, spacing: TMISpacing.md) {
                        sectionHeader(title: "Academic Information", icon: "graduationcap.fill")

                        VStack(spacing: TMISpacing.md) {
                            // Grade
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Grade Level *")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                Picker("Grade", selection: $selectedGrade) {
                                    ForEach(grades, id: \.self) { grade in
                                        Text("Grade \(grade)").tag(grade)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.tmiPrimary)
                                .padding(TMISpacing.md)
                                .background(Color.tmiSurface)
                                .cornerRadius(TMIRadius.sm)
                            }

                            // School
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("School *")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)

                                    Spacer()

                                    if !school.isEmpty && !isEditingSchool {
                                        Button {
                                            isEditingSchool = true
                                        } label: {
                                            Text("Edit")
                                                .font(.tmiCaption)
                                                .foregroundColor(.tmiPrimary)
                                        }
                                    }
                                }

                                if isEditingSchool {
                                    TextField("", text: $school, prompt: Text("Enter school name").foregroundColor(.tmiTextTertiary))
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)
                                        .padding(TMISpacing.md)
                                        .background(Color.tmiSurface)
                                        .cornerRadius(TMIRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                                .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.words)
                                } else {
                                    HStack {
                                        Text(school.isEmpty ? "Enter school name" : school)
                                            .font(.tmiBody)
                                            .foregroundColor(school.isEmpty ? .tmiTextTertiary : .tmiTextPrimary)

                                        Spacer()

                                        if !school.isEmpty {
                                            Image(systemName: "building.2.fill")
                                                .foregroundColor(.tmiTextTertiary)
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .padding(TMISpacing.md)
                                    .background(Color.tmiSurface.opacity(0.5))
                                    .cornerRadius(TMIRadius.sm)
                                    .onTapGesture {
                                        if school.isEmpty {
                                            isEditingSchool = true
                                        }
                                    }
                                }
                            }
                        }
                        .tmiCard()
                    }

                    // Guardian/Contact Information Section
                    VStack(alignment: .leading, spacing: TMISpacing.md) {
                        sectionHeader(title: "Guardian & Contact Information", icon: "person.2.fill")

                        VStack(spacing: TMISpacing.md) {
                            // Guardian Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Guardian/Parent Name")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                TextField("", text: $guardianName, prompt: Text("Full name").foregroundColor(.tmiTextTertiary))
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)
                                    .padding(TMISpacing.md)
                                    .background(Color.tmiSurface)
                                    .cornerRadius(TMIRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: TMIRadius.sm)
                                            .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .textInputAutocapitalization(.words)
                            }

                            // Relationship
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Relationship")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                Picker("Relationship", selection: $relationship) {
                                    ForEach(relationshipOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.tmiPrimary)
                                .padding(TMISpacing.md)
                                .background(Color.tmiSurface)
                                .cornerRadius(TMIRadius.sm)
                            }

                            // Contact Information
                            HStack(spacing: TMISpacing.md) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Phone")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)

                                    TextField("", text: $guardianPhone, prompt: Text("(555) 123-4567").foregroundColor(.tmiTextTertiary))
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)
                                        .padding(TMISpacing.md)
                                        .background(Color.tmiSurface)
                                        .cornerRadius(TMIRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                                .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .keyboardType(.phonePad)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)

                                    TextField("", text: $guardianEmail, prompt: Text("email@example.com").foregroundColor(.tmiTextTertiary))
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)
                                        .padding(TMISpacing.md)
                                        .background(Color.tmiSurface)
                                        .cornerRadius(TMIRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                                .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                }
                            }

                            // Emergency Contact
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Emergency Contact (if different)")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                TextField("", text: $emergencyContact, prompt: Text("Name").foregroundColor(.tmiTextTertiary))
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)
                                    .padding(TMISpacing.md)
                                    .background(Color.tmiSurface)
                                    .cornerRadius(TMIRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: TMIRadius.sm)
                                            .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .textInputAutocapitalization(.words)
                            }

                            if !emergencyContact.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Emergency Phone")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)

                                    TextField("", text: $emergencyPhone, prompt: Text("(555) 123-4567").foregroundColor(.tmiTextTertiary))
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)
                                        .padding(TMISpacing.md)
                                        .background(Color.tmiSurface)
                                        .cornerRadius(TMIRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: TMIRadius.sm)
                                                .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .keyboardType(.phonePad)
                                }
                            }
                        }
                        .tmiCard()
                    }

                    // Notes & Next Steps Section
                    VStack(alignment: .leading, spacing: TMISpacing.md) {
                        sectionHeader(title: "Additional Notes & Next Steps", icon: "note.text")

                        VStack(spacing: TMISpacing.md) {
                            // Behavioral/Support Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Behavioral Notes or Support Needs")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                TextEditor(text: $behavioralNotes)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)
                                    .padding(TMISpacing.sm)
                                    .background(Color.tmiSurface)
                                    .cornerRadius(TMIRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: TMIRadius.sm)
                                            .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            // Workflow option
                            Toggle(isOn: $launchSurveyImmediately) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Complete Interest Survey Now")
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)

                                    Text("Launch in-app survey to identify student interests and hobbies")
                                        .font(.tmiFootnote)
                                        .foregroundColor(.tmiTextSecondary)
                                }
                            }
                            .tint(.tmiPrimary)
                            .padding(TMISpacing.md)
                            .background(Color.tmiSurface)
                            .cornerRadius(TMIRadius.sm)
                        }
                        .tmiCard()
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.tmiCaption)
                            .foregroundColor(.tmiError)
                            .padding(TMISpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.tmiError.opacity(0.1))
                            .cornerRadius(TMIRadius.sm)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }

            // Bottom Action Bar
            VStack {
                Spacer()

                HStack(spacing: TMISpacing.md) {
                    TMIButton(
                        text: "Cancel",
                        style: .secondary,
                        action: { dismiss() }
                    )

                    TMIButton(
                        text: launchSurveyImmediately ? "Save & Launch Survey" : "Save Student",
                        style: .primary,
                        isLoading: isSaving,
                        isDisabled: !isValid,
                        action: saveStudent
                    )
                }
                .padding(TMISpacing.md)
                .background(
                    Color.tmiBackground
                        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.tmiPrimary)
            }
        }
        .sheet(isPresented: $showingSurvey) {
            if let studentId = createdStudentId {
                NavigationStack {
                    StudentSurveyFlow(studentId: studentId)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Skip") {
                                    showingSurvey = false
                                    onComplete()
                                }
                                .foregroundColor(.tmiPrimary)
                            }
                        }
                }
                .onDisappear {
                    // When survey is dismissed (completed or skipped), call onComplete
                    if !showingSurvey {
                        onComplete()
                    }
                }
            }
        }
        .onAppear {
            // Auto-populate school from current user's institution
            if school.isEmpty, let institutionName = authStateModel.currentUser?.institutionName {
                school = institutionName
                isEditingSchool = false
            } else if school.isEmpty {
                // If no institution is set, allow manual entry
                isEditingSchool = true
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: TMISpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.tmiPrimary)

            Text(title)
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Spacer()
        }
    }

    // MARK: - Save Student

    private func saveStudent() {
        guard isValid else { return }

        Task {
            isSaving = true
            errorMessage = nil

            do {
                let student = Student(
                    name: fullName,
                    grade: selectedGrade,
                    school: school.trimmingCharacters(in: .whitespacesAndNewlines),
                    dateOfBirth: dateOfBirth,
                    studentID: studentID.isEmpty ? nil : studentID
                )

                let savedStudent = try await studentService.addStudent(student)

                await MainActor.run {
                    if launchSurveyImmediately, let studentId = savedStudent.id {
                        // Store student ID and show survey
                        createdStudentId = studentId
                        showingSurvey = true
                    } else {
                        // Complete without survey
                        onComplete()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save student: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddStudentView(onComplete: {})
    }
}
