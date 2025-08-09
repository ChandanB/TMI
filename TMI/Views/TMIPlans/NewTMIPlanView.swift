// NewTMIPlanView.swift

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct NewTMIPlanView: View {
  var preselectedStudent: Student? = nil
  var onPlanCreated: ((TMIPlan) -> Void)? = nil
  
  @Environment(\.dismiss) private var dismiss

  // State for selection
  @State private var selectedStudent: Student?
  @State private var selectedModel: TMIPlanModel?
  @State private var selectedInterests: [Interest] = []
  @State private var selectedHobbies: [Hobby] = []
  @State private var notes: String = ""

  // Data state
  @State private var students: [Student] = []
  @State private var interests: [Interest] = []
  @State private var hobbies: [Hobby] = []
  @State private var isLoadingData = false

  // UI state
  @State private var currentStep = 0
  @State private var showingAlert = false
  @State private var alertMessage = ""
  @State private var isCreatingPlan = false

  // Animation states
  @State private var headerAppeared = false
  @State private var contentAppeared = false
  @State private var navigationAppeared = false

  private let totalSteps = 4
  
  init(preselectedStudent: Student? = nil, onPlanCreated: ((TMIPlan) -> Void)? = nil) {
    self.preselectedStudent = preselectedStudent
    self.onPlanCreated = onPlanCreated
    _selectedStudent = State(initialValue: preselectedStudent)
  }

  var body: some View {
    ZStack {
      // Background
      planCreationBackgroundView

      NavigationStack {
        VStack(spacing: 0) {
          // Header and progress bar
          VStack(spacing: 16) {
            enhancedHeaderView
              .padding(.top, 16)
              .padding(.horizontal, 20)
              .offset(y: headerAppeared ? 0 : -20)
              .opacity(headerAppeared ? 1 : 0)

            enhancedProgressBar
              .padding(.horizontal, 20)
              .offset(y: headerAppeared ? 0 : -15)
              .opacity(headerAppeared ? 1 : 0)
          }

          // Step content
          ScrollView {
            VStack(spacing: 20) {
              stepTitleView
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .offset(y: contentAppeared ? 0 : 20)
                .opacity(contentAppeared ? 1 : 0)

              enhancedStepContent
                .padding(.horizontal, 20)
                .offset(y: contentAppeared ? 0 : 30)
                .opacity(contentAppeared ? 1 : 0)
            }
            .padding(.bottom, 100)
          }

          // Navigation buttons
          enhancedNavigationButtons
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
              Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.5)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
            )
            .offset(y: navigationAppeared ? 0 : 50)
            .opacity(navigationAppeared ? 1 : 0)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text("Create TMI Plan")
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundColor(.white)
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(ScaleButtonStyle())
          }
        }
        .alert(alertMessage, isPresented: $showingAlert) {
          Button("OK", role: .cancel) {}
        }
      }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      animateViews()
      Task {
        await fetchAllData()
      }
    }
  }

  private func animateViews() {
    withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
      headerAppeared = true
    }

    withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
      contentAppeared = true
    }

    withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
      navigationAppeared = true
    }
  }

  // MARK: - Background

  private var planCreationBackgroundView: some View {
    // Using unified TMIBackgroundView with plans variant
    TMIBackgroundView(variant: .plans)
      .ignoresSafeArea()
  }

  // MARK: - Header Views

  private var enhancedHeaderView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("New TMI Plan")
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(.white)

      Text(stepSubtitle)
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var enhancedProgressBar: some View {
    VStack(spacing: 8) {
      // Progress bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.1))
            .frame(height: 8)

          // Progress
          RoundedRectangle(cornerRadius: 4)
            .fill(
              LinearGradient(
                colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(
              width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 8
            )
            .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 4, x: 0, y: 0)
        }
      }
      .frame(height: 8)

      // Step indicators
      HStack {
        ForEach(0..<totalSteps, id: \.self) { step in
          StepIndicator(
            step: step + 1,
            isActive: currentStep >= step,
            isCurrent: currentStep == step
          )

          if step < totalSteps - 1 {
            Spacer()
          }
        }
      }
    }
  }

  private var stepTitleView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Step \(currentStep + 1) of \(totalSteps)")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(Color.tmiSecondary)

        Text(stepTitle)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.white)
      }

      Spacer()
    }
  }

  // MARK: - Step Content

  @ViewBuilder
  private var enhancedStepContent: some View {
    if isLoadingData {
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
        
        Text("Loading data...")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.7))
      }
      .frame(maxWidth: .infinity, minHeight: 200)
    } else {
      switch currentStep {
      case 0:
        enhancedSelectStudentView
      case 1:
        enhancedSelectModelView
      case 2:
        enhancedSelectInterestsView
      case 3:
        enhancedSelectHobbiesView
      default:
        EmptyView()
      }
    }
  }

  private var enhancedSelectStudentView: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Select a student for this TMI plan")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView {
        VStack(spacing: 12) {
          ForEach(students) { student in
            StudentSelectionCard(
              student: student,
              isSelected: selectedStudent?.id == student.id,
              action: {
                selectedStudent = student
              }
            )
          }
        }
      }
    }
  }

  private var enhancedSelectModelView: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Choose the most appropriate TMI model")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView {
        VStack(spacing: 16) {
          ForEach(TMIPlanModel.allCases, id: \.self) { model in
            ModelCard(
              model: model,
              isSelected: selectedModel == model,
              action: {
                selectedModel = model
              }
            )
          }
        }
      }
    }
  }

  private var enhancedSelectInterestsView: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Select relevant interests")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.7))

        if let student = selectedStudent {
          Text("Based on \(student.name)'s profile")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.5))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Selected counter
      Text("Selected: \(selectedInterests.count)")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(selectedInterests.isEmpty ? .white.opacity(0.5) : Color.tmiSecondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
          Capsule()
            .fill(Color.white.opacity(0.05))
        )
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
          ForEach(interests) { interest in
            InterestSelectionCard(
              interest: interest,
              isSelected: selectedInterests.contains(interest),
              action: {
                toggleSelection(of: interest, in: &selectedInterests)
              }
            )
          }
        }
      }
    }
  }

  private var enhancedSelectHobbiesView: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Select relevant hobbies")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.7))

        if let student = selectedStudent {
          Text("Based on \(student.name)'s profile")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.5))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Selected counter and notes
      Text("Selected: \(selectedHobbies.count)")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(selectedHobbies.isEmpty ? .white.opacity(0.5) : Color.tmiSecondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
          Capsule()
            .fill(Color.white.opacity(0.05))
        )
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
          ForEach(hobbies) { hobby in
            HobbySelectionCard(
              hobby: hobby,
              isSelected: selectedHobbies.contains(hobby),
              action: {
                toggleSelection(of: hobby, in: &selectedHobbies)
              }
            )
          }
        }
      }

      // Notes field
      VStack(alignment: .leading, spacing: 10) {
        Text("Additional Notes (Optional)")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.white)

        TextEditor(text: $notes)
          .frame(minHeight: 100)
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white.opacity(0.05))
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(.ultraThinMaterial)
                  .opacity(0.3)
              )
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .foregroundColor(.white)
      }
      .padding(.top, 16)
    }
  }

  // MARK: - Navigation Buttons

  private var enhancedNavigationButtons: some View {
    HStack(spacing: 16) {
      // Back button
      if currentStep > 0 {
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentStep -= 1
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .semibold))

            Text("Back")
              .font(.system(size: 16, weight: .semibold))
          }
          .frame(height: 50)
          .frame(maxWidth: .infinity)
          .foregroundColor(.white)
          .background(
            RoundedRectangle(cornerRadius: 14)
              .fill(Color.white.opacity(0.1))
          )
        }
        .buttonStyle(ScaleButtonStyle())
      }

      // Next/Save button
      Button {
        if validateCurrentStep() {
          if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              currentStep += 1
            }
          } else {
            savePlan()
          }
        }
      } label: {
        HStack(spacing: 8) {
          if isCreatingPlan {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
          } else {
            Text(currentStep < totalSteps - 1 ? "Next" : "Create Plan")
              .font(.system(size: 16, weight: .semibold))

            Image(systemName: currentStep < totalSteps - 1 ? "chevron.right" : "checkmark.circle")
              .font(.system(size: 16, weight: .semibold))
          }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .fill(
              LinearGradient(
                colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        )
        .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
      }
      .buttonStyle(ScaleButtonStyle())
      .disabled(isCreatingPlan)
    }
  }

  // MARK: - Properties

  private var stepTitle: String {
    switch currentStep {
    case 0:
      return "Select a Student"
    case 1:
      return "Choose TMI Model"
    case 2:
      return "Select Interests"
    case 3:
      return "Select Hobbies"
    default:
      return ""
    }
  }

  private var stepSubtitle: String {
    switch currentStep {
    case 0:
      return "Choose a student for this plan"
    case 1:
      return "Select the appropriate TMI model"
    case 2:
      return "Identify relevant interests"
    case 3:
      return "Complete your plan"
    default:
      return ""
    }
  }

  // MARK: - Helper Methods

  private func validateCurrentStep() -> Bool {
    switch currentStep {
    case 0:
      if selectedStudent == nil {
        alertMessage = "Please select a student to continue."
        showingAlert = true
        return false
      }
    case 1:
      if selectedModel == nil {
        alertMessage = "Please select a TMI model to continue."
        showingAlert = true
        return false
      }
    case 2:
      if selectedInterests.isEmpty {
        // This is not a hard requirement, but we'll show a confirmation
        alertMessage = "You haven't selected any interests. Are you sure you want to continue?"
        return true
      }
    default:
      break
    }
    return true
  }

  private func savePlan() {
    guard let student = selectedStudent, let model = selectedModel else { return }

    isCreatingPlan = true
    
    Task {
      do {
        let newPlan = TMIPlan(
          id: nil, // Let Firestore generate the ID
          student: student,
          students: [student],
          model: model,
          interests: selectedInterests,
          hobbies: selectedHobbies,
          creationDate: Date(),
          lastUpdated: Date(),
          goals: [],
          progress: 0.0,
          notes: notes
        )
        
        let planService = TMIPlanService()
        let savedPlan = try await planService.addPlan(newPlan)
        
        await MainActor.run {
          isCreatingPlan = false
          onPlanCreated?(savedPlan)
          dismiss()
        }
      } catch {
        await MainActor.run {
          isCreatingPlan = false
          alertMessage = "Failed to save plan: \(error.localizedDescription)"
          showingAlert = true
        }
      }
    }
  }

  // MARK: - Data Fetching Functions

  @MainActor
  private func fetchAllData() async {
    isLoadingData = true
    
    do {
      // Use StudentService for consistent student fetching
      let studentService = StudentService()
      students = try await studentService.fetchStudents()
      
      // Fetch interests and hobbies using the existing logic
      guard let uid = Auth.auth().currentUser?.uid else { 
        print("No authenticated user found")
        students = Student.comprehensiveSampleStudents
        interests = Interest.expandedSampleInterests
        hobbies = Hobby.expandedSampleHobbies
        isLoadingData = false
        return 
      }
      
      let db = FirebaseManager.shared.firestore
      
      async let interestsTask = fetchInterestsFromFirestore(db: db, uid: uid)
      async let hobbiesTask = fetchHobbiesFromFirestore(db: db, uid: uid)
      
      interests = try await interestsTask
      hobbies = try await hobbiesTask
      
      print("Fetched \(students.count) students, \(interests.count) interests, \(hobbies.count) hobbies")
    } catch {
      print("Error fetching data: \(error.localizedDescription)")
      // Fall back to sample data if Firebase fails
      students = Student.comprehensiveSampleStudents
      interests = Interest.expandedSampleInterests
      hobbies = Hobby.expandedSampleHobbies
    }
    
    isLoadingData = false
  }

  private func fetchInterestsFromFirestore(db: Firestore, uid: String) async throws -> [Interest] {
    let collection = db.collection("users").document(uid).collection("interests")
    let querySnapshot = try await collection.getDocuments()
    return querySnapshot.documents.compactMap { document -> Interest? in
      Interest.fromFirestore(id: document.documentID, data: document.data())
    }
  }

  private func fetchHobbiesFromFirestore(db: Firestore, uid: String) async throws -> [Hobby] {
    let collection = db.collection("users").document(uid).collection("hobbies")
    let querySnapshot = try await collection.getDocuments()
    return querySnapshot.documents.compactMap { document -> Hobby? in
      Hobby.fromFirestore(id: document.documentID, data: document.data())
    }
  }


  private func toggleSelection<T: Identifiable & Equatable>(of item: T, in array: inout [T]) {
    if let index = array.firstIndex(of: item) {
      array.remove(at: index)
    } else {
      array.append(item)
    }
  }
}

