import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

// MARK: - View Model

@Observable
class StudentListViewModel {
  var students: [Student] = []
  var isLoading = false
  var errorMessage: String?
  private var db = FirebaseManager.shared.firestore

  private var userStudentsCollection: CollectionReference? {
    guard let uid = Auth.auth().currentUser?.uid else {
      print("Error: User not logged in.")
      return nil
    }
    return db.collection("users").document(uid).collection("students")
  }

  @MainActor
  func fetchStudents() async {
    guard let collection = userStudentsCollection else { return }
    
    isLoading = true
    errorMessage = nil
    
    do {
      let querySnapshot = try await collection.getDocuments()
      students = querySnapshot.documents.compactMap { document -> Student? in
        try? document.data(as: Student.self)
      }
      print("Fetched \(students.count) students")
    } catch {
      print("Error getting students: \(error.localizedDescription)")
      errorMessage = "Failed to load students: \(error.localizedDescription)"
    }
    
    isLoading = false
  }

  @MainActor
  func addStudent(_ student: Student) async -> Bool {
    guard let collection = userStudentsCollection else { 
      errorMessage = "Unable to access student collection"
      return false 
    }
    
    do {
      _ = try await collection.addDocument(data: student.toFirestoreData())
      await fetchStudents()  // Refresh the list after adding
      return true
    } catch {
      print("Error adding student: \(error.localizedDescription)")
      errorMessage = "Failed to add student: \(error.localizedDescription)"
      return false
    }
  }

  @MainActor
  func deleteStudent(_ student: Student) async -> Bool {
    guard let id = student.id else { 
      errorMessage = "Cannot delete student: Invalid student ID"
      return false 
    }
    guard let collection = userStudentsCollection else { 
      errorMessage = "Unable to access student collection"
      return false 
    }
    
    do {
      try await collection.document(id).delete()
      await fetchStudents()  // Refresh the list after deleting
      return true
    } catch {
      print("Error deleting student: \(error.localizedDescription)")
      errorMessage = "Failed to delete student: \(error.localizedDescription)"
      return false
    }
  }
}

enum FilterOption: String, CaseIterable, Identifiable {
  var id: String { self.rawValue }

  case all = "All"
  case active = "Active TMI"
  case inactive = "Inactive TMI"
  case highEngagement = "High Engagement"
  case lowEngagement = "Low Engagement"
}

// MARK: -  Student List View

struct StudentListView: View {
  @State private var viewModel = StudentListViewModel()
  @State private var searchText = ""
  @State private var showingAddStudent = false
  @State private var selectedFilterOption: FilterOption = .all
  @State private var showingFilterSheet = false
  @State private var selectedStudent: Student?
  @State private var isSearchFocused = false

  // Animation states
  @State private var headerAppeared = false
  @State private var searchBarAppeared = false
  @State private var gridAppeared = false
  @State private var actionBarAppeared = false

