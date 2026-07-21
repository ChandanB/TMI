// PlanResourcesSection.swift
// TMI
//
// Accordion section for linking resources to a TMI Plan.
// Loads available resources from the authenticated user's Firebase collection.

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - PlanResourcesSection

/// Accordion-style section for viewing and editing the resources linked to a TMI plan.
/// Loads the user's resource library from Firebase and allows inline add/remove.
struct PlanResourcesSection: View {
    @Binding var linkedResources: [Resource]
    var students: [Student]

    // MARK: State

    @State private var searchText: String = ""
    @State private var availableResources: [Resource] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // MARK: Computed

    private var filteredAvailable: [Resource] {
        let unlinked = availableResources.filter { !linkedResources.contains($0) }
        guard !searchText.isEmpty else { return unlinked }
        let query = searchText.lowercased()
        return unlinked.filter {
            $0.title.lowercased().contains(query) ||
            $0.description.lowercased().contains(query)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optional for MVP: add a resource only if it directly supports the student's next step.")
                .font(.caption)
                .foregroundStyle(.secondary)

            searchBar
            linkedResourcesList
            Divider()
            availableResourcesList
        }
        .task {
            await loadResources()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("Search resources…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Linked Resources

    @ViewBuilder
    private var linkedResourcesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked to Plan")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if linkedResources.isEmpty {
                Text("No resources linked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(linkedResources) { resource in
                    ResourceRow(resource: resource, actionLabel: "Remove", actionSystemImage: "minus.circle.fill") {
                        unlinkResource(resource)
                    }
                }
            }
        }
    }

    // MARK: - Available Resources

    @ViewBuilder
    private var availableResourcesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Resources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            } else if filteredAvailable.isEmpty {
                Text(
                    searchText.isEmpty
                        ? "No additional resources found."
                        : "No matches for \"\(searchText)\"."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                ForEach(filteredAvailable) { resource in
                    ResourceRow(resource: resource, actionLabel: "Add", actionSystemImage: "plus.circle.fill") {
                        linkResource(resource)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func linkResource(_ resource: Resource) {
        guard !linkedResources.contains(resource) else { return }
        withAnimation(.spring(response: 0.3)) {
            linkedResources.append(resource)
        }
    }

    private func unlinkResource(_ resource: Resource) {
        withAnimation(.spring(response: 0.3)) {
            linkedResources.removeAll { $0 == resource }
        }
    }

    // MARK: - Firebase Loading

    @MainActor
    private func loadResources() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let uid = Auth.auth().currentUser?.uid else {
            availableResources = Resource.sampleResources
            return
        }

        do {
            let db = FirebaseManager.shared.firestore
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("resources")
                .getDocuments()

            let fetched = snapshot.documents.compactMap { doc -> Resource? in
                try? doc.decodedModel(as: Resource.self, assigningDocumentIDTo: \.id)
            }
            availableResources = fetched.isEmpty ? Resource.sampleResources : fetched
        } catch {
            errorMessage = "Could not load resources."
            availableResources = Resource.sampleResources
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var linked: [Resource] = []
    return ScrollView {
        PlanResourcesSection(linkedResources: $linked, students: [])
            .padding()
    }
}
