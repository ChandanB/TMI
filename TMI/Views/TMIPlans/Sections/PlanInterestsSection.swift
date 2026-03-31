// PlanInterestsSection.swift
// TMI
//
// Accordion section for linking interests to a TMI Plan.
// Pulls interest suggestions from the associated students' edge collections.

import SwiftUI
import FirebaseFirestore

// MARK: - PlanInterestsSection

/// Accordion-style section for viewing and editing the interests linked to a TMI plan.
/// Suggests interests from the plan's associated students and allows inline management.
struct PlanInterestsSection: View {
    @Binding var linkedInterests: [Interest]
    var students: [Student]

    // MARK: State

    @State private var searchText: String = ""
    @State private var studentInterests: [Interest] = []
    @State private var isLoadingStudentInterests: Bool = false
    @State private var loadError: String?
    @State private var showNewInterestSheet: Bool = false
    @State private var newInterestName: String = ""
    @State private var isCreating: Bool = false

    // MARK: Computed

    private var filteredLinked: [Interest] {
        guard !searchText.isEmpty else { return linkedInterests }
        return linkedInterests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSuggestions: [Interest] {
        let linkedIDs = Set(linkedInterests.compactMap { $0.id })
        let linkedNames = Set(linkedInterests.map { $0.name.lowercased() })
        let unlinked = studentInterests.filter { interest in
            guard let id = interest.id else {
                return !linkedNames.contains(interest.name.lowercased())
            }
            return !linkedIDs.contains(id)
        }
        guard !searchText.isEmpty else { return unlinked }
        return unlinked.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                .buttonStyle(.plain)
            }

            // Linked interests
            if !filteredLinked.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Linked to Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    FlowLayout(spacing: 8) {
                        ForEach(filteredLinked, id: \.id) { interest in
                            InterestChip(interest: interest, isSelected: true) {
                                unlinkInterest(interest)
                            }
                        }
                    }
                }
            }

            // Suggestions from students' profiles
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("From Students' Profiles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    if isLoadingStudentInterests {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if let error = loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else if filteredSuggestions.isEmpty && !isLoadingStudentInterests {
                    Text(
                        students.isEmpty
                            ? "Add students to this plan to see interest suggestions."
                            : searchText.isEmpty
                                ? "No additional interests found on linked students."
                                : "No matches for \"\(searchText)\"."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(filteredSuggestions, id: \.id) { interest in
                            InterestChip(interest: interest, isSelected: false) {
                                linkInterest(interest)
                            }
                        }
                    }
                }
            }
        }
        .task(id: students.map { $0.id }.description) {
            await loadStudentInterests()
        }
        .sheet(isPresented: $showNewInterestSheet) {
            newInterestSheetView
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
            .navigationTitle("New Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewInterestSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await createAndLinkInterest() }
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

    private func linkInterest(_ interest: Interest) {
        guard !linkedInterests.contains(interest) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            linkedInterests.append(interest)
        }
    }

    private func unlinkInterest(_ interest: Interest) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            linkedInterests.removeAll { $0 == interest }
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadStudentInterests() async {
        guard !students.isEmpty else {
            studentInterests = []
            return
        }

        isLoadingStudentInterests = true
        loadError = nil
        defer { isLoadingStudentInterests = false }

        do {
            var fetched: [Interest] = []
            var seenIDs = Set<String>()
            var seenNames = Set<String>()

            for student in students {
                let interests = try await student.fetchInterestsFromEdgeCollection()
                for interest in interests {
                    let key = interest.id ?? ""
                    let nameLower = interest.name.lowercased()
                    if !key.isEmpty {
                        if seenIDs.insert(key).inserted {
                            fetched.append(interest)
                            seenNames.insert(nameLower)
                        }
                    } else if seenNames.insert(nameLower).inserted {
                        fetched.append(interest)
                    }
                }
            }
            studentInterests = fetched
        } catch {
            loadError = "Could not load student interests: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func createAndLinkInterest() async {
        let trimmed = newInterestName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }

        isCreating = true
        defer { isCreating = false }

        let newInterest = Interest(name: trimmed, category: [.other])

        do {
            let db = FirebaseManager.shared.firestore
            let ref = db
                .collection("users")
                .document(uid)
                .collection("interests")
                .document()
            try ref.setData(from: newInterest)
            newInterest.id = ref.documentID
        } catch {
            // Continue without persistence — link locally only
        }

        linkInterest(newInterest)
        newInterestName = ""
        showNewInterestSheet = false
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var linked: [Interest] = [
        Interest(name: "Robotics", category: [.technology])
    ]
    return ScrollView {
        PlanInterestsSection(linkedInterests: $linked, students: [])
            .padding()
    }
}
