import SwiftUI

struct StudentModeLaunchView: View {
    @Environment(\.dismiss) private var dismiss

    let student: StudentRecord
    let member: MembershipContext
    let repository: StudentModeRepository
    let session: StudentModeSession

    @State private var assignments: [FormAssignment] = []
    @State private var isLoading = true
    @State private var launchingAssignmentID: String?
    @State private var errorMessage: String?

    private let assignmentService = FormAssignmentService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading assigned activities…")
                } else if assignments.isEmpty {
                    ContentUnavailableView(
                        "No Eligible Activities",
                        systemImage: "list.clipboard",
                        description: Text(
                            "Create an active assignment with an exact student target "
                                + "before launching Student Mode."
                        )
                    )
                } else {
                    List(assignments) { assignment in
                        Button {
                            Task {
                                await launch(assignment)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                                    Text(assignment.templateName)
                                        .font(.headline)
                                    if let instructions = assignment.instructions,
                                       !instructions.isEmpty {
                                        Text(instructions)
                                            .font(.subheadline)
                                            .foregroundStyle(TMIColors.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if launchingAssignmentID == assignment.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "lock.shield")
                                        .foregroundStyle(TMIColors.teal)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(launchingAssignmentID != nil)
                    }
                }
            }
            .navigationTitle("Launch Student Mode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(launchingAssignmentID != nil)
                }
            }
            .task {
                await loadAssignments()
            }
            .alert("Student Mode Unavailable", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "The secure session could not be started.")
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { presented in
                if !presented {
                    errorMessage = nil
                }
            }
        )
    }

    private func loadAssignments() async {
        defer { isLoading = false }
        guard let scope = StudentAuthorizationScope(record: student) else {
            errorMessage = "The student authorization scope is incomplete."
            return
        }
        do {
            assignments = try await assignmentService
                .fetchActiveAssignmentsForStudent(student: scope)
                .filter { assignment in
                    guard let assignmentID = assignment.id,
                          TrustedIdentifier.isValid(assignmentID) else {
                        return false
                    }
                    return assignment.studentIDs?.contains(student.id) == true
                }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Assigned activities could not be loaded."
        }
    }

    private func launch(_ assignment: FormAssignment) async {
        guard let assignmentID = assignment.id,
              assignment.studentIDs?.contains(student.id) == true else {
            errorMessage = "This activity is not scoped to the selected student."
            return
        }
        launchingAssignmentID = assignmentID
        defer { launchingAssignmentID = nil }
        do {
            let scope = try StudentModeScope(
                districtID: student.districtID,
                studentID: student.id,
                assignmentIDs: [assignmentID],
                allowedOperations: StudentModeOperation.surveyAssignment
            )
            let grant = try await repository.issueSession(
                scope: scope,
                requestedDurationMinutes: nil,
                staffIdentity: StudentModeStaffIdentity(
                    userID: member.userID,
                    districtID: member.districtID,
                    membershipVersion: member.version
                ),
                expectedStudentRecordVersion: student.metadata.recordVersion,
                idempotencyKey: UUID().uuidString,
                reasonCode: "educator-launch"
            )
            session.activate(
                grant,
                profile: StudentModeProfile(
                    studentID: student.id,
                    displayName: student.displayName,
                    grade: student.grade,
                    pronouns: student.pronouns
                )
            )
            dismiss()
        } catch StudentModeRepositoryError.cancelled {
            return
        } catch StudentModeRepositoryError.authenticationRequired {
            errorMessage = "Your staff session must be verified again."
        } catch StudentModeRepositoryError.conflict {
            errorMessage = "The student or assignment changed. Refresh and try again."
        } catch StudentModeRepositoryError.validation {
            errorMessage = "The selected assignment is not eligible for Student Mode."
        } catch StudentModeRepositoryError.unavailable {
            errorMessage = "A connection is required to launch Student Mode."
        } catch {
            errorMessage = "The secure session could not be started."
        }
    }
}
