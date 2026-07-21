//
//  StudentResourcesSection.swift
//  TMI
//
//  Accordion section for inline resource management on a student profile.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - StudentResourcesSection

struct StudentResourcesSection: View {
    @Binding var selectedResources: [Resource]

    @State private var searchText: String = ""
    @State private var availableResources: [Resource] = []
    @State private var isLoading = false
    @State private var showingAddForm = false
    @State private var errorMessage: String?

    // MARK: Computed helpers

    private var filteredAvailable: [Resource] {
        let unselected = availableResources.filter { resource in
            !selectedResources.contains(resource)
        }
        guard !searchText.isEmpty else { return unselected }
        let query = searchText.lowercased()
        return unselected.filter {
            $0.title.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            selectedResourcesList
            Divider()
            availableResourcesList
        }
        .task {
            await loadResources()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("Search resources…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .autocorrectionDisabled()

            Spacer()

            Button {
                showingAddForm = true
            } label: {
                Label("New", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Selected Resources

    @ViewBuilder
    private var selectedResourcesList: some View {
        if selectedResources.isEmpty {
            Text("No resources selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 8) {
                ForEach(selectedResources) { resource in
                    ResourceRow(resource: resource, actionLabel: "Remove", actionSystemImage: "minus.circle.fill") {
                        removeResource(resource)
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
                Text("No resources found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(filteredAvailable) { resource in
                    ResourceRow(resource: resource, actionLabel: "Add", actionSystemImage: "plus.circle.fill") {
                        addResource(resource)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addResource(_ resource: Resource) {
        guard !selectedResources.contains(resource) else { return }
        withAnimation(.spring(response: 0.3)) {
            selectedResources.append(resource)
        }
    }

    private func removeResource(_ resource: Resource) {
        withAnimation(.spring(response: 0.3)) {
            selectedResources.removeAll { $0 == resource }
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

            // Fall back to sample data when the user collection is empty
            availableResources = fetched.isEmpty ? Resource.sampleResources : fetched
        } catch {
            errorMessage = "Could not load resources."
            availableResources = Resource.sampleResources
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selected: [Resource] = [Resource.sampleResources[0]]

    StudentResourcesSection(selectedResources: $selected)
        .padding()
}