  // Layout states
  @State private var scrollOffset: CGFloat = 0
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    ZStack {
      // Background
      studentBackgroundView

      NavigationStack {
        ZStack {
          Color.clear  // Needed for scroll detection to work properly

          VStack(spacing: 0) {
            enhancedSearchAndFilterBar
              .padding(.top, 10)
              .padding(.horizontal)
              .opacity(searchBarAppeared ? 1 : 0)
              .offset(y: searchBarAppeared ? 0 : -20)

            enhancedStudentGrid
              .opacity(gridAppeared ? 1 : 0)

            enhancedQuickActionBar
              .opacity(actionBarAppeared ? 1 : 0)
              .offset(y: actionBarAppeared ? 0 : 100)
          }
          .background(
            GeometryReader { proxy in
              Color.clear.preference(
                key: ScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named("scrollView")).minY
              )
            }
          )
          .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
          }
        }
        .navigationTitle("Students")
        .foregroundColor(.white)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
              ForEach(FilterOption.allCases) { option in
                Button(action: {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedFilterOption = option
                  }
                }) {
                  Label(
                    option.rawValue,
                    systemImage: option == selectedFilterOption ? "checkmark.circle.fill" : "circle"
                  )
                }
              }

              Divider()

              Button(action: { showingFilterSheet = true }) {
                Label("Advanced Filters", systemImage: "slider.horizontal.3")
              }
            } label: {
              HStack(spacing: 4) {
                if selectedFilterOption != .all {
                  Text(selectedFilterOption.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.white)
                }

                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                  .font(.system(size: 20))
                  .foregroundColor(.white)
                  .symbolRenderingMode(.hierarchical)
                  .contentTransition(.symbolEffect(.replace))
              }
              .padding(6)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(
                    selectedFilterOption == .all ? Color.clear : Color.tmiSecondary.opacity(0.3))
              )
            }
          }
        }
        .sheet(isPresented: $showingAddStudent) {
          AddStudentView { newStudent in
            Task {
              let success = await viewModel.addStudent(newStudent)
              if success {
                showingAddStudent = false
              } else {
                // Error will be shown in the main view via viewModel.errorMessage
                showingAddStudent = false
              }
            }
          }
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
          .presentationCornerRadius(30)
          .presentationSizing(.page)
        }
        .sheet(isPresented: $showingFilterSheet) {
          StudentListFilterView(selectedOption: $selectedFilterOption)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .presentationSizing(.page)
        }
        .sheet(item: $selectedStudent) { student in
          StudentDetailView(student: student)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .presentationSizing(.page)
        }
        .onAppear {
          Task {
            await viewModel.fetchStudents()
          }

          // Animated appearance
          withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            headerAppeared = true
          }

          withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
            searchBarAppeared = true
          }

          withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
            gridAppeared = true
          }

          withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
            actionBarAppeared = true
          }
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Background

  private var studentBackgroundView: some View {
    // Using unified TMIBackgroundView
    TMIBackgroundView(variant: .default)
      .ignoresSafeArea()
  }

  // MARK: - Search & Filter Bar

  private var enhancedSearchAndFilterBar: some View {
    // Search Field - Using unified TMITextField
    TMITextField(
      icon: "magnifyingglass",
      placeholder: "Search students",
      text: $searchText
    )
  }

  // MARK: - Student Grid

  private var enhancedStudentGrid: some View {
    ScrollView {
      VStack(spacing: 24) {
        if viewModel.isLoading {
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.5)
              .foregroundColor(.white)
            
            Text("Loading students...")
              .font(.system(size: 16))
              .foregroundColor(.white.opacity(0.7))
          }
          .frame(maxWidth: .infinity, minHeight: 200)
        } else if let errorMessage = viewModel.errorMessage {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 50))
              .foregroundColor(.orange)
            
            Text("Error Loading Students")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.white)
            
            Text(errorMessage)
              .font(.system(size: 16))
              .foregroundColor(.white.opacity(0.7))
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)
            
            Button("Retry") {
              Task {
                await viewModel.fetchStudents()
              }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.tmiSecondary)
            .cornerRadius(12)
          }
          .frame(maxWidth: .infinity, minHeight: 200)
        } else if viewModel.students.isEmpty {
          enhancedEmptyState
        } else {
          // Stats summary
          enhancedStatsSummary

          // Grid layout
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 160 : 200), spacing: 20)],
            spacing: 20
          ) {
            ForEach(filteredStudents) { student in
              StudentCard(student: student)
                .onTapGesture {
                  selectedStudent = student
                }
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 100)  // Extra padding at bottom to account for the action bar
        }
      }
      .padding(.top, 20)
    }
    .coordinateSpace(name: "scrollView")
    .scrollIndicators(.hidden)
  }

  private var enhancedEmptyState: some View {
    VStack(spacing: 24) {
      // Empty illustration
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.2), Color.clear]),
              center: .center,
              startRadius: 1,
              endRadius: 100
            )
          )
          .frame(width: 200, height: 200)

        Image(systemName: "person.3.fill")
          .font(.system(size: 80))
          .foregroundColor(.white.opacity(0.7))
      }
      .padding(.top, 60)

      Text("No students available")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(.white)

      Text("Add your first student to get started with TMI")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Button {
        showingAddStudent = true
      } label: {
        HStack {
          Image(systemName: "person.badge.plus")
            .font(.system(size: 16, weight: .semibold))

          Text("Add Student")
            .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.tmiSecondary)
        )
        .foregroundColor(.white)
      }
      .padding(.top, 10)

      Spacer()
    }
    .frame(minHeight: 500)
    .padding(.horizontal)
  }

  private var enhancedStatsSummary: some View {
    HStack(spacing: 20) {
      StudentStatCard(
        title: "Total",
        value: "\(filteredStudents.count)",
        icon: "person.3.fill",
        color: .blue
      )

      StudentStatCard(
        title: "With TMI Plans",
        value: "\(filteredStudents.filter { $0.tmiPlans?.isEmpty == false }.count)",
        icon: "doc.text.fill",
        color: .orange
      )

      StudentStatCard(
        title: "High Engagement",
        value: "\(filteredStudents.filter { $0.engagementScore >= 0.7 }.count)",
        icon: "chart.line.uptrend.xyaxis.circle.fill",
        color: .green
      )
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Quick Action Bar

  private var enhancedQuickActionBar: some View {
    VStack(spacing: 0) {
      // Divider with gradient
      Rectangle()
        .fill(
          LinearGradient(
            colors: [.clear, .white.opacity(0.1), .clear],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 1)

      // Action buttons
      HStack(spacing: 20) {
        // Add Student Button
        StudentListActionButton(
          icon: "person.badge.plus",
          title: "Add Student",
          action: {
            showingAddStudent = true
          }
        )

        // Bulk Actions Button
        StudentListActionButton(
          icon: "person.crop.rectangle.stack.fill",
          title: "Bulk Actions",
          action: {
            // Implement bulk actions
          }
        )

        // Export Button
        StudentListActionButton(
          icon: "square.and.arrow.up",
          title: "Export",
          action: {
            // Implement export
          }
        )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(
        RoundedRectangle(cornerRadius: 30, style: .continuous)
          .fill(Color.black.opacity(0.2))
          .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
              .fill(.ultraThinMaterial)
              .opacity(0.8)
          )
          .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 30, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
          )
      )
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
    .ignoresSafeArea(.keyboard)
  }

  // MARK: - Filtered Students

  private var filteredStudents: [Student] {
    viewModel.students.filter { student in
      (searchText.isEmpty || student.name.localizedCaseInsensitiveContains(searchText))
        && (selectedFilterOption == .all
          || matchesFilter(student: student, filter: selectedFilterOption))
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
}

// MARK: - Student Card (Using dedicated StudentCard.swift file)

// MARK: - Engagement Badge

struct EngagementBadge: View {
  var score: Double

  var body: some View {
    HStack(spacing: 4) {
      Text(formattedScore)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(textColor)

      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(textColor)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(backgroundColor)
    )
  }

  private var icon: String {
    if score >= 0.7 {
      return "arrow.up"
    } else if score >= 0.4 {
      return "arrow.right"
    } else {
      return "arrow.down"
    }
  }

  private var formattedScore: String {
    return "\(Int(score * 100))%"
  }

  private var textColor: Color {
    if score >= 0.7 {
      return .green
    } else if score >= 0.4 {
      return .orange
    } else {
      return .red
    }
  }

  private var backgroundColor: Color {
    if score >= 0.7 {
      return Color.green.opacity(0.2)
    } else if score >= 0.4 {
      return Color.orange.opacity(0.2)
    } else {
      return Color.red.opacity(0.2)
    }
  }
}

// MARK: - Student Stat Card

struct StudentStatCard: View {
  var title: String
  var value: String
  var icon: String
  var color: Color

  @State private var isAnimated = false

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(color.opacity(0.15))
          .frame(width: 40, height: 40)

        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(color)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.7))

        Text(value)
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .foregroundColor(.white)
          .contentTransition(.numericText())
      }

      Spacer()
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.4)
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
    .onAppear {
      isAnimated = true
    }
  }
}

