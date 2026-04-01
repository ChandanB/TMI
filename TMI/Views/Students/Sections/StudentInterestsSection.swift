// StudentInterestsSection.swift
// TMI
//
// Accordion section for managing a student's interests within the student profile view.

import SwiftUI
import FirebaseFirestore

// MARK: - StudentInterestsSection

/// Accordion-style section for viewing and editing a student's interests.
/// Displays selected interests as removable pink chips and loads available
/// interests from Firebase for the authenticated user.
struct StudentInterestsSection: View {
    @Binding var selectedInterests: [Interest]

    // MARK: State

    @State private var searchText: String = ""
    @State private var availableInterests: [Interest] = []
    @State private var isLoadingAvailable: Bool = false
    @State private var loadError: String? = nil
    @State private var showNewInterestSheet: Bool = false
    @State private var newInterestName: String = ""
    @State private var isCreating: Bool = false

    // MARK: Computed

    private var filteredSelected: [Interest] {
        guard !searchText.isEmpty else { return selectedInterests }
        return selectedInterests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredAvailable: [Interest] {
        let selectedIDs = Set(selectedInterests.compactMap { $0.id })
        let selectedNames = Set(selectedInterests.map { $0.name.lowercased() })
        let unselected = availableInterests.filter { interest in
            guard let id = interest.id else {
                return !selectedNames.contains(interest.name.lowercased())
            }
            return !selectedIDs.contains(id)
        }
        guard !searchText.isEmpty else { return unselected }
        return unselected.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search bar + New button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search interests…", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            // Filtering is reactive via searchText binding — just dismiss keyboard
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    newInterestName = searchText
                    showNewInterestSheet = true
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.pink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Selected interests
            if !filteredSelected.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    FlowLayout(spacing: 8) {
                        ForEach(filteredSelected, id: \.id) { interest in
                            InterestChip(interest: interest, isSelected: true) {
                                removeInterest(interest)
                            }
                        }
                    }
                }
            }

            // Available interests
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Suggested")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    if isLoadingAvailable {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if let error = loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else if filteredAvailable.isEmpty && !isLoadingAvailable {
                    Text(searchText.isEmpty ? "No additional interests found." : "No matches for \"\(searchText)\".")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(filteredAvailable, id: \.id) { interest in
                            InterestChip(interest: interest, isSelected: false) {
                                addInterest(interest)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadAvailableInterests()
        }
        .sheet(isPresented: $showNewInterestSheet) {
            newInterestSheetView
                .tmiSheetStyle()
        }
    }

    // MARK: - New Interest Sheet

    private var newInterestSheetView: some View {
        NavigationStack {
            Form {
                Section("Interest name") {
                    TextField("e.g. Robotics", text: $newInterestName)
                        .textInputAutocapitalization(.words)
                }
            }
            .padding(.horizontal)
            .navigationTitle("New Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewInterestSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await createAndAddInterest() }
                    }
                    .disabled(newInterestName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ProgressView("Creating…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Actions

    private func addInterest(_ interest: Interest) {
        guard !selectedInterests.contains(interest) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedInterests.append(interest)
        }
    }

    private func removeInterest(_ interest: Interest) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedInterests.removeAll { $0 == interest }
        }
    }

    // MARK: - Firebase

    @MainActor
    private func loadAvailableInterests() async {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            loadError = "Not signed in."
            return
        }

        isLoadingAvailable = true
        loadError = nil
        defer { isLoadingAvailable = false }

        do {
            let db = FirebaseManager.shared.firestore
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("interests")
                .getDocuments()

            let fetched: [Interest] = snapshot.documents.compactMap { doc in
                try? doc.data(as: Interest.self)
            }
            availableInterests = fetched
        } catch {
            loadError = "Could not load interests: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func createAndAddInterest() async {
        let trimmed = newInterestName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }

        isCreating = true
        defer { isCreating = false }

        let newInterest = Interest(
            name: trimmed,
            category: [.other]
        )

        do {
            let db = FirebaseManager.shared.firestore
            let ref = db
                .collection("users")
                .document(uid)
                .collection("interests")
                .document()

            try ref.setData(from: newInterest)

            // Assign the Firestore-generated ID back so chips are stable
            newInterest.id = ref.documentID
            availableInterests.append(newInterest)
            addInterest(newInterest)
        } catch {
            // Fallback: add locally without persisting
            addInterest(newInterest)
        }

        newInterestName = ""
        showNewInterestSheet = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selected: [Interest] = [
        Interest(name: "Robotics", category: [.technology]),
        Interest(name: "Soccer", category: [.sports])
    ]

    return ScrollView {
        StudentInterestsSection(selectedInterests: $selected)
            .padding()
    }
}