// MARK: - Supporting Views

struct StepIndicator: View {
  var step: Int
  var isActive: Bool
  var isCurrent: Bool

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(isActive ? Color.tmiSecondary : Color.white.opacity(0.2))
          .frame(width: 28, height: 28)

        if isCurrent {
          Circle()
            .stroke(Color.tmiSecondary, lineWidth: 2)
            .frame(width: 34, height: 34)
        }

        Text("\(step)")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(isActive ? .white : .white.opacity(0.5))
      }

      if isCurrent {
        Text("Current")
          .font(.system(size: 10))
          .foregroundColor(Color.tmiSecondary)
      }
    }
  }
}

struct StudentSelectionCard: View {
  let student: Student
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        // Avatar
        ZStack {
          Circle()
            .fill(getAvatarColor())
            .frame(width: 50, height: 50)

          Text(student.initials)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
        }

        // Student info
        VStack(alignment: .leading, spacing: 4) {
          Text(student.name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)

          HStack(spacing: 12) {
            Label("Grade \(student.grade)", systemImage: "bookmark.fill")
              .font(.system(size: 13))
              .foregroundColor(.white.opacity(0.7))

            if !student.interests.isEmpty {
              Label("\(student.interests.count) Interests", systemImage: "heart.fill")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            }
          }
        }

