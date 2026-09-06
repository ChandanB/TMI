import SwiftUI

/// Renders the resources linked to a plan, plus an "Add from library"
/// affordance to link more. There is no unlink/remove action here —
/// `ResourceRepository` does not expose one yet.
struct PlanResourceListSection: View {
    let planID: String
    let member: MembershipContext
    let repository: any ResourceRepository
    let canLink: Bool

    @State private var model: PlanResourcesSectionModel
    @State private var showingLibrary = false

    init(
        planID: String,
        member: MembershipContext,
        repository: any ResourceRepository,
        canLink: Bool
    ) {
        self.planID = planID
        self.member = member
        self.repository = repository
        self.canLink = canLink
        _model = State(initialValue: PlanResourcesSectionModel(repository: repository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Linked resources")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                if canLink {
                    Button("Add from library", systemImage: "plus.circle") {
                        showingLibrary = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("planResources.addFromLibrary")
                }
            }

            if !canLink {
                Text("Resources can be linked while the plan is in draft.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                ContentUnavailableView(
                    "Resources unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                Button("Try Again") {
                    Task { await model.load(planID: planID, member: member) }
                }
                .buttonStyle(.bordered)
            } else if model.linked.isEmpty, !model.isLoading {
                ContentUnavailableView(
                    "No resources linked",
                    systemImage: "books.vertical",
                    description: Text(canLink
                        ? "Add a resource from the library to share it with this plan."
                        : "No resources were linked before this plan left draft status.")
                )
                .accessibilityIdentifier("planResources.empty")
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: TMISpacing.md)],
                    spacing: TMISpacing.md
                ) {
                    ForEach(model.linked) { resource in
                        ResourceCard(resource: resource)
                    }
                }
                .accessibilityIdentifier("planResources.linked")
            }
        }
        .task {
            await model.load(planID: planID, member: member)
        }
        .onChange(of: canLink) { _, allowed in
            if !allowed { self.showingLibrary = false }
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

    private var linkedResourceIDs: Set<String> {
        Set(model.linked.compactMap(\.id))
    }

    @ViewBuilder
    private var libraryPicker: some View {
        let available = model.library.filter { resource in
            guard let id = resource.id else { return false }
            return !linkedResourceIDs.contains(id)
        }

        if available.isEmpty {
            ContentUnavailableView(
                "Nothing to add",
                systemImage: "checkmark.circle",
                description: Text("Every library resource is already linked to this plan.")
            )
        } else {
            List(available) { resource in
                Button {
                    Task {
                        guard self.canLink, let resourceID = resource.id else { return }
                        await model.linkFromLibrary(
                            resourceID: resourceID,
                            planID: planID,
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
                .disabled(!canLink || model.isLoading)
                .accessibilityIdentifier("planResources.library.\(resource.id ?? resource.title)")
            }
        }
    }
}
