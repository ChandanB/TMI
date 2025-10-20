//
//  TMIPlanListViewRedesigned.swift
//  TMI
//
//  Unified TMI plans list with contextual information
//

import SwiftUI

struct TMIPlanListViewRedesigned: View {
    @State private var stateModel = TMIPlanListStateModel()
    @State private var selectedTab: PlanTab = .active
    @State private var searchText = ""
    @State private var showingNewPlan = false
    @State private var planToDelete: TMIPlan? = nil
    @State private var showingDeleteConfirmation = false

    enum PlanTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
    }

    var filteredPlans: [TMIPlan] {
        var plans = stateModel.plans

        // Filter by status
        switch selectedTab {
        case .active:
            plans = plans.filter { $0.endDate == nil || $0.endDate! > Date() }
        case .completed:
            plans = plans.filter { $0.endDate != nil && $0.endDate! <= Date() }
        }

        // Apply search
        if !searchText.isEmpty {
            plans = plans.filter { plan in
                plan.title.localizedCaseInsensitiveContains(searchText) ||
                plan.students.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return plans.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.tmiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab Selector
                tabSelector
                    .padding(.horizontal, TMISpacing.screenPadding)
                    .padding(.top, TMISpacing.sm)

                // Search Bar
                TMISearchBarRedesigned(text: $searchText, placeholder: "Search plans...")
                    .padding(.horizontal, TMISpacing.screenPadding)
                    .padding(.top, TMISpacing.md)

                // Plans List
                Group {
                    switch stateModel.state {
                    case .idle, .loading:
                        loadingView
                    case .loaded:
                        if filteredPlans.isEmpty {
                            emptyStateView
                        } else {
                            plansList
                        }
                    case .error(let error):
                        errorView(error)
                    }
                }
            }

            // FAB for New Plan
            TMIFAB(
                icon: "plus",
                label: "New Plan",
                action: { showingNewPlan = true }
            )
            .padding(TMISpacing.md)
        }
        .navigationTitle("TMI Plans")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingNewPlan) {
            NavigationStack {
                newPlanSelector
            }
        }
        .task {
            await stateModel.fetch()
        }
        .refreshable {
            await stateModel.fetch()
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: TMISpacing.sm) {
            ForEach(PlanTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.sm)
    }

    private func tabButton(_ tab: PlanTab) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = tab
            }
        }) {
            Text(tab.rawValue)
                .font(.tmiCaption)
                .foregroundColor(selectedTab == tab ? .white : .tmiTextSecondary)
                .padding(.horizontal, TMISpacing.md)
                .padding(.vertical, TMISpacing.sm)
                .frame(maxWidth: .infinity)
                .background(selectedTab == tab ? Color.tmiPrimary : Color.clear)
                .cornerRadius(TMIRadius.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plans List

    private var plansList: some View {
        List {
            ForEach(filteredPlans) { plan in
                NavigationLink(destination: TMIPlanDetailView(plan: plan)) {
                    planRow(plan)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: TMISpacing.screenPadding, bottom: 4, trailing: TMISpacing.screenPadding))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Delete action
                    Button(role: .destructive) {
                        planToDelete = plan
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    // View Students action
                    Button {
                        // Navigate to first student in plan
                        TMIHaptics.lightImpact()
                    } label: {
                        Label("Students", systemImage: "person.2")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .alert("Delete Plan", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let plan = planToDelete {
                    Task {
                        TMIHaptics.mediumImpact()
                        _ = await stateModel.deletePlan(plan)
                        planToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                planToDelete = nil
            }
        } message: {
            if let plan = planToDelete {
                Text("Are you sure you want to delete the plan \"\(plan.title)\"? This action cannot be undone.")
            }
        }
    }

    private func planRow(_ plan: TMIPlan) -> some View {
        HStack(spacing: TMISpacing.md) {
            // Model Icon
            ZStack {
                Circle()
                    .fill(modelColor(for: plan.model).opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: modelIcon(for: plan.model))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(modelColor(for: plan.model))
            }

            // Plan Info
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.tmiLabelLarge)
                    .foregroundColor(.tmiTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(plan.model.rawValue)
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextSecondary)

                    Text("•")
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextTertiary)

                    Text(studentNames(plan.students))
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Progress Circle
            TMIProgressCircle(
                progress: plan.progress,
                size: 40,
                lineWidth: 3,
                color: modelColor(for: plan.model)
            )
        }
        .padding(TMISpacing.md)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.md)
    }

    // MARK: - Empty/Loading States

    private var loadingView: some View {
        VStack(spacing: TMISpacing.lg) {
            ProgressView()
                .tint(.tmiPrimary)

            Text("Loading plans...")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        TMIEmptyStateRedesigned(
            icon: selectedTab == .active ? "doc.badge.plus" : "archivebox",
            title: selectedTab == .active ? "No Active Plans" : "No Completed Plans",
            message: selectedTab == .active ?
                "Create your first TMI plan to get started" :
                "Completed plans will appear here",
            action: selectedTab == .active ? { showingNewPlan = true } : nil,
            actionLabel: selectedTab == .active ? "Create Plan" : nil
        )
    }

    private func errorView(_ error: IdentifiableError) -> some View {
        TMIEmptyStateRedesigned(
            icon: "exclamationmark.triangle",
            title: "Unable to Load",
            message: error.message,
            action: {
                Task { await stateModel.fetch() }
            },
            actionLabel: "Try Again"
        )
    }

    // MARK: - New Plan Selector

    private var newPlanSelector: some View {
        StudentSelectorForPlanView(onStudentSelected: { _ in
            showingNewPlan = false
        })
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showingNewPlan = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func modelIcon(for model: TMIPlanModel) -> String {
        switch model {
        case .chaseYourSpace: return "arrow.up.right"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.triangle.2.circlepath"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.fill"
        }
    }

    private func modelColor(for model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .purple
        case .alignYourMind: return .teal
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }

    private func studentNames(_ students: [Student]) -> String {
        if students.isEmpty {
            return "No students"
        } else if students.count == 1 {
            return students[0].name
        } else {
            return "\(students[0].name) +\(students.count - 1)"
        }
    }
}

#Preview {
    NavigationStack {
        TMIPlanListViewRedesigned()
    }
}
