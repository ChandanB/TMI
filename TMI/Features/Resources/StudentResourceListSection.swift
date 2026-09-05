import SwiftUI

/// Renders the resources assigned to a student, plus an "Add from library"
/// affordance to assign more. There is no unassign/remove action here —
/// `ResourceRepository` does not expose one yet.
struct StudentResourceListSection: View {
    let studentID: String
    let member: MembershipContext
    let repository: any ResourceRepository

    @State private var model: StudentResourcesSectionModel
    @State private var showingLibrary = false

    init(studentID: String, member: MembershipContext, repository: any ResourceRepository) {
        self.studentID = studentID
        self.member = member
        self.repository = repository
        _model = State(initialValue: StudentResourcesSectionModel(repository: repository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Assigned resources")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Add from library", systemImage: "plus.circle") {
                    showingLibrary = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("studentResources.addFromLibrary")
            }

            if let errorMessage = model.errorMessage {
                ContentUnavailableView(
                    "Resources unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                Button("Try Again") {
                    Task { await model.load(studentID: studentID, member: member) }
                }
                .buttonStyle(.bordered)
            } else if model.assigned.isEmpty, !model.isLoading {
                ContentUnavailableView(
                    "No resources assigned",
                    systemImage: "books.vertical",
                    description: Text("Add a resource from the library to share it with this student.")
                )
                .accessibilityIdentifier("studentResources.empty")
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: TMISpacing.md)],
                    spacing: TMISpacing.md
                ) {
                    ForEach(model.assigned) { resource in
                        ResourceCard(resource: resource)
                    }
                }
                .accessibilityIdentifier("studentResources.assigned")
            }
        }
        .task {
            await model.load(studentID: studentID, member: member)
        }
        .sheet(isPresented: $showingLibrary) {
            NavigationStack {
                libraryPicker
                    .navigationTitle("Add a resource")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingLibrary = false }
                        }
                    }
            }
        }
    }

    private var assignedResourceIDs: Set<String> {
        Set(model.assigned.compactMap(\.id))
    }

    @ViewBuilder
    private var libraryPicker: some View {
        let available = model.library.filter { resource in
            guard let id = resource.id else { return false }
            return !assignedResourceIDs.contains(id)
        }

        if available.isEmpty {
            ContentUnavailableView(
                "Nothing to add",
                systemImage: "checkmark.circle",
                description: Text("Every library resource is already assigned to this student.")
            )
        } else {
            List(available) { resource in
                Button {
                    Task {
                        guard let resourceID = resource.id else { return }
                        await model.assignFromLibrary(
                            resourceID: resourceID,
                            studentID: studentID,
                            member: member
                        )
                        showingLibrary = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                        Text(resource.title)
                            .font(.headline)
                        Text(resource.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .accessibilityIdentifier("studentResources.library.\(resource.id ?? resource.title)")
            }
        }
    }
}
