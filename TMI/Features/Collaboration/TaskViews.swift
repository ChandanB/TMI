import SwiftUI

/// Follow-up tasks linked to one student.
struct StudentTasksSection: View {
    let districtID: String
    let studentID: String
    let studentName: String
    let member: MembershipContext?
    var repository: (any CollaborationRepository)? = nil

    @Environment(\.syncCoordinator) private var sync
    @State private var tasks: [FollowUpTask] = []
    @State private var showClosed = false
    @State private var isCreating = false
    @State private var completing: FollowUpTask?
    @State private var errorMessage: String?

    private var resolved: any CollaborationRepository { repository ?? FirebaseCollaborationRepository() }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Follow-up tasks").font(.headline)
                Spacer()
                Button("Add task", systemImage: "checklist") { isCreating = true }
                    .buttonStyle(.bordered)
                    .disabled(member == nil)
                    .accessibilityIdentifier("studentTasks.add")
            }
            Toggle("Show completed", isOn: $showClosed)
                .font(.subheadline)
            PendingSyncList(prefixes: [SyncAggregate.newTask(studentID: studentID)] + tasks.map { SyncAggregate.task($0.taskID) })
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText)
            } else if tasks.isEmpty {
                Text("No \(showClosed ? "" : "open ")tasks for \(studentName).")
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.textSecondary)
            }
            ForEach(tasks) { task in
                TaskRow(task: task, currentUserID: member?.userID) { completing = task }
            }
        }
        .task(id: "\(studentID)-\(showClosed)") { await load() }
        .sheet(isPresented: $isCreating) {
            TaskEditorSheet(
                districtID: districtID,
                studentID: studentID,
                currentUserID: member?.userID ?? "",
                repository: resolved
            ) { await load() }
        }
        .sheet(item: $completing) { task in
            TaskCompletionSheet(task: task) { status, outcome in
                let result = try await sync.updateTask(task, districtID: districtID, status: status, outcome: outcome, repository: resolved)
                if result == .sent { await load() }
            }
        }
    }

    private func load() async {
        do {
            tasks = try await resolved.tasks(districtID: districtID, studentID: studentID, includeClosed: showClosed)
            errorMessage = nil
        } catch {
            errorMessage = CollaborationError.map(error).localizedDescription
        }
    }
}

/// Everything assigned to or created by the signed-in staff member.
struct TaskListView: View {
    @Environment(\.authStateModel) private var authStateModel
    @Environment(AppRouter.self) private var router
    var repository: (any CollaborationRepository)? = nil
    var memberOverride: MembershipContext? = nil

    @State private var tasks: [FollowUpTask] = []
    @State private var showClosed = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var completing: FollowUpTask?
    @Environment(\.syncCoordinator) private var sync

    private var resolved: any CollaborationRepository { repository ?? FirebaseCollaborationRepository() }
    private var member: MembershipContext? { memberOverride ?? authStateModel.currentMembership }

    private var overdue: [FollowUpTask] { tasks.filter(\.isOverdue) }
    private var upcoming: [FollowUpTask] { tasks.filter { $0.status == .open && !$0.isOverdue } }
    private var closed: [FollowUpTask] { tasks.filter { $0.status != .open } }

    var body: some View {
        List {
            Toggle("Show completed", isOn: $showClosed)
            PendingSyncList(prefixes: ["task-new:"] + tasks.map { SyncAggregate.task($0.taskID) })
            if let errorMessage {
                ContentUnavailableView("Tasks unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if tasks.isEmpty, !isLoading {
                ContentUnavailableView("No tasks", systemImage: "checkmark.circle", description: Text("Follow-ups assigned to you or created by you appear here."))
            }
            if !overdue.isEmpty {
                Section("Overdue") { rows(overdue) }
            }
            if !upcoming.isEmpty {
                Section("Open") { rows(upcoming) }
            }
            if showClosed, !closed.isEmpty {
                Section("Completed") { rows(closed) }
            }
        }
        .navigationTitle("My tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isCreating = true } label: { Label("New task", systemImage: "plus") }
                    .disabled(member == nil)
            }
        }
        .overlay { if isLoading && tasks.isEmpty { ProgressView() } }
        .task(id: showClosed) { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $isCreating) {
            if let member {
                TaskEditorSheet(districtID: member.districtID, studentID: nil, currentUserID: member.userID, repository: resolved) { await load() }
            }
        }
        .sheet(item: $completing) { task in
            TaskCompletionSheet(task: task) { status, outcome in
                if let member {
                    let result = try await sync.updateTask(task, districtID: member.districtID, status: status, outcome: outcome, repository: resolved)
                    if result == .sent { await load() }
                }
            }
        }
    }

