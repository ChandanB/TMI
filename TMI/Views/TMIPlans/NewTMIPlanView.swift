// NewTMIPlanView.swift

import SwiftUI

struct NewTMIPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStudent: Student?
    @State private var selectedModel: TMIPlanModel?
    @State private var selectedInterests: [Interest] = []
    @State private var selectedHobbies: [Hobby] = []
    @State private var currentStep = 0

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    progressBar
                    stepContent
                    Spacer()
                    navigationButtons
                }
                .padding()
            }
            .background(Color.tmiBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Incomplete"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Create New TMI Plan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
                Text(stepTitle)
                    .font(.title3)
                    .foregroundColor(.tmiSecondary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.tmiPrimary)
            }
        }
    }

    private var progressBar: some View {
        ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
            .progressViewStyle(LinearProgressViewStyle(tint: .tmiPrimary))
            .padding(.vertical)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            selectStudentView
        case 1:
            selectModelView
        case 2:
            selectInterestsView
        case 3:
            selectHobbiesView
        default:
            EmptyView()
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0:
            return "Select a Student"
        case 1:
            return "Choose a TMI Model"
        case 2:
            return "Select Interests"
        case 3:
            return "Select Hobbies"
        default:
            return ""
        }
    }

    private var selectStudentView: some View {
        VStack(spacing: 20) {
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(fetchStudents()) { student in
                        StudentSelectionCard(student: student, isSelected: selectedStudent?.id == student.id) {
                            selectedStudent = student
                        }
                    }
                }
            }
        }
    }

    private var selectModelView: some View {
        VStack(spacing: 20) {
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(TMIPlanModel.allCases, id: \.self) { model in
                        TMIModelCard(model: model, isSelected: selectedModel == model) {
                            selectedModel = model
                        }
                    }
                }
            }
        }
    }

    private var selectInterestsView: some View {
        VStack(spacing: 20) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                    ForEach(fetchInterests()) { interest in
                        SelectableChip(title: interest.name, isSelected: selectedInterests.contains(interest)) {
                            toggleSelection(of: interest, in: &selectedInterests)
                        }
                    }
                }
            }
        }
    }

    private var selectHobbiesView: some View {
        VStack(spacing: 20) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                    ForEach(fetchHobbies()) { hobby in
                        SelectableChip(title: hobby.name, isSelected: selectedHobbies.contains(hobby)) {
                            toggleSelection(of: hobby, in: &selectedHobbies)
                        }
                    }
                }
            }
        }
    }

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button(action: { currentStep -= 1 }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.tmiPrimary)
                    .padding()
                    .background(Color.tmiSecondary.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button(action: {
                    if validateCurrentStep() {
                        currentStep += 1
                    }
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.tmiPrimary)
                    .cornerRadius(10)
                }
            } else {
                Button(action: {
                    if validateCurrentStep() {
                        savePlan()
                    }
                }) {
                    HStack {
                        Text("Save Plan")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.tmiPrimary)
                    .cornerRadius(10)
                }
            }
        }
    }

    @State private var showingAlert = false
    @State private var alertMessage = ""

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case 0:
            if selectedStudent == nil {
                alertMessage = "Please select a student."
                showingAlert = true
                return false
            }
        case 1:
            if selectedModel == nil {
                alertMessage = "Please select a TMI model."
                showingAlert = true
                return false
            }
        default:
            break
        }
        return true
    }

    private func savePlan() {
        guard let student = selectedStudent, let model = selectedModel else { return }
        let newPlan = TMIPlan(
            student: student,
            students: [student],
            model: model,
            interests: selectedInterests,
            hobbies: selectedHobbies,
            creationDate: Date(),
            lastUpdated: Date(),
            progress: 0.0,
            notes: ""
        )
        dismiss()
    }

    private func fetchStudents() -> [Student] {
        return Student.sampleStudents
    }

    private func fetchInterests() -> [Interest] {
        return Interest.sampleInterests
    }

    private func fetchHobbies() -> [Hobby] {
        return Hobby.sampleHobbies
    }

    private func toggleSelection<T: Identifiable & Equatable>(of item: T, in array: inout [T]) {
        if let index = array.firstIndex(of: item) {
            array.remove(at: index)
        } else {
            array.append(item)
        }
    }
}

// MARK: - Custom Components

struct StudentSelectionCard: View {
    let student: Student
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                AvatarView(student: student)
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading) {
                    Text(student.name)
                        .font(.headline)
                        .foregroundColor(.tmiText)
                    Text("Grade \(student.grade)")
                        .font(.subheadline)
                        .foregroundColor(.tmiSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.tmiPrimary.opacity(0.1) : Color.tmiSecondary.opacity(0.05))
            )
        }
    }
}

struct TMIModelCard: View {
    let model: TMIPlanModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.rawValue)
                        .font(.headline)
                        .foregroundColor(.tmiText)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                }
                Text(model.description)
                    .font(.body)
                    .foregroundColor(.tmiSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.tmiPrimary.opacity(0.1) : Color.tmiSecondary.opacity(0.05))
            )
        }
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .tmiText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.tmiPrimary : Color.tmiSecondary.opacity(0.2))
                )
        }
    }
}

#Preview {
    NewTMIPlanView()
}
