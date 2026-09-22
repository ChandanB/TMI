import SwiftUI

/// Forms assigned to one student, in the student's own record: assign,
/// complete, and review without leaving the student's context.
struct StudentFormsSection: View {
    let districtID: String
    let studentID: String
    let studentName: String
    var repository: (any FormResponseRepository)? = nil

    @State private var forms: [StudentFormSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var openForm: StudentFormSummary?
    @State private var isAssigning = false

    private var resolvedRepository: any FormResponseRepository {
        repository ?? FirebaseFormResponseRepository()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Forms")
                    .font(.headline)
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                Button("Assign a form", systemImage: "plus") { isAssigning = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("studentForms.assign")
            }

            if let errorMessage {
                ContentUnavailableView(
                    "Forms unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                Button("Try again") { Task { await load() } }
                    .buttonStyle(.bordered)
            } else if forms.isEmpty, !isLoading {
                ContentUnavailableView(
                    "No forms assigned",
                    systemImage: "list.clipboard",
                    description: Text("Assign a form to \(studentName) to collect information from staff, the family, or the student.")
                )
            } else {
                ForEach(forms) { form in
                    Button {
                        openForm = form
                    } label: {
                        StudentFormRow(form: form)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("studentForms.form.\(form.assignmentID)")
                }
            }
        }
        .task(id: "\(districtID)/\(studentID)") { await load() }
        .sheet(item: $openForm, onDismiss: { Task { await load() } }) { form in
            FormResponseView(
                districtID: districtID,
                studentID: studentID,
                studentName: studentName,
                summary: form,
                repository: resolvedRepository
            )
        }
        .sheet(isPresented: $isAssigning, onDismiss: { Task { await load() } }) {
            AssignmentCreationView(preselectedStudentIDs: [studentID])
                .tmiSheetStyle()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            forms = try await resolvedRepository.forms(districtID: districtID, studentID: studentID)
            errorMessage = nil
        } catch {
            errorMessage = FormResponseError.map(error).localizedDescription
        }
    }
}

private struct StudentFormRow: View {
    let form: StudentFormSummary

    var body: some View {
        HStack(alignment: .top, spacing: TMISpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                Text(form.templateName)
                    .font(.headline)
                    .foregroundStyle(TMIColors.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(form.isOverdue() ? TMIColors.errorText : TMIColors.textSecondary)
            }
            Spacer()
            Text(form.isOverdue() ? "Overdue" : form.state.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, TMISpacing.sm)
                .padding(.vertical, TMISpacing.xxs)
                .foregroundStyle(tint)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .padding(TMISpacing.md)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.md))
        .overlay { RoundedRectangle(cornerRadius: TMIRadius.md).stroke(TMIColors.border, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        switch form.state {
        case .submitted where form.requiresReview: "Submitted — awaiting review"
        case .submitted, .reviewed:
            form.submittedAt.flatMap(FormDates.parse).map { "Submitted \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Submitted"
        case .notStarted, .draft:
            form.due.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "No due date"
        }
    }

    private var icon: String {
        switch form.state {
        case .notStarted: "doc"
        case .draft: "doc.badge.ellipsis"
        case .submitted: "checkmark.circle"
        case .reviewed: "checkmark.seal.fill"
        }
    }

    private var tint: Color {
        if form.isOverdue() { return TMIColors.errorText }
        switch form.state {
        case .notStarted, .draft: return TMIColors.infoText
        case .submitted: return TMIColors.warningText
        case .reviewed: return TMIColors.successText
        }
    }
}