// MARK: - Quick Action Button

struct StudentListActionButton: View {
  var icon: String
  var title: String
  var action: () -> Void

  @State private var isHovered = false
  @State private var isPressed = false

  var body: some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.1)) {
        isPressed = true
      }

      // Slight delay to show press effect
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.easeInOut(duration: 0.1)) {
          isPressed = false
        }
        action()
      }
    }) {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .medium))
          .symbolEffect(.pulse, options: .speed(1.5), value: isHovered)

        Text(title)
          .font(.system(size: 12, weight: .medium))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isPressed)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - Add Student View

struct AddStudentView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var grade = ""
  @State private var studentID = ""
  @State private var dateOfBirth = Date()
  @State private var isSubmitting = false
  @State private var validationMessage = ""

  var onStudentAdded: ((Student) -> Void)?
  
  private var isFormInvalid: Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
    grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
    studentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      ZStack {
        // Background
        studentBackgroundView

        // Content
        ScrollView {
          VStack(spacing: 24) {
            // Form content
            TMITextField(
              icon: "person.fill",
              placeholder: "Student Name",
              text: $name
            )

            TMITextField(
              icon: "number",
              placeholder: "Grade Level",
              text: $grade,
              keyboardType: .numberPad
            )

            TMITextField(
              icon: "barcode",
              placeholder: "Student ID",
              text: $studentID,
              keyboardType: .numberPad
            )
            
            DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
              .datePickerStyle(.compact)
              .accentColor(.tmiSecondary)
              .padding(.bottom, 10)
            
            // Validation message
            if !validationMessage.isEmpty {
              Text(validationMessage)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            }

            // Submit button
            Button {
              // Validate inputs
              validationMessage = ""
              isSubmitting = true
              
              if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationMessage = "Please enter a student name"
                isSubmitting = false
                return
              }
              
              if grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationMessage = "Please enter a grade level"
                isSubmitting = false
                return
              }
              
              if studentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationMessage = "Please enter a student ID"
                isSubmitting = false
                return
              }
              
              // Construct new Student and call completion closure
              let newStudent = Student(
                id: nil,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                grade: grade.trimmingCharacters(in: .whitespacesAndNewlines),
                dateOfBirth: dateOfBirth,
                tmiPlans: [],
                studentID: studentID.trimmingCharacters(in: .whitespacesAndNewlines),
                interests: [],
                hobbies: [],
                photoURL: nil
              )
              onStudentAdded?(newStudent)
              // Don't dismiss here - let the parent handle it
            } label: {
              HStack {
                if isSubmitting {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                  Text("Add Student")
                    .font(.system(size: 17, weight: .semibold))
                }
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(
                LinearGradient(
                  colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .cornerRadius(14)
              .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isSubmitting || isFormInvalid)
            .opacity(isFormInvalid ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFormInvalid)
            .padding(.top, 10)
          }
          .padding(24)
        }
      }
      .navigationTitle("Add New Student")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var studentBackgroundView: some View {
    LinearGradient(
      gradient: Gradient(colors: [
        Color(red: 0.08, green: 0.08, blue: 0.15),
        Color(red: 0.14, green: 0.14, blue: 0.25),
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }
}

// MARK: - Filter View

struct StudentListFilterView: View {
  @Binding var selectedOption: FilterOption
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        // Background
        studentBackgroundView

        // Content
        ScrollView {
          VStack(spacing: 16) {
            ForEach(FilterOption.allCases) { option in
              StudentListFilterOptionCard(
                option: option,
                isSelected: selectedOption == option,
                action: {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedOption = option
                    dismiss()
                  }
                }
              )
            }
          }
          .padding(20)
        }
      }
      .navigationTitle("Filter Students")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var studentBackgroundView: some View {
    LinearGradient(
      gradient: Gradient(colors: [
        Color(red: 0.08, green: 0.08, blue: 0.15),
        Color(red: 0.14, green: 0.14, blue: 0.25),
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }
}

struct StudentListFilterOptionCard: View {
  var option: FilterOption
  var isSelected: Bool
  var action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
        // Icon
        filterIcon
          .padding(12)
          .background(
            Circle()
              .fill(isSelected ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.05))
          )

        // Label
        VStack(alignment: .leading, spacing: 4) {
          Text(option.rawValue)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)

          Text(filterDescription)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.7))
            .lineLimit(1)
        }

        Spacer()

        // Selection indicator
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(Color.tmiSecondary)
            .font(.system(size: 22))
        }
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
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
                colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
            lineWidth: 1
          )
      )
      .shadow(
        color: isSelected ? Color.tmiSecondary.opacity(0.2) : Color.clear, radius: 10, x: 0, y: 5
      )
      .scaleEffect(isHovered ? 1.02 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private var filterIcon: some View {
    let iconName: String
    let iconColor: Color

    switch option {
    case .all:
      iconName = "person.3.fill"
      iconColor = .blue
    case .active:
      iconName = "checkmark.circle.fill"
      iconColor = .green
    case .inactive:
      iconName = "xmark.circle.fill"
      iconColor = .orange
    case .highEngagement:
      iconName = "chart.line.uptrend.xyaxis.circle.fill"
      iconColor = .green
    case .lowEngagement:
      iconName = "chart.line.downtrend.xyaxis.circle.fill"
      iconColor = .red
    }

    return Image(systemName: iconName)
      .font(.system(size: 20))
      .foregroundColor(iconColor)
  }

  private var filterDescription: String {
    switch option {
    case .all:
      return "View all enrolled students"
    case .active:
      return "Students with active TMI plans"
    case .inactive:
      return "Students without active TMI plans"
    case .highEngagement:
      return "Students with engagement score above 70%"
    case .lowEngagement:
      return "Students with engagement score below 30%"
    }
  }
}