        Spacer()

        // Selection indicator
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(Color.tmiSecondary)
            .font(.system(size: 22))
        }
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(isSelected ? Color.tmiSecondary.opacity(0.2) : Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected
              ? LinearGradient(
                colors: [Color.tmiSecondary.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              : LinearGradient(
                colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
      .scaleEffect(isHovered ? 1.02 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private func getAvatarColor() -> Color {
    switch student.avatarColor {
    case .blue: return Color.blue.opacity(0.2)
    case .green: return Color.green.opacity(0.2)
    case .orange: return Color.orange.opacity(0.2)
    case .purple: return Color.purple.opacity(0.2)
    case .teal: return Color.teal.opacity(0.2)
    case .pink: return Color.pink.opacity(0.2)
    default: return Color.indigo.opacity(0.2)
    }
  }
}

struct ModelCard: View {
  let model: TMIPlanModel
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 16) {
        // Model icon
        ZStack {
          Circle()
            .fill(modelColor.opacity(0.15))
            .frame(width: 50, height: 50)

          Image(systemName: modelIcon)
            .font(.system(size: 20))
            .foregroundColor(modelColor)
        }
        .padding(.top, 4)

        // Model info
        VStack(alignment: .leading, spacing: 8) {
          Text(model.rawValue)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)

          Text(model.description)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.7))
            .lineLimit(3)
        }

        Spacer()

        // Selection indicator
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(modelColor)
            .font(.system(size: 22))
            .padding(.top, 4)
        }
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(isSelected ? modelColor.opacity(0.1) : Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected
              ? LinearGradient(
                colors: [modelColor.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              : LinearGradient(
                colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
      .scaleEffect(isHovered ? 1.02 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private var modelIcon: String {
    switch model {
    case .chaseYourSpace:
      return "rocket.fill"
    case .acknowledgeInterests:
      return "heart.fill"
    case .alignYourMind:
      return "brain.head.profile.fill"
    case .directAndCorrect:
      return "arrow.up.forward.circle.fill"
    case .bullyToBoss:
      return "person.fill.badge.plus"
    case .meekToProtector:
      return "person.fill.turn.up"
    }
  }

  private var modelColor: Color {
    switch model {
    case .chaseYourSpace:
      return .blue
    case .acknowledgeInterests:
      return .pink
    case .alignYourMind:
      return .purple
    case .directAndCorrect:
      return .orange
    case .bullyToBoss:
      return .red
    case .meekToProtector:
      return .green
    }
  }
}

struct InterestSelectionCard: View {
  let interest: Interest
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(interest.color.opacity(0.15))
            .frame(width: 40, height: 40)

          Image(systemName: interest.iconName)
            .font(.system(size: 18))
            .foregroundColor(interest.color)
        }

        Text(interest.name)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
          .lineLimit(1)

        Text(interest.category.map { $0.rawValue }.joined(separator: ", "))
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(isSelected ? interest.color.opacity(0.15) : Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected
              ? LinearGradient(
                colors: [interest.color.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              : LinearGradient(
                colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
      .scaleEffect(isHovered ? 1.05 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

struct HobbySelectionCard: View {
  let hobby: Hobby
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(hobby.color.opacity(0.15))
            .frame(width: 40, height: 40)

          Image(systemName: hobby.iconName)
            .font(.system(size: 18))
            .foregroundColor(hobby.color)
        }

        Text(hobby.name)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
          .lineLimit(1)

        Text(hobby.category.map { $0.rawValue }.joined(separator: ", "))
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(isSelected ? hobby.color.opacity(0.15) : Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected
              ? LinearGradient(
                colors: [hobby.color.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              : LinearGradient(
                colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
      .scaleEffect(isHovered ? 1.05 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - Preview

#Preview {
  NewTMIPlanView()
}

