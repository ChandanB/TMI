//
//  EditStudentView.swift
//  TMI
//
//  Edit existing student information including academic performance and notes
//

import SwiftUI

struct EditStudentView: View {
    let student: Student
    let onSave: (Student) -> Void

    @Environment(\.dismiss) private var dismiss

    // Basic Info
    @State private var firstName: String
    @State private var lastName: String
    @State private var selectedGrade: String
    @State private var school: String
    @State private var dateOfBirth: Date
    @State private var studentID: String

    // Academic Performance
    @State private var gpa: String
    @State private var subjects: [SubjectPerformance]
    @State private var academicStrengths: String
    @State private var areasForImprovement: String

    // Notes
    @State private var noteContent: String
    @State private var noteCategory: StudentNote.NoteCategory = .general

    // Engagement Status
    @State private var engagementStatus: EngagementStatus = .growing

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingAddSubject = false
    @State private var newSubjectName = ""
    @State private var newSubjectGrade = "A"

    enum EngagementStatus: String, CaseIterable, Identifiable {
        case engaged = "Engaged"
        case growing = "Growing"
        case needsSupport = "Needs Support"

        var id: String { rawValue }

        var score: Double {
            switch self {
            case .engaged: return 0.85
            case .growing: return 0.55
            case .needsSupport: return 0.25
            }
        }

        var color: Color {
            switch self {
            case .engaged: return .tmiSuccess
            case .growing: return .tmiWarning
            case .needsSupport: return Color(hex: "#FB923C")
            }
        }

        var icon: String {
            switch self {
            case .engaged: return "checkmark.circle.fill"
            case .growing: return "chart.line.uptrend.xyaxis"
            case .needsSupport: return "heart.fill"
            }
        }
    }

    private let studentService = StudentService()
    let grades = Array(1...12).map { String($0) } + ["Pre-K", "K"]
    let letterGrades = ["A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D", "D-", "F"]

    init(student: Student, onSave: @escaping (Student) -> Void) {
        self.student = student
        self.onSave = onSave

        // Parse student name
        let nameParts = student.name.components(separatedBy: " ")
        _firstName = State(initialValue: nameParts.first ?? "")
        _lastName = State(initialValue: nameParts.dropFirst().joined(separator: " "))

        _selectedGrade = State(initialValue: student.grade)
        _school = State(initialValue: student.school)
        _dateOfBirth = State(initialValue: student.dateOfBirth)
        _studentID = State(initialValue: student.studentID ?? "")

        // Academic Performance
        _gpa = State(initialValue: String(format: "%.2f", student.academicPerformance?.gpa ?? 0.0))
        _subjects = State(initialValue: student.academicPerformance?.subjects ?? [])
        _academicStrengths = State(initialValue: student.academicPerformance?.strengths.joined(separator: ", ") ?? "")
        _areasForImprovement = State(initialValue: student.academicPerformance?.areasForImprovement.joined(separator: ", ") ?? "")

        // Notes - start with empty for adding NEW notes
        _noteContent = State(initialValue: "")

        // Engagement Status - determine from current engagement score
        let currentScore = student.engagementScore
        if currentScore >= 0.7 {
            _engagementStatus = State(initialValue: .engaged)
        } else if currentScore >= 0.4 {
            _engagementStatus = State(initialValue: .growing)
        } else {
            _engagementStatus = State(initialValue: .needsSupport)
        }
    }