    private func rows(_ tasks: [FollowUpTask]) -> some View {
        ForEach(tasks) { task in
            TaskRow(task: task, currentUserID: member?.userID) { completing = task }
                .contextMenu {
                    if let studentID = task.studentID {
                        Button("Open student", systemImage: "person.crop.circle") {
                            try? router.open(.student(studentID))
                        }
                    }
                }
        }
    }

    private func load() async {
        guard let member else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            tasks = try await resolved.tasks(districtID: member.districtID, studentID: nil, includeClosed: showClosed)
            errorMessage = nil
        } catch {
            errorMessage = CollaborationError.map(error).localizedDescription
        }
    }
}

struct TaskRow: View {
    let task: FollowUpTask
    let currentUserID: String?
    let onUpdate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: TMISpacing.md) {
            Button(action: onUpdate) {
                Image(systemName: task.status == .open ? "circle" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(task.status == .open ? TMIColors.textSecondary : TMIColors.successText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.status == .open ? "Update task" : "Completed")
            VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.status != .open)
                if let details = task.details { Text(details).font(.subheadline).foregroundStyle(TMIColors.textSecondary) }
                HStack(spacing: TMISpacing.sm) {
                    if let due = task.due {
                        Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .foregroundStyle(task.isOverdue ? TMIColors.errorText : TMIColors.textSecondary)
                    }
                    if task.assigneeUserID != currentUserID {
                        Label("Assigned to a colleague", systemImage: "person")
                            .foregroundStyle(TMIColors.textSecondary)
                    }
                }
                .font(.caption)
                if let outcome = task.outcome {
                    Text("Outcome: \(outcome)").font(.caption).foregroundStyle(TMIColors.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TaskEditorSheet: View {
    let districtID: String
    let studentID: String?
    let currentUserID: String
    let repository: any CollaborationRepository
    let onCreated: @MainActor () async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncCoordinator) private var sync
    @State private var draft = TaskDraft()
    @State private var colleagues: [Colleague] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to happen?", text: $draft.title)
                        .accessibilityIdentifier("taskEditor.title")
                    TextField("Details (optional)", text: $draft.details, axis: .vertical).lineLimit(2...5)
                }
                Section("Owner") {
                    Picker("Assigned to", selection: $draft.assigneeUserID) {
                        ForEach(colleagues) { colleague in
                            Text(colleague.isSelf ? "Me" : colleague.displayName).tag(colleague.userID)
                        }
                    }
                }
                Section {
                    Toggle("Due date", isOn: $draft.hasDueDate)
                    if draft.hasDueDate {
                        DatePicker("Due", selection: $draft.dueDate, in: Date.now..., displayedComponents: .date)
                    }
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Create") {
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            do {
                                let payload = CreateTaskSyncPayload(districtID: districtID, draft: draft)
                                let result = try await sync.perform(
                                    .createTask,
                                    aggregateKey: SyncAggregate.newTask(studentID: draft.studentID),
                                    summary: "New task: \(draft.title.prefix(60))",
                                    districtID: districtID,
                                    payload: payload
                                ) { operationID in
                                    try await repository.createTask(districtID: payload.districtID, draft: payload.draft, operationID: operationID)
                                }
                                if result == .sent { await onCreated() }
                                dismiss()
                            } catch {
                                errorMessage = CollaborationError.map(error).localizedDescription
                            }
                        }
                    }
                    .disabled(isSaving || !draft.isValid)
                }
            }
            .task {
                draft.studentID = studentID
                draft.assigneeUserID = currentUserID
                colleagues = (try? await repository.colleagues(districtID: districtID, studentID: studentID)) ?? []
                if !colleagues.contains(where: { $0.userID == currentUserID }) {
                    colleagues.insert(Colleague(userID: currentUserID, displayName: "Me", role: "", isSelf: true), at: 0)
                }
            }
        }
        .tmiSheetStyle()
    }
}

struct TaskCompletionSheet: View {
    let task: FollowUpTask
    let onSave: @MainActor (TaskStatus, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status: TaskStatus = .done
    @State private var outcome = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(task.title) {
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("What happened? (recorded outcome)", text: $outcome, axis: .vertical).lineLimit(2...6)
                } footer: {
                    Text("Recording the outcome closes the loop on the decision that created this task.")
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TMIColors.errorText) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Update task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            do {
                                try await onSave(status, outcome)
                                dismiss()
                            } catch {
                                errorMessage = CollaborationError.map(error).localizedDescription
                            }
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                status = task.status == .open ? .done : task.status
                outcome = task.outcome ?? ""
            }
        }
        .tmiSheetStyle()
    }
}