// MARK: - Student Detail View

struct StudentDetailView: View {
  var student: Student
  @Environment(\.dismiss) private var dismiss

  @State private var tabSelection = 0
  @State private var showingNewPlanSheet = false

  var body: some View {
    NavigationStack {
      ZStack {
        studentBackgroundView

        ScrollView {
          VStack(spacing: 24) {
            profileHeader

            Button(action: { showingNewPlanSheet = true }) {
              Label("Create TMI Plan", systemImage: "plus.square.on.square")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.tmiSecondary))
                .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.top, 8)

            StudentListTabPicker(selection: $tabSelection)
              .padding(.horizontal, 20)
            tabContent
              .padding(.horizontal, 20)
          }
        }
      }
      .navigationTitle("Student Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarMenu }
      .sheet(isPresented: $showingNewPlanSheet) {
        NewTMIPlanView(preselectedStudent: student)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
          .presentationCornerRadius(30)
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Subviews

  private var profileHeader: some View {
    VStack(spacing: 16) {
      avatarView
      nameAndGradeView
      quickStatsView
    }
    .padding(20)
  }

  private var avatarView: some View {
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
  }

  private var nameAndGradeView: some View {
    VStack(spacing: 4) {
      Text(student.name)
        .font(.system(size: 24, weight: .bold))
        .foregroundColor(.white)
      Text("Grade \(student.grade) • ID: \(student.studentID)")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
    }
  }

  private var quickStatsView: some View {
    HStack(spacing: 20) {
      statView(
        title: "Engagement",
        value: "\(Int(student.engagementScore * 100))%",
        color: engagementColor)
      divider
      statView(
        title: "TMI Plan",
        value: student.tmiPlans?.isEmpty == false ? "Active" : "None",
        color: student.tmiPlans?.isEmpty == false ? .green : .orange)
      divider
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

  private var divider: some View {
    Rectangle()
      .fill(Color.white.opacity(0.2))
      .frame(width: 1, height: 30)
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarMenu: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Menu {
        Button(action: {
          // Edit action
        }) {
          Label("Edit Student", systemImage: "pencil")
        }
        Button(action: {
          // Add TMI Plan action
        }) {
          Label("Add TMI Plan", systemImage: "doc.badge.plus")
        }
        Divider()
        Button(
          role: .destructive,
          action: {
            // Delete action
          }
        ) {
          Label("Delete Student", systemImage: "trash")
        }
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 20))
          .foregroundColor(.white)
      }
    }
  }

  private var studentBackgroundView: some View {
    LinearGradient(
      gradient: Gradient(colors: [
        Color(red: 0.08, green: 0.08, blue: 0.15),
        Color(red: 0.14, green: 0.14, blue: 0.25),
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }

  @ViewBuilder
  private var tabContent: some View {
    switch tabSelection {
    case 0:
      // TMI Plans
      if student.tmiPlans?.isEmpty ?? true {
        emptyStateView(
          icon: "doc.text.fill",
          title: "No TMI Plans",
          message: "Create a TMI plan to start tracking the student's progress",
          buttonTitle: "Create TMI Plan",
          action: {
            showingNewPlanSheet = true
          }
        )
      } else {
        Text("TMI Plans content")
      }

    case 1:
      // Interests & Hobbies
      if student.interests.isEmpty {
        emptyStateView(
          icon: "heart.fill",
          title: "No Interests Recorded",
          message: "Record the student's interests and hobbies to improve TMI alignment",
          buttonTitle: "Add Interests",
          action: {
            // Add interests action
          }
        )
      } else {
        Text("Interests & Hobbies content")
      }

    case 2:
      // Survey Results
      if student.surveyResults?.isEmpty ?? true {
        emptyStateView(
          icon: "list.clipboard.fill",
          title: "No Survey Results",
          message: "Assign surveys to collect valuable data for the TMI program",
          buttonTitle: "Assign Survey",
          action: {
            // Assign survey action
          }
        )
      } else {
        Text("Survey Results content")
      }

    default:
      Text("Invalid tab")
    }
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

      Button(action: action) {
        Text(buttonTitle)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(Color.tmiSecondary)
          .cornerRadius(12)
      }
      .buttonStyle(.plain)
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

// MARK: - Tab Picker

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

// MARK: - Using TMITextField from unified components

// MARK: - Animated Blob View

// MARK: - Helper Extensions and Types

struct ScrollOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: - Preview

#Preview {
  StudentListView()
}