    var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func statusDescription(for status: EngagementStatus) -> String {
        switch status {
        case .engaged:
            return "Actively participating and making progress"
        case .growing:
            return "Showing improvement and development"
        case .needsSupport:
            return "Could benefit from additional support"
        }
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 50))
                            .foregroundColor(.tmiPrimary)

                        Text("Edit Student")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Update \(student.name)'s information")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)

                    // Basic Information
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Basic Information")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name *")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    TextField("First Name", text: $firstName)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name *")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    TextField("Last Name", text: $lastName)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Grade *")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Picker("Grade", selection: $selectedGrade) {
                                    ForEach(grades, id: \.self) { grade in
                                        Text(grade).tag(grade)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.tmiPrimary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("School *")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                TextField("School Name", text: $school)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Student ID")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                TextField("Student ID", text: $studentID)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of Birth")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(.tmiPrimary)
                            }
                        }
                    }

                    // Engagement Status
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.tmiPrimary)
                                Text("Engagement Status")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            Text("Set the student's current engagement level")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            VStack(spacing: 12) {
                                ForEach(EngagementStatus.allCases) { status in
                                    Button(action: {
                                        engagementStatus = status
                                    }) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(status.color.opacity(0.2))
                                                    .frame(width: 40, height: 40)

                                                Image(systemName: status.icon)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(status.color)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(status.rawValue)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)

                                                Text(statusDescription(for: status))
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.6))
                                            }

                                            Spacer()

                                            if engagementStatus == status {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(status.color)
                                            } else {
                                                Circle()
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 22, height: 22)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(engagementStatus == status ? status.color.opacity(0.1) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(engagementStatus == status ? status.color.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Academic Performance
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Academic Performance")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()

                                if let gpaValue = Double(gpa), gpaValue > 0 {
                                    HStack(spacing: 4) {
                                        Text("GPA:")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        Text(String(format: "%.2f", gpaValue))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.tmiPrimary)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("GPA (0.0 - 4.0)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                TextField("3.5", text: $gpa)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Subject Grades
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Subject Grades")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))

                                    Spacer()

                                    Button(action: { showingAddSubject = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Subject")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.tmiPrimary)
                                    }
                                }

                                if subjects.isEmpty {
                                    Text("No subjects added yet")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.vertical, 8)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(Array(subjects.enumerated()), id: \.element.name) { index, subject in
                                            HStack {
                                                Text(subject.name)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)

                                                Spacer()

                                                Menu {
                                                    ForEach(letterGrades, id: \.self) { grade in
                                                        Button(grade) {
                                                            updateSubjectGrade(at: index, grade: grade)
                                                        }
                                                    }
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Text(subject.grade)
                                                            .font(.system(size: 15, weight: .semibold))
                                                            .foregroundColor(gradeColor(subject.grade))
                                                        Image(systemName: "chevron.down")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.white.opacity(0.5))
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(gradeColor(subject.grade).opacity(0.2))
                                                    )
                                                }

                                                Button(action: { deleteSubject(at: index) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red.opacity(0.7))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.white.opacity(0.05))
                                            )
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Academic Strengths (comma separated)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                TextField("e.g., Math, Science, Problem Solving", text: $academicStrengths)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Areas for Improvement (comma separated)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                TextField("e.g., Reading Comprehension, Focus", text: $areasForImprovement)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    // Notes & History
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add Note")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))

                                Picker("Category", selection: $noteCategory) {
                                    Text("General").tag(StudentNote.NoteCategory.general)
                                    Text("Academic").tag(StudentNote.NoteCategory.academic)
                                    Text("Behavioral").tag(StudentNote.NoteCategory.behavioral)
                                    Text("TMI Plan").tag(StudentNote.NoteCategory.tmiPlan)
                                }
                                .pickerStyle(.segmented)
                                .tint(.tmiPrimary)
                            }

                            TextEditor(text: $noteContent)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .font(.system(size: 15))
                                .cornerRadius(8)
                                .overlay(
                                    noteContent.isEmpty ?
                                    VStack {
                                        HStack {
                                            Text("Add notes about the student's progress, behavior, or other important information...")
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.system(size: 15))
                                                .allowsHitTesting(false)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    : nil
                                )
                        }
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }

            // Save button
            VStack {
                Spacer()

                TMIButton(
                    text: isSaving ? "Saving..." : "Save Changes",
                    icon: "checkmark",
                    style: .primary,
                    action: saveStudent
                )
                .disabled(isSaving || !isValid)
                .padding(20)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
                )
            }
        }
        .navigationTitle("Edit Student")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Add Subject", isPresented: $showingAddSubject) {
            TextField("Subject Name", text: $newSubjectName)
            Button("Cancel", role: .cancel) {
                newSubjectName = ""
                newSubjectGrade = "A"
            }
            Button("Add") {
                addSubject()
            }
        } message: {
            Text("Enter the subject name and grade")
        }
    }

    // MARK: - Helper Methods

    private func gradeColor(_ grade: String) -> Color {
        switch grade.prefix(1) {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        case "F": return .red
        default: return .gray
        }
    }

    private func updateSubjectGrade(at index: Int, grade: String) {
        guard index < subjects.count else { return }
        let score = gradeToScore(grade)
        subjects[index] = SubjectPerformance(
            name: subjects[index].name,
            grade: grade,
            score: score,
            interestAlignment: subjects[index].interestAlignment
        )
    }

    private func deleteSubject(at index: Int) {
        guard index < subjects.count else { return }
        subjects.remove(at: index)
    }

    private func addSubject() {
        let trimmedName = newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newSubject = SubjectPerformance(
            name: trimmedName,
            grade: newSubjectGrade,
            score: gradeToScore(newSubjectGrade),
            interestAlignment: 0.0
        )

        subjects.append(newSubject)
        newSubjectName = ""
        newSubjectGrade = "A"
    }

    private func gradeToScore(_ grade: String) -> Double {
        switch grade {
        case "A+": return 4.0
        case "A": return 4.0
        case "A-": return 3.7
        case "B+": return 3.3
        case "B": return 3.0
        case "B-": return 2.7
        case "C+": return 2.3
        case "C": return 2.0
        case "C-": return 1.7
        case "D+": return 1.3
        case "D": return 1.0
        case "D-": return 0.7
        case "F": return 0.0
        default: return 0.0
        }
    }

    private func saveStudent() {
        guard isValid else { return }

        isSaving = true

        Task {
            do {
                // Parse academic data
                let gpaValue = Double(gpa) ?? 0.0

                let strengthsArray = academicStrengths
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let improvementArray = areasForImprovement
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let academicPerformance = AcademicPerformance(
                    gpa: gpaValue,
                    subjects: subjects,
                    strengths: strengthsArray,
                    areasForImprovement: improvementArray
                )

                // Create new note if content is provided
                var updatedNotes = student.notes ?? []
                let trimmedNoteContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedNoteContent.isEmpty {
                    let newNote = StudentNote(
                        date: Date(),
                        author: "Educator", // TODO: Get from current user
                        content: trimmedNoteContent,
                        category: noteCategory
                    )
                    updatedNotes.insert(newNote, at: 0) // Add to beginning
                }

                // Update engagement history with new status
                var updatedEngagementHistory = student.engagementHistory ?? []
                let newEngagementRecord = EngagementRecord(
                    date: Date(),
                    score: engagementStatus.score,
                    source: .teacherInput,
                    notes: "Status set to \(engagementStatus.rawValue)"
                )
                updatedEngagementHistory.insert(newEngagementRecord, at: 0)

                // Create updated student
                let updatedStudent = Student(
                    id: student.id,
                    name: fullName,
                    grade: selectedGrade,
                    school: school,
                    dateOfBirth: dateOfBirth,
                    interests: [], tmiPlans: student.tmiPlans,
                    studentID: studentID.isEmpty ? nil : studentID,  // Managed via StudentInterestService edge collection
                    photoURL: student.photoURL,
                    surveyResults: student.surveyResults,
                    academicPerformance: academicPerformance,
                    engagementHistory: updatedEngagementHistory,
                    notes: updatedNotes.isEmpty ? nil : updatedNotes,
                    lastInteractionDate: Date()
                )

                // Save to Firestore
                let savedStudent = try await studentService.updateStudent(updatedStudent)

                await MainActor.run {
                    onSave(savedStudent)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}
