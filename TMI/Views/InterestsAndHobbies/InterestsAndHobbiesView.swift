//
//  InterestsAndHobbiesView.swift
//  TMI
//
//  Enhanced with modern SwiftUI patterns and TMI component library
//

import SwiftUI

// MARK: - Main View

struct InterestsAndHobbiesView: View {
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    // Animation states
    @State private var headerAppeared = false
    @State private var searchAppeared = false
    @State private var segmentAppeared = false
    @State private var contentAppeared = false
    @State private var fabAppeared = false
    
    var body: some View {
        ZStack {
            // Unified background
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            ZStack(alignment: .bottomTrailing) {
                contentView
                
                // Floating action button
                TMIButton(
                    text: "",
                    icon: "plus",
                    style: .floating,
                    action: { stateModel.showingAddSheet = true }
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .offset(y: fabAppeared ? 0 : 100)
                .opacity(fabAppeared ? 1 : 0)
                .accessibilityLabel("Add new \(stateModel.selectedSegment.rawValue.lowercased())")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: binding(stateModel, \.showingAddSheet)) {
            AddItemSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .preferredColorScheme(.dark)
        .task {
            await stateModel.fetch()
        }
        .refreshable {
            await stateModel.refresh()
        }
        .onAppear {
            animateViewEntrance()
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            switch stateModel.state {
            case .idle, .loading:
                loadingView
                
            case .loaded:
                loadedContentView
                
            case .error(let error):
                errorView(error)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading \(stateModel.selectedSegment.rawValue.lowercased())...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: IdentifiableError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)
            
            Text("Unable to Load Data")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(error.message)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 40)
            
            TMIButton(
                text: "Try Again",
                style: .secondary,
                action: {
                    Task { await stateModel.fetch() }
                }
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadedContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                    .offset(y: headerAppeared ? 0 : -20)
                    .opacity(headerAppeared ? 1 : 0)
                
                searchSection
                    .padding(.horizontal, 20)
                    .offset(y: searchAppeared ? 0 : -20)
                    .opacity(searchAppeared ? 1 : 0)
                
                segmentControlSection
                    .padding(.horizontal, 20)
                    .offset(y: segmentAppeared ? 0 : 10)
                    .opacity(segmentAppeared ? 1 : 0)
                
                statsSection
                    .padding(.horizontal, 20)
                    .offset(y: segmentAppeared ? 0 : 10)
                    .opacity(segmentAppeared ? 1 : 0)
                
                itemsGridSection
                    .padding(.horizontal, 20)
                    .offset(y: contentAppeared ? 0 : 30)
                    .opacity(contentAppeared ? 1 : 0)
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your \(stateModel.selectedSegment.rawValue)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(headerSubtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(Date(), style: .date)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("\(stateModel.totalItems) items")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var headerSubtitle: String {
        stateModel.selectedSegment == .interests
            ? "Explore and manage academic and personal interests"
            : "Discover and track favorite pastimes and activities"
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        TMITextField(
            icon: "magnifyingglass",
            placeholder: "Search \(stateModel.selectedSegment.rawValue.lowercased())...",
            text: binding(stateModel, \.searchText)
        )
        .accessibilityLabel("Search \(stateModel.selectedSegment.rawValue.lowercased())")
    }
    
    // MARK: - Segment Control Section
    
    private var segmentControlSection: some View {
        HStack(spacing: 0) {
            ForEach(InterestsAndHobbiesStateModel.ViewSegment.allCases, id: \.self) { segment in
                Button {
                    stateModel.selectedSegment = segment
                } label: {
                    Text(segment.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(stateModel.selectedSegment == segment ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(stateModel.selectedSegment == segment ? Color.white.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityLabel("Switch between interests and hobbies")
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 15) {
            statsCards
        }
    }
    
    @ViewBuilder
    private var statsCards: some View {
        Group {
            TMIGlassCard(style: .default) {
                VStack(spacing: 8) {
                    Image(systemName: stateModel.selectedSegment == .interests ? "heart.fill" : "gamecontroller.fill")
                        .font(.system(size: 24))
                        .foregroundColor(segmentColor)
                    
                    Text("\(stateModel.totalItems)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 24))
                        .foregroundColor(segmentColor)
                    
                    Text("\(stateModel.categoryCount)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Categories")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(segmentColor)
                    
                    Text("24")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Active Students")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Items Grid Section
    
    private var itemsGridSection: some View {
        Group {
            if stateModel.selectedSegment == .interests && stateModel.filteredInterests.isEmpty {
                emptyStateView
            } else if stateModel.selectedSegment == .hobbies && stateModel.filteredHobbies.isEmpty {
                emptyStateView
            } else {
                itemsGrid
            }
        }
    }
    
    private var itemsGrid: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: 20
        ) {
            if stateModel.selectedSegment == .interests {
                ForEach(stateModel.filteredInterests) { interest in
                    NavigationLink(destination: InterestDetailView(interest: interest)) {
                        TMIGlassCard(style: .default) {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: interest.iconName)
                                        .font(.system(size: 24))
                                        .foregroundColor(interest.color)
                                    
                                    Spacer()
                                    
                                    if interest.isFeatured {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(interest.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Text(interest.category.first?.rawValue ?? "General")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("View details for \(interest.name)")
                }
            } else {
                ForEach(stateModel.filteredHobbies) { hobby in
                    NavigationLink(destination: HobbyDetailView(hobby: hobby)) {
                        TMIGlassCard(style: .default) {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: hobby.iconName)
                                        .font(.system(size: 24))
                                        .foregroundColor(hobby.color)
                                    
                                    Spacer()
                                    
                                    if hobby.isFeatured {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hobby.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Text(hobby.category.first?.rawValue ?? "General")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("View details for \(hobby.name)")
                }
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        sizeClass == .regular
            ? Array(repeating: GridItem(.adaptive(minimum: 160), spacing: 20), count: 1)
            : Array(repeating: GridItem(.adaptive(minimum: 140), spacing: 16), count: 1)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 20) {
                Image(systemName: stateModel.selectedSegment == .interests ? "heart.slash" : "gamecontroller.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.4))
                
                VStack(spacing: 8) {
                    Text("No \(stateModel.selectedSegment.rawValue) Found")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(emptyStateMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                }
                
                TMIButton(
                    text: "Add \(stateModel.selectedSegment.rawValue.dropLast())",
                    icon: "plus",
                    style: .primary,
                    action: {
                        stateModel.showingAddSheet = true
                    }
                )
            }
            .padding(.vertical, 40)
        }
        .frame(minHeight: 400)
    }
    
    private var emptyStateMessage: String {
        if !stateModel.searchText.isEmpty {
            return "No \(stateModel.selectedSegment.rawValue.lowercased()) match your search. Try different keywords."
        } else if stateModel.selectedFilter != .all {
            return "No \(stateModel.selectedSegment.rawValue.lowercased()) in this category. Try a different filter."
        } else {
            return stateModel.selectedSegment == .interests
                ? "Add your first interest to start tracking student alignments"
                : "Add your first hobby to start exploring student activities"
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Interests & Hobbies")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                sortMenu
                Divider()
                filterMenu
                Divider()
                actionMenu
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
            .accessibilityLabel("More options")
        }
    }
    
    @ViewBuilder
    private var sortMenu: some View {
        Menu("Sort") {
            ForEach(InterestsAndHobbiesStateModel.SortOption.allCases) { option in
                Button {
                    stateModel.selectedSortOption = option
                } label: {
                    Label(
                        option.rawValue,
                        systemImage: stateModel.selectedSortOption == option ? "checkmark" : ""
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var filterMenu: some View {
        Menu("Filter") {
            ForEach(InterestsAndHobbiesStateModel.FilterOption.allCases) { option in
                Button {
                    stateModel.selectedFilter = option
                } label: {
                    Label(
                        option.rawValue,
                        systemImage: stateModel.selectedFilter == option ? "checkmark" : ""
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionMenu: some View {
        Button {
            // Import functionality - future enhancement
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
        
        Button {
            // Export functionality - future enhancement
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
    
    // MARK: - Helper Properties
    
    private var segmentColor: Color {
        stateModel.selectedSegment == .interests ? .pink : .green
    }
    
    // MARK: - Animation Methods
    
    private func animateViewEntrance() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            headerAppeared = true
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            searchAppeared = true
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            segmentAppeared = true
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            contentAppeared = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
            fabAppeared = true
        }
    }
}

// MARK: - Add Item Sheet

struct AddItemSheet: View {
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.dismiss) var dismiss
    
    @State private var itemType: InterestsAndHobbiesItemType = .interest
    @State private var itemName = ""
    @State private var selectedCategory = InterestCategory.academics
    @State private var selectedHobbyCategory = HobbyCategory.sports
    @State private var selectedIcon = "heart.fill"
    @State private var description = ""
    
    var body: some View {
        ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        typeSelectionSection
                        nameInputSection
                        categorySelectionSection
                        iconSelectionSection
                        descriptionSection
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
                
                saveButtonSection
            }
            .navigationTitle(itemType == .interest ? "Add Interest" : "Add Hobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    
    // MARK: - Type Selection
    
    private var typeSelectionSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Item Type")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 0) {
                    ForEach(InterestsAndHobbiesItemType.allCases, id: \.self) { type in
                        Button {
                            itemType = type
                        } label: {
                            Text(type.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(itemType == type ? .white : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(itemType == type ? Color.white.opacity(0.1) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Name Input
    
    private var nameInputSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TMITextField(
                    icon: "pencil",
                    placeholder: itemType == .interest ? "Enter interest name" : "Enter hobby name",
                    text: $itemName
                )
                .accessibilityLabel("Enter \(itemType.rawValue.lowercased()) name")
            }
        }
    }
    
    // MARK: - Category Selection
    
    private var categorySelectionSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if itemType == .interest {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(InterestCategory.allCases, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategory == category ? Color.pink.opacity(0.3) : Color.white.opacity(0.1))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(selectedCategory == category ? Color.pink : Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(HobbyCategory.allCases, id: \.self) { category in
                                Button {
                                    selectedHobbyCategory = category
                                } label: {
                                    Text(category.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedHobbyCategory == category ? .white : .white.opacity(0.7))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedHobbyCategory == category ? Color.green.opacity(0.3) : Color.white.opacity(0.1))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(selectedHobbyCategory == category ? Color.green : Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Icon Selection
    
    private var iconSelectionSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Icon")
                    .font(.headline)
                    .foregroundColor(.white)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(itemType == .interest ? interestIcons : hobbyIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(selectedIcon == icon ? .white : .white.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIcon == icon ? (itemType == .interest ? Color.pink.opacity(0.3) : Color.green.opacity(0.3)) : Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedIcon == icon ? (itemType == .interest ? Color.pink : Color.green) : Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Description (Optional)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextEditor(text: $description)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .overlay(
                        description.isEmpty ?
                        VStack {
                            HStack {
                                Text("Add a description to help identify this \(itemType.rawValue.lowercased())...")
                                    .foregroundColor(.white.opacity(0.5))
                                    .allowsHitTesting(false)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        : nil
                    )
                .frame(height: 80)
            }
        }
    }
    
    // MARK: - Save Button
    
    private var saveButtonSection: some View {
        VStack {
            Spacer()
            
            TMIButton(
                text: "Save \(itemType.rawValue)",
                style: .primary,
                action: saveItem
            )
            .disabled(itemName.isEmpty)
            .padding(20)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
            )
        }
    }
    
    // MARK: - Actions
    
    private func saveItem() {
        Task {
            if itemType == .interest {
                let newInterest = Interest(
                    name: itemName,
                    category: [selectedCategory],
                    description: description.isEmpty ? nil : description
                )
                await stateModel.addInterest(newInterest)
            } else {
                let newHobby = Hobby(
                    name: itemName,
                    category: [selectedHobbyCategory],
                    description: description.isEmpty ? nil : description
                )
                await stateModel.addHobby(newHobby)
            }
            dismiss()
        }
    }
}

// MARK: - Supporting Types

enum InterestsAndHobbiesItemType: String, CaseIterable, Identifiable {
    case interest = "Interest"
    case hobby = "Hobby"
    
    var id: String { self.rawValue }
}

private let interestIcons = [
    "heart.fill", "book.fill", "graduationcap.fill", "atom", "fossil.shell.fill",
    "leaf.fill", "globe.americas.fill", "paintbrush.fill", "ruler.fill", "guitars.fill"
]

private let hobbyIcons = [
    "gamecontroller.fill", "figure.run", "basketball.fill", "music.note", "camera.fill",
    "theatermasks.fill", "mountain.2.fill", "airplane", "bike", "baseball.fill"
]

// MARK: - Preview

#if DEBUG
#Preview {
    InterestsAndHobbiesView()
        .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
}
#endif
