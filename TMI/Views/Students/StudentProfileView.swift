// StudentProfileView.swift
// TMI
//
// Unified create/edit view for student profiles using accordion sections.
// Pass `existingStudent: nil` to create a new student, or a Student to edit.

import SwiftUI
import FirebaseAuth

struct StudentProfileView: View {
    // MARK: - Parameters

    var existingStudent: Student?
    let onComplete: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.authStateModel) private var authStateModel

    // MARK: - Section Expansion State

    @State private var infoExpanded = true
    @State private var guardianExpanded = false
    @State private var interestsExpanded = false
    @State private var careersExpanded = false
    @State private var resourcesExpanded = false
    @State private var notesExpanded = false

    // MARK: - Student Information Fields

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedGrade = "9"
    @State private var school = ""
    @State private var dateOfBirth = Date()
    @State private var studentID = ""

    // MARK: - Guardian Information Fields

    @State private var guardianName = ""
    @State private var relationship = "Parent"
    @State private var guardianPhone = ""
    @State private var guardianEmail = ""
    @State private var emergencyContact = ""
    @State private var emergencyPhone = ""

    // MARK: - Section Data

    @State private var selectedInterests: [Interest] = []
    @State private var selectedCareers: [Career] = []
    @State private var selectedResources: [Resource] = []

    // MARK: - Notes

    @State private var behavioralNotes = ""

    // MARK: - Save State

    @State private var isSaving = false
    @State private var errorMessage: String?

    // MARK: - Constants

    private let studentService = StudentService()
    private let grades = Array(1...12).map { String($0) } + ["Pre-K", "K"]
    private let relationshipOptions = ["Parent", "Legal Guardian", "Foster Parent", "Relative", "Other"]

    // MARK: - Computed Properties

    private var isEditMode: Bool { existingStudent != nil }

    private var navigationTitle: String {
        isEditMode ? "Edit Student" : "New Student"
    }

    private var saveButtonTitle: String {
        isEditMode ? "Save" : "Create"
    }

    private var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Badge Helpers

    private var guardianBadge: String? {
        guardianName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Added"
    }

    private var interestsBadge: String? {
        selectedInterests.isEmpty ? nil : "\(selectedInterests.count) added"
    }

    private var careersBadge: String? {
        selectedCareers.isEmpty ? nil : "\(selectedCareers.count) added"
    }

    private var resourcesBadge: String? {
        selectedResources.isEmpty ? nil : "\(selectedResources.count) added"
    }

    private var notesBadge: String? {
        behavioralNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Added"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    headerView

                    // Student Information — required, expanded by default
                    AccordionSection(
                        icon: "person.fill",
                        title: "Student Information",
                        isRequired: true,
                        isExpanded: $infoExpanded
                    ) {
                        studentInformationContent
                    }
                    .tmiCard()

                    // Guardian Information
                    AccordionSection(
                        icon: "person.2.fill",
                        title: "Guardian Information",
                        badge: guardianBadge,
                        badgeColor: .tmiPrimary,
                        isExpanded: $guardianExpanded
                    ) {
                        guardianInformationContent
                    }
                    .tmiCard()

                    // Interests & Hobbies
                    AccordionSection(
                        icon: "star.fill",
                        title: "Interests & Hobbies",
                        badge: interestsBadge,
                        badgeColor: .pink,
                        isExpanded: $interestsExpanded
                    ) {
                        StudentInterestsSection(selectedInterests: $selectedInterests)
                    }
                    .tmiCard()

                    // Career Exploration
                    AccordionSection(
                        icon: "briefcase.fill",
                        title: "Career Exploration",
                        badge: careersBadge,
                        badgeColor: .tmiSuccess,
                        isExpanded: $careersExpanded
                    ) {
                        StudentCareersSection(
                            selectedCareers: $selectedCareers,
                            studentInterests: selectedInterests
                        )
                    }
                    .tmiCard()

                    // Resources
                    AccordionSection(
                        icon: "books.vertical.fill",
                        title: "Resources",
                        badge: resourcesBadge,
                        badgeColor: .tmiWarning,
                        isExpanded: $resourcesExpanded
                    ) {
                        StudentResourcesSection(selectedResources: $selectedResources)
                    }
                    .tmiCard()

                    // Notes & Additional Info
                    AccordionSection(
                        icon: "note.text",
                        title: "Notes & Additional Info",
                        badge: notesBadge,
                        badgeColor: .tmiTextSecondary,
                        isExpanded: $notesExpanded
                    ) {
                        notesContent
                    }
                    .tmiCard()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.tmiCaption)
                            .foregroundStyle(Color.tmiError)
                            .padding(TMISpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.tmiError.opacity(0.1))
                            .cornerRadius(TMIRadius.sm)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, TMISpacing.screenPadding)
            }

            // Floating bottom action bar
            VStack {
                Spacer()
                bottomActionBar
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.tmiPrimary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveButtonTitle) { saveStudent() }
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? Color.tmiPrimary : Color.tmiTextSecondary)
                    .disabled(!isValid || isSaving)
            }
        }
        .onAppear {
            populateFromExistingStudent()
            prefillSchoolIfNeeded()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: TMISpacing.md) {
            Text(isEditMode ? "Edit Student Profile" : "New Student Intake")
                .font(.tmiTitle1)
                .foregroundStyle(Color.tmiTextPrimary)

            Text(isEditMode
                 ? "Update \(existingStudent?.name ?? "student") information"
                 : "Complete student profile for comprehensive support")
                .font(.tmiBody)
                .foregroundStyle(Color.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, TMISpacing.lg)
    }

    // MARK: - Student Information Section Content

    private var studentInformationContent: some View {
        VStack(spacing: TMISpacing.md) {
            // First / Last Name row
            HStack(spacing: TMISpacing.md) {
                labeledField(label: "First Name *", placeholder: "First") {
                    TextField("", text: $firstName,
                              prompt: Text("First").foregroundStyle(Color.tmiTextSecondary))
                        .textInputAutocapitalization(.words)
                }

                labeledField(label: "Last Name *", placeholder: "Last") {
                    TextField("", text: $lastName,
                              prompt: Text("Last").foregroundStyle(Color.tmiTextSecondary))
                        .textInputAutocapitalization(.words)
                }
            }

            // Grade Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Grade Level *")
                    .font(.tmiCaption)
                    .foregroundStyle(Color.tmiTextSecondary)

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
            labeledField(label: "School *", placeholder: "School name") {
                TextField("", text: $school,
                          prompt: Text("School name").foregroundStyle(Color.tmiTextSecondary))
                    .textInputAutocapitalization(.words)
            }

            // Date of Birth
            VStack(alignment: .leading, spacing: 8) {
                Text("Date of Birth")
                    .font(.tmiCaption)
                    .foregroundStyle(Color.tmiTextSecondary)

                DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(.tmiPrimary)
                    .padding(TMISpacing.sm)
                    .background(Color.tmiSurface)
                    .cornerRadius(TMIRadius.sm)
            }

            // Student ID
            labeledField(label: "Student ID", placeholder: "School-issued ID (optional)") {
                TextField("", text: $studentID,
                          prompt: Text("School-issued ID (optional)").foregroundStyle(Color.tmiTextSecondary))
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: - Guardian Information Section Content

    private var guardianInformationContent: some View {
        VStack(spacing: TMISpacing.md) {
            labeledField(label: "Guardian / Parent Name", placeholder: "Full name") {
                TextField("", text: $guardianName,
                          prompt: Text("Full name").foregroundStyle(Color.tmiTextSecondary))
                    .textInputAutocapitalization(.words)
            }

            // Relationship Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Relationship")
                    .font(.tmiCaption)
                    .foregroundStyle(Color.tmiTextSecondary)

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

            HStack(spacing: TMISpacing.md) {
                labeledField(label: "Phone", placeholder: "(555) 123-4567") {
                    TextField("", text: $guardianPhone,
                              prompt: Text("(555) 123-4567").foregroundStyle(Color.tmiTextSecondary))
                        .keyboardType(.phonePad)
                }

                labeledField(label: "Email", placeholder: "email@example.com") {
                    TextField("", text: $guardianEmail,
                              prompt: Text("email@example.com").foregroundStyle(Color.tmiTextSecondary))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            labeledField(label: "Emergency Contact (if different)", placeholder: "Name") {
                TextField("", text: $emergencyContact,
                          prompt: Text("Name").foregroundStyle(Color.tmiTextSecondary))
                    .textInputAutocapitalization(.words)
            }

            if !emergencyContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                labeledField(label: "Emergency Phone", placeholder: "(555) 123-4567") {
                    TextField("", text: $emergencyPhone,
                              prompt: Text("(555) 123-4567").foregroundStyle(Color.tmiTextSecondary))
                        .keyboardType(.phonePad)
                }
            }
        }
    }

    // MARK: - Notes Section Content

    private var notesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Behavioral Notes or Support Needs")
                .font(.tmiCaption)
                .foregroundStyle(Color.tmiTextSecondary)

            TextEditor(text: $behavioralNotes)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .font(.tmiBody)
                .foregroundStyle(Color.tmiTextPrimary)
                .padding(TMISpacing.sm)
                .background(Color.tmiSurface)
                .cornerRadius(TMIRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: TMIRadius.sm)
                        .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if behavioralNotes.isEmpty {
                        Text("Add notes about the student's needs, behaviors, or other relevant context…")
                            .font(.tmiBody)
                            .foregroundStyle(Color.tmiTextSecondary)
                            .padding(.top, TMISpacing.sm + 4)
                            .padding(.leading, TMISpacing.sm + 4)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: TMISpacing.md) {
            TMIButton(
                text: "Cancel",
                style: .secondary,
                action: { dismiss() }
            )

            TMIButton(
                text: isSaving ? "Saving…" : saveButtonTitle,
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

    // MARK: - Reusable Labeled Field Builder

    @ViewBuilder
    private func labeledField<F: View>(label: String, placeholder: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.tmiCaption)
                .foregroundStyle(Color.tmiTextSecondary)

            field()
                .font(.tmiBody)
                .foregroundStyle(Color.tmiTextPrimary)
                .padding(TMISpacing.md)
                .background(Color.tmiSurface)
                .cornerRadius(TMIRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: TMIRadius.sm)
                        .stroke(Color.tmiTextSecondary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Populate from Existing Student

    private func populateFromExistingStudent() {
        guard let student = existingStudent else { return }

        let nameParts = student.name.components(separatedBy: " ")
        firstName = nameParts.first ?? ""
        lastName = nameParts.dropFirst().joined(separator: " ")
        selectedGrade = student.grade
        school = student.school
        dateOfBirth = student.dateOfBirth
        studentID = student.studentID ?? ""

        // Restore behavioral notes from the most recent general note
        if let firstNote = student.notes?.first(where: { $0.category == .general }) {
            behavioralNotes = firstNote.content
        }
    }

    // MARK: - School Prefill

    private func prefillSchoolIfNeeded() {
        guard !isEditMode, school.isEmpty else { return }
        if let institutionName = authStateModel.currentUser?.institutionName {
            school = institutionName
        }
    }

    // MARK: - Save

    private func saveStudent() {
        guard isValid else { return }

        Task {
            await MainActor.run { isSaving = true; errorMessage = nil }

            do {
                if isEditMode {
                    try await performUpdate()
                } else {
                    try await performCreate()
                }
                await MainActor.run {
                    isSaving = false
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save student: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }

    private func performCreate() async throws {
        let student = Student(
            name: fullName,
            grade: selectedGrade,
            school: school.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            studentID: studentID.isEmpty ? nil : studentID
        )
        let saved = try await studentService.addStudent(student)

        // Associate selected interests with the new student
        if let studentId = saved.id {
            for interest in selectedInterests {
                if let interestId = interest.id {
                    try? await StudentInterestService.shared.addInterest(
                        studentId: studentId,
                        interestId: interestId,
                        level: 3,
                        source: .staff
                    )
                }
            }
        }
    }

    private func performUpdate() async throws {
        guard let existing = existingStudent else { return }

        // Build updated notes array — prepend new note if behavioral notes changed
        var updatedNotes = existing.notes ?? []
        let trimmedNotes = behavioralNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            let authorName = Auth.auth().currentUser?.displayName
                ?? Auth.auth().currentUser?.email
                ?? "Educator"
            let newNote = StudentNote(
                date: Date(),
                author: authorName,
                content: trimmedNotes,
                category: .general
            )
            // Only add if content differs from existing most-recent general note
            let existingNoteContent = updatedNotes.first(where: { $0.category == .general })?.content
            if existingNoteContent != trimmedNotes {
                updatedNotes.insert(newNote, at: 0)
            }
        }

        let updatedStudent = Student(
            id: existing.id,
            name: fullName,
            grade: selectedGrade,
            school: school.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            districtId: existing.districtId,
            schoolId: existing.schoolId,
            assignedCounselorId: existing.assignedCounselorId,
            primaryTeacherId: existing.primaryTeacherId,
            createdBy: existing.createdBy,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            tmiPlans: existing.tmiPlans,
            studentID: studentID.isEmpty ? nil : studentID,
            photoURL: existing.photoURL,
            surveyResults: existing.surveyResults,
            academicPerformance: existing.academicPerformance,
            engagementHistory: existing.engagementHistory,
            notes: updatedNotes.isEmpty ? nil : updatedNotes,
            lastInteractionDate: Date()
        )

        _ = try await studentService.updateStudent(updatedStudent)

        // Sync interest associations
        if let studentId = existing.id {
            for interest in selectedInterests {
                if let interestId = interest.id {
                    try? await StudentInterestService.shared.addInterest(
                        studentId: studentId,
                        interestId: interestId,
                        level: 3,
                        source: .staff
                    )
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Create Mode") {
    NavigationStack {
        StudentProfileView(onComplete: {})
    }
}

#Preview("Edit Mode") {
    let sample = Student(
        id: "preview-id",
        name: "Alex Johnson",
        grade: "10",
        school: "Lincoln High",
        dateOfBirth: Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
    )
    return NavigationStack {
        StudentProfileView(existingStudent: sample, onComplete: {})
    }
}
