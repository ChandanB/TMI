import SwiftUI

/// Workspace-wide search across the students, plans, resources, and careers
/// the signed-in member can open. Results are filtered on the server, so a
/// hit is always something the member is allowed to see.
struct GlobalSearchView: View {
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.programContext) private var programContext
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var repository: (any CollaborationRepository)? = nil
    /// Set when search is hosted as a tab: called after navigating to a hit
    /// (instead of dismissing a sheet) so the shell can leave the Search tab.
    var onOpen: (() -> Void)? = nil

    @State private var query = ""
    @State private var results: WorkspaceSearchResults = .empty
    @State private var isSearching = false
    @State private var errorMessage: String?

    private var resolved: any CollaborationRepository { repository ?? FirebaseCollaborationRepository() }
    private var terminology: Terminology { programContext.shell.terminology }
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                if trimmed.count < 2 {
                    ContentUnavailableView(
                        "Search your workspace",
                        systemImage: "magnifyingglass",
                        description: Text("Find \(terminology.learners.lowercased()), plans, resources\(programContext.shell.showsCareers ? ", and careers" : "") you have access to.")
                    )
                } else if let errorMessage {
                    ContentUnavailableView("Search unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if results.isEmpty, !isSearching {
                    ContentUnavailableView.search(text: trimmed)
                }
                group(terminology.learners, systemImage: "person.fill", hits: results.students) { hit in
                    open { try router.open(.student(hit.id)) }
                }
                group("Plans", systemImage: "doc.text.fill", hits: results.plans) { hit in
                    open { try router.open(.plan(hit.id)) }
                }
                group("Resources", systemImage: "book.fill", hits: results.resources) { hit in
                    if let url = hit.url.flatMap(URL.init(string:)) {
                        openURL(url)
                    }
                }
                if programContext.shell.showsCareers {
                    group("Careers", systemImage: "briefcase.fill", hits: results.careers, action: nil)
                }
            }
            .overlay { if isSearching && results.isEmpty { ProgressView() } }
            .searchable(text: $query, placement: .automatic, prompt: "Search")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onOpen == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
            }
            .task(id: trimmed) { await search() }
        }
        .tmiSheetStyle()
    }

    @ViewBuilder
    private func group(_ title: String, systemImage: String, hits: [SearchHit], action: ((SearchHit) -> Void)?) -> some View {
        if !hits.isEmpty {
            Section(title) {
                ForEach(hits) { hit in
                    Button {
                        action?(hit)
                    } label: {
                        HStack {
                            Image(systemName: systemImage)
                                .foregroundStyle(TMIColors.accent)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading) {
                                Text(hit.title).foregroundStyle(TMIColors.textPrimary)
                                if !subtitle(for: hit).isEmpty {
                                    Text(subtitle(for: hit)).font(.caption).foregroundStyle(TMIColors.textSecondary)
                                }
                            }
                        }
                    }
                    .disabled(action == nil)
                }
            }
        }
    }

    private func subtitle(for hit: SearchHit) -> String {
        if let schoolID = hit.schoolID, !schoolID.isEmpty {
            return [terminology.gradeDescription(hit.subtitle), programContext.siteName(schoolID)]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
        return hit.subtitle
    }

    private func open(_ navigate: () throws -> Void) {
        do {
            try navigate()
            if let onOpen {
                onOpen()
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "You don't have access to open that record."
        }
    }

    private func search() async {
        guard trimmed.count >= 2, let member = authStateModel.currentMembership else {
            results = .empty
            return
        }
        // Debounce typing; the task is cancelled when the query changes.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await resolved.search(districtID: member.districtID, query: trimmed, includeCareers: programContext.shell.showsCareers)
            guard !Task.isCancelled else { return }
            results = found
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = CollaborationError.map(error).localizedDescription
        }
    }
}
