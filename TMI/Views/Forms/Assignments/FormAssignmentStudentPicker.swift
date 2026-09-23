import SwiftUI

// MARK: - Cohort Type

enum CohortType: CaseIterable {
  case allStudents
  case school
  case grade
  case specificStudents

  var displayName: String {
    switch self {
    case .allStudents: return "All Students"
    case .school: return "Specific School"
    case .grade: return "Grade Level"
    case .specificStudents: return "Specific Students"
    }
  }
}


// MARK: - Student Picker

/// Multi-select roster picker used to build a `.specificStudents` cohort.
/// Reuses the canonical `StudentListState` so search, paging, and access
/// policy match the main Students roster.
struct FormAssignmentStudentPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selection: Set<String>
  let member: MembershipContext
  let repository: any StudentRepository

  @State private var state: StudentListState?
  @State private var workingSelection: Set<String> = []

  var body: some View {
    NavigationStack {
      Group {
        if let state {
          FormAssignmentStudentPickerContent(
            state: state,
            workingSelection: $workingSelection
          )
        } else {
          ProgressView("Loading students…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .navigationTitle("Select Students")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            selection = workingSelection
            dismiss()
          }
        }
      }
    }
    .task {
      guard state == nil else { return }
      workingSelection = selection
      let newState = StudentListState(repository: repository, member: member)
      state = newState
      await newState.load()
    }
  }
}

private struct FormAssignmentStudentPickerContent: View {
  @Bindable var state: StudentListState
  @Binding var workingSelection: Set<String>

  var body: some View {
    Group {
      switch state.phase {
      case .idle, .loading:
        ProgressView("Loading students…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)

      case .empty:
        ContentUnavailableView(
          "No Students",
          systemImage: "person.2.slash",
          description: Text("No students match your search or you don't have access to any roster records.")
        )

      case .permissionDenied:
        ContentUnavailableView(
          "Access Unavailable",
          systemImage: "lock",
          description: Text("A verified staff membership is required to view students.")
        )

      case .failed(let message):
        ContentUnavailableView(
          "Couldn't Load Students",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )

      case .loaded, .refreshing, .offline:
        studentList
      }
    }
    .searchable(text: $state.searchText, prompt: "Search students")
  }

  private var studentList: some View {
    List {
      if !workingSelection.isEmpty {
        Section {
          HStack {
            Text("\(workingSelection.count) selected")
              .font(.subheadline.weight(.medium))
              .foregroundColor(.secondary)
            Spacer()
            Button("Clear") { workingSelection.removeAll() }
              .font(.subheadline)
          }
        }
      }

      Section {
        ForEach(state.students) { record in
          studentRow(record)
            .onAppear {
              if record.id == state.students.last?.id, state.canLoadNextPage {
                Task { await state.loadNextPage() }
              }
            }
        }

        if state.isLoadingNextPage {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      }
    }
    .listStyle(.plain)
    .refreshable { await state.refresh() }
  }

  private func studentRow(_ record: StudentRecord) -> some View {
    let isSelected = workingSelection.contains(record.id)
    return Button {
      if isSelected {
        workingSelection.remove(record.id)
      } else {
        workingSelection.insert(record.id)
      }
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(record.displayName)
            .font(.body)
            .foregroundColor(.primary)
          Text("Grade \(record.grade)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundColor(isSelected ? TMIColors.accent : Color.secondary.opacity(0.5))
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(record.displayName)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
