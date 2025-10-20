//
//  StudentDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import SwiftUI

// Modern StudentDetailView using TMI design system
struct StudentDetailView: View {
    @State var student: Student
    @Environment(\.dismiss) private var dismiss
    @State private var stateModel: StudentDetailStateModel
    @State private var tabSelection = 0
    @State private var showingNewPlanSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditStudentSheet = false

    init(student: Student) {
        _student = State(initialValue: student)
        _stateModel = State(initialValue: StudentDetailStateModel(student: student))
    }

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader
                        
                        TMIButton(
                            text: "Create TMI Plan",
                            icon: "plus.square.on.square",
                            style: .primary,
                            action: { showingNewPlanSheet = true }
                        )
                        .padding(.top, 8)

                        StudentListTabPicker(selection: $tabSelection)
                            .padding(.horizontal, 20)
                        tabContent
                            .padding(.horizontal, 20)
                    }
                }
            .navigationTitle("Student Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Student") { showingEditStudentSheet = true }
                        Button("Add TMI Plan") { showingNewPlanSheet = true }
                        Divider()
                        Button("Delete Student", role: .destructive) { showingDeleteConfirmation = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewPlanSheet) {
            NewTMIPlanView(preselectedStudent: student) { newPlan in
                // Refresh the TMI plans after creation
                Task {
                    await stateModel.fetchTMIPlans()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingEditStudentSheet) {
            AddStudentView(student: student, onStudentAdded: {
                Task {
                    if let updatedStudent = try? await StudentService().getStudent(by: student.id ?? "") {
                        self.student = updatedStudent
                    }
                }
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Student?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteStudent()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this student? This action cannot be undone.")
        }
        .preferredColorScheme(.dark)
        .task {
            await stateModel.fetchTMIPlans()
        }
    }
    
    private func deleteStudent() async {
        do {
            try await StudentService().deleteStudent(student)
            dismiss()
        } catch {
            // Handle error
            print("Error deleting student: \(error)")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.2, blue: 0.3),
                                Color(red: 0.1, green: 0.1, blue: 0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Text(student.initials)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(student.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Grade \(student.grade) • ID: \(student.studentID ?? "N/A")")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HStack(spacing: 20) {
                statView(
                    title: "Engagement",
                    value: "\(Int(student.engagementScore * 100))%",
                    color: engagementColor)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 30)
                statView(
                    title: "TMI Plan",
                    value: stateModel.tmiPlans.isEmpty ? "None" : "Active",
                    color: stateModel.tmiPlans.isEmpty ? .orange : .green
                )
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 30)
                statView(
                    title: "Interests",
                    value: "\(student.interests.count)",
                    color: .blue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
        }
        .padding(20)
    }
    
    private func statView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch tabSelection {
        case 0:
            tmiPlansTab
        case 1:
            interestsTab
        case 2:
            surveysTab
        default:
            Text("Invalid tab")
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var tmiPlansTab: some View {
        switch stateModel.state {
        case .loading:
            ProgressView()
        case .loaded:
            if stateModel.tmiPlans.isEmpty {
                emptyStateView(
                    icon: "doc.text.fill",
                    title: "No TMI Plans",
                    message: "Create a TMI plan to start tracking the student's progress",
                    buttonTitle: "Create TMI Plan",
                    action: { showingNewPlanSheet = true }
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(stateModel.tmiPlans) { plan in
                        TMIPlanCard(plan: plan)
                    }
                }
            }
        case .error(let error):
            Text("Error: \(error.localizedDescription)")
                .foregroundColor(.red)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var interestsTab: some View {
        if student.interests.isEmpty {
            emptyStateView(
                icon: "heart.fill",
                title: "No Interests Recorded",
                message: "Record the student's interests and hobbies to improve TMI alignment",
                buttonTitle: "Add Interests",
                action: { showingEditStudentSheet = true }
            )
        } else {
            StudentInterestsAndHobbiesView(student: student)
        }
    }

    @ViewBuilder
    private var surveysTab: some View {
        NavigationLink(destination: FormSubmissionsView(studentId: student.id ?? "")) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.tmiSecondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Form Submissions")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("View all survey responses and form data")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func emptyStateView(
        icon: String, title: String, message: String, buttonTitle: String, action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.5))

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            TMIButton(
                text: buttonTitle,
                style: .secondary,
                action: action
            )
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private var engagementColor: Color {
        if student.engagementScore >= 0.7 {
            return .green
        } else if student.engagementScore >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

// Tab Picker
struct StudentListTabPicker: View {
    @Binding var selection: Int
    @Namespace private var tabAnimation

    private let tabs = ["TMI Plans", "Interests", "Surveys"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 10) {
                        Text(tabs[index])
                            .font(.system(size: 16, weight: selection == index ? .semibold : .regular))
                            .foregroundColor(selection == index ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)

                        if selection == index {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.tmiSecondary)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "ActiveTab", in: tabAnimation)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
    }
}

// MARK: - Student Interests and Hobbies View
struct StudentInterestsAndHobbiesView: View {
    let student: Student
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Interests Section
            if !student.interests.isEmpty {
                InterestHobbySection(
                    title: "Interests",
                    icon: "heart.fill",
                    color: .pink,
                    items: student.interests.map { InterestHobbyItem(name: $0.name, category: $0.category.first?.rawValue ?? "General") }
                )
            }
            
            // Note: Hobbies are now included in interests above
            // Removed separate hobbies section as hobbies are now part of interests
            
            // Edit button
            TMIButton(
                text: "Edit Interests & Hobbies",
                icon: "pencil",
                style: .secondary,
                action: { showingEditSheet = true }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            EditStudentInterestsView(student: student)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct InterestHobbySection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [InterestHobbyItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(items.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.2))
                    )
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                ForEach(items, id: \.name) { item in
                    InterestHobbyCard(item: item, color: color)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct InterestHobbyItem {
    let name: String
    let category: String
}

struct InterestHobbyCard: View {
    let item: InterestHobbyItem
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(item.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(item.category)
                .font(.system(size: 11))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(color.opacity(0.2))
                )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct EditStudentInterestsView: View {
    let student: Student
    @Environment(\.dismiss) private var dismiss
    @State private var selectedInterests: [Interest] = []
    // Note: Hobbies are now included in interests
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Edit \(student.name)'s")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Interests")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.tmiSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Interests Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                Text("Interests")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                                ForEach(Interest.expandedSampleInterests) { interest in
                                    InterestPickerCard(
                                        interest: interest,
                                        isSelected: selectedInterests.contains(interest),
                                        onTap: { toggleInterest(interest) }
                                    )
                                }
                            }
                        }
                        
                        // Note: Hobbies section removed - now handled through interests above
                    }
                    .padding(20)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Update the student with selected interests and hobbies
                        var updatedStudent = student
                        updatedStudent.interests = selectedInterests
                        // Note: Hobbies are now included in interests
                        
                        // Save the updated student (this would typically use StudentService)
                        Task {
                            // In a real implementation, you would call StudentService.updateStudent()
                            // For now, we'll just dismiss the view
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                    .foregroundColor(.tmiSecondary)
                    .font(.system(.caption, weight: .semibold))
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                selectedInterests = student.interests
                // Note: Hobbies are now included in interests
            }
    }
    
    private func toggleInterest(_ interest: Interest) {
        if selectedInterests.contains(interest) {
            selectedInterests.removeAll { $0.id == interest.id }
        } else {
            selectedInterests.append(interest)
        }
    }
    
    // Note: toggleHobby function removed - hobbies now handled through interests
}

#Preview {
    StudentDetailView(student: Student.sampleStudent)
}

