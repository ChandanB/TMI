// TMIPlanListView.swift

import SwiftUI

struct TMIPlanListView: View {
    @State var tmiPlans: [TMIPlan]
    @State private var showingNewPlanSheet = false
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var selectedFilter: PlanFilter = .all

    enum PlanFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case inProgress = "In Progress"
        case completed = "Completed"

        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    searchAndFilterView
                    if tmiPlans.isEmpty {
                        emptyStateView
                    } else {
                        planGridView
                    }
                }
                .padding()
            }
            .background(Color.tmiBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewPlanSheet) {
                NewTMIPlanView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                PlanFilterView(selectedFilter: $selectedFilter)
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Plans")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
                Text("Manage and track your TMI Plans")
                    .font(.subheadline)
                    .foregroundColor(.tmiSecondary)
            }
            Spacer()
            Button(action: { showingNewPlanSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.tmiPrimary)
            }
            .accessibilityLabel("Add New Plan")
        }
    }

    private var searchAndFilterView: some View {
        HStack(spacing: 15) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.tmiSecondary)
                TextField("Search Plans", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color.tmiSecondary.opacity(0.1))
            .cornerRadius(10)

            Button(action: { showingFilterSheet = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.tmiPrimary)
            }
            .accessibilityLabel("Filter Plans")
        }
    }

    private var planGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 375))], spacing: 20) {
            ForEach(filteredPlans) { plan in
                NavigationLink(destination: TMIPlanDetailView(plan: plan)) {
                    TMIPlanCard(plan: plan)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.tmiSecondary)
            Text("No Plans Found")
                .font(.title2)
                .foregroundColor(.tmiPrimary)
            Text("Try adjusting your search or filter criteria.")
                .font(.body)
                .foregroundColor(.tmiSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private var filteredPlans: [TMIPlan] {
        tmiPlans.filter { plan in
            (searchText.isEmpty || plan.model.rawValue.localizedCaseInsensitiveContains(searchText) || plan.student.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedFilter == .all || matchesFilter(plan: plan))
        }
    }

    private func matchesFilter(plan: TMIPlan) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .inProgress:
            return plan.progress < 1.0
        case .completed:
            return plan.progress >= 1.0
        }
    }
}

struct PlanFilterView: View {
    @Binding var selectedFilter: TMIPlanListView.PlanFilter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(TMIPlanListView.PlanFilter.allCases) { filter in
                    HStack {
                        Text(filter.rawValue)
                            .foregroundColor(.tmiText)
                        Spacer()
                        if filter == selectedFilter {
                            Image(systemName: "checkmark")
                                .foregroundColor(.tmiPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFilter = filter
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filter Plans")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    TMIPlanListView(tmiPlans: TMIPlan.samplePlans)
}
