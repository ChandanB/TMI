//
//  InterestsAndHobbiesView.swift
//  TMI
//
//  Enhanced with modern SwiftUI patterns and TMI component library.
//  Now context-aware: shows student-specific interests when context is set.
//

import SwiftUI

// MARK: - Main View

struct InterestsAndHobbiesView: View {
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.studentContext) private var studentContext
    @Environment(\.studentAccessMode) private var accessMode
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var segmentNamespace

    // Animation states
    @State private var headerAppeared = false
    @State private var searchAppeared = false
    @State private var segmentAppeared = false
    @State private var contentAppeared = false
    @State private var fabAppeared = false

    // Dynamic data
    @State private var activeStudentCount = 0
    
    // Context-aware mode
    private var isStudentContext: Bool {
        studentContext.hasActiveStudent
    }
    
    private var contextStudent: Student? {
        studentContext.cachedStudent
    }

    private let studentService = StudentService()
    
    var body: some View {
        ZStack {
            // Unified background
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()
            
            ZStack(alignment: .bottomTrailing) {
                contentView
                
                // Floating action button - only show for staff
                if StudentAccessPolicy.canEdit(in: accessMode) {
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: binding(stateModel, \.showingAddSheet)) {
            AddItemSheet()
                .tmiSheetStyle()
        }
        .task {
            await stateModel.fetch()
            await loadActiveStudentCount()
            
            // If we have a student context, use prefetched interests
            if isStudentContext && !studentContext.prefetchedInterests.isEmpty {
                print("[InterestsAndHobbiesView] Using \(studentContext.prefetchedInterests.count) prefetched interests for student context")
            }
        }
        .refreshable {
            await stateModel.refresh()
            await loadActiveStudentCount()
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
            VStack(spacing: 20) {
                headerSection
                    .padding(.top, 12)
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

                Spacer(minLength: 80)
            }
            .padding(.bottom, 20)
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
        stateModel.selectedSegment == .all
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        stateModel.selectedSegment = segment
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: segment.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(stateModel.selectedSegment == segment ? segmentColor : .white.opacity(0.5))

                        Text(segment.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(stateModel.selectedSegment == segment ? .white : .white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .background(
                        ZStack {
                            if stateModel.selectedSegment == segment {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(segmentColor.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(segmentColor.opacity(0.4), lineWidth: 1.5)
                                    )
                                    .shadow(color: segmentColor.opacity(0.3), radius: 8, y: 2)
                                    .matchedGeometryEffect(id: "segment_background", in: segmentNamespace)
                            }
                        }
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityLabel("Switch between interest categories")
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
            StatsCard(
                icon: stateModel.selectedSegment.iconName,
                value: "\(displayedInterests.count)",
                label: stateModel.selectedSegment == .all ? "Total" : "In Category",
                color: segmentColor,
                index: 0
            )

            StatsCard(
                icon: "chart.bar.fill",
                value: "\(stateModel.categoryCount)",
                label: "Categories",
                color: segmentColor,
                index: 1
            )

            StatsCard(
                icon: "person.2.fill",
                value: "\(activeStudentCount)",
                label: "Students",
                color: segmentColor,
                index: 2
            )
        }
    }
    
    // MARK: - Items Grid Section
    
    private var itemsGridSection: some View {
        Group {
            if stateModel.filteredInterests.isEmpty {
                emptyStateView
            } else {
                itemsGrid
            }
        }
    }
    
    private var itemsGrid: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: 18
        ) {
            ForEach(displayedInterests) { interest in
                NavigationLink {
                    InterestDetailView(interest: interest)
                } label: {
                    InterestCardView(interest: interest)
                }
                .buttonStyle(InterestCardButtonStyle())
                .accessibilityLabel("View details for \(interest.name)")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }

    // Computed property to get interests based on selected segment
    private var displayedInterests: [Interest] {
        if stateModel.selectedSegment == .all {
            return stateModel.filteredInterests
        } else {
            let targetCategories = stateModel.selectedSegment.categories
            return stateModel.filteredInterests.filter { interest in
                !Set(interest.category).isDisjoint(with: Set(targetCategories))
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        sizeClass == .regular
            ? [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)]
            : [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 16)]
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 20) {
                Image(systemName: stateModel.selectedSegment == .all ? "heart.slash" : "gamecontroller.fill")
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
            return stateModel.selectedSegment == .all
                ? "Add your first interest to start tracking student alignments"
                : "Add your first interest to start exploring student activities"
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
    
    // MARK: - Helper Properties
    
    private var segmentColor: Color {
        stateModel.selectedSegment == .all ? .pink : .green
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

    @MainActor
    private func loadActiveStudentCount() async {
        do {
            let students = try await studentService.fetchStudents()
            activeStudentCount = students.count
        } catch {
            print("[InterestsAndHobbiesView] Failed to load student count: \(error)")
            activeStudentCount = 0
        }
    }
}

// MARK: - Add Item Sheet

struct AddItemSheet: View {
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.dismiss) var dismiss

    @State private var showingPredefinedList = false
    @State private var itemName = ""
    @State private var selectedCategory = InterestCategory.academics
    @State private var selectedIcon = "heart.fill"
    @State private var description = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .base)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Browse predefined interests button
                        browsePredefinedSection

                        // Divider with "OR"
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                            Text("OR")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 12)
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)

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
            .navigationTitle("Add Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingPredefinedList) {
                PredefinedInterestsListView()
                    .tmiSheetStyle()
            }
        }
    }

    // MARK: - Browse Predefined Section

    private var browsePredefinedSection: some View {
        TMIGlassCard(style: .elevated) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse 200+ Interests")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Choose from our curated catalog")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()
                }

                TMIButton(
                    text: "Browse Catalog",
                    icon: "list.bullet",
                    style: .secondary,
                    action: { showingPredefinedList = true }
                )
            }
            .padding(20)
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
                    placeholder: "Enter interest name",
                    text: $itemName
                )
                .accessibilityLabel("Enter interest name")
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
                    ForEach(interestIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(selectedIcon == icon ? .white : .white.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIcon == icon ? Color.pink.opacity(0.3) : Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedIcon == icon ? Color.pink : Color.white.opacity(0.2), lineWidth: 1)
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
                                Text("Add a description to help identify this interest...")
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
                text: "Save Interest",
                style: .primary,
                action: saveItem
            )
            .disabled(itemName.isEmpty)
            .padding(20)
            .background(
                Rectangle()
                    .fill(Color.tmiSurface)
                    .opacity(0.5)
                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
            )
        }
    }
    
    // MARK: - Actions
    
    private func saveItem() {
        Task {
            let newInterest = Interest(
                name: itemName,
                category: [selectedCategory],
                description: description.isEmpty ? nil : description
            )
            await stateModel.addInterest(newInterest)
            dismiss()
        }
    }
}

// MARK: - Stats Card View

struct StatsCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let index: Int

    @State private var isHovered = false
    @State private var hasAppeared = false

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isHovered ? 1.1 : 1.0)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                        .symbolEffect(.bounce, options: .speed(0.5), value: isHovered)
                }

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(value: Double(value) ?? 0))

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 8)
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .shadow(
            color: isHovered ? color.opacity(0.3) : Color.clear,
            radius: isHovered ? 12 : 0,
            y: isHovered ? 4 : 0
        )
        .scaleEffect(hasAppeared ? 1.0 : 0.8)
        .opacity(hasAppeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1)) {
                hasAppeared = true
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Interest Card View

struct InterestCardView: View {
    let interest: Interest
    @State private var isHovered = false

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 0) {
                // Icon header with gradient background
                ZStack {
                    LinearGradient(
                        colors: [
                            interest.color.opacity(0.3),
                            interest.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 80)

                    VStack {
                        HStack {
                            Spacer()

                            if interest.isFeatured {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                    )
                            }
                        }
                        .padding(12)

                        Spacer()
                    }

                    Image(systemName: interest.iconName)
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(interest.color)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: isHovered)
                }
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    topTrailingRadius: 16
                ))

                // Content section
                VStack(alignment: .leading, spacing: 8) {
                    Text(interest.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 10))
                            .foregroundColor(interest.color.opacity(0.8))

                        Text(interest.category.first?.rawValue ?? "General")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .offset(x: isHovered ? 4 : 0)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(
            color: isHovered ? interest.color.opacity(0.3) : Color.clear,
            radius: isHovered ? 15 : 0,
            x: 0,
            y: isHovered ? 8 : 0
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Button Styles

struct InterestCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Predefined Interests List View

struct PredefinedInterestsListView: View {
    @Environment(\.interestsStateModel) var stateModel
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var selectedCategory: InterestCategory?

    private var filteredInterests: [Interest] {
        var interests = PredefinedInterestsData.allPredefinedInterests

        // Filter by category
        if let category = selectedCategory {
            interests = interests.filter { $0.category.contains(category) }
        }

        // Filter by search
        if !searchText.isEmpty {
            interests = PredefinedInterestsData.search(searchText)
        }

        return interests.sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .base)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    TMITextField(
                        icon: "magnifyingglass",
                        placeholder: "Search interests...",
                        text: $searchText
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            CategoryFilterChip(
                                title: "All",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )

                            ForEach(InterestCategory.allCases, id: \.self) { category in
                                CategoryFilterChip(
                                    title: category.rawValue,
                                    icon: category.iconName,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }

                    // Results count
                    HStack {
                        Text("\(filteredInterests.count) interests")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Interests list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredInterests) { interest in
                                PredefinedInterestRow(interest: interest) {
                                    Task {
                                        await stateModel.addInterest(interest)
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Browse Interests")
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
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.pink.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.pink : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Predefined Interest Row

struct PredefinedInterestRow: View {
    let interest: Interest
    let onAdd: () -> Void

    @State private var isExpanded = false

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 0) {
                // Main content
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(interest.color.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: interest.iconName)
                            .font(.system(size: 22))
                            .foregroundColor(interest.color)
                    }

                    // Name and category
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(interest.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            if interest.isFeatured {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 9))
                            Text(interest.category.first?.rawValue ?? "General")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.6))

                        if let score = interest.popularityScore {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 9))
                                Text("\(score)% popular")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Add button
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }

                // Expanded details
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        if let description = interest.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        if !interest.academicRelevance.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Academic Relevance")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(interest.academicRelevance, id: \.self) { subject in
                                            Text(subject.rawValue)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.2))
                                                )
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }

                        if let skills = interest.skillsDeveloped, !skills.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Skills Developed")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(skills, id: \.self) { skill in
                                            Text(skill.rawValue)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.purple.opacity(0.2))
                                                )
                                                .foregroundColor(.purple)
                                        }
                                    }
                                }
                            }
                        }

                        if let pathways = interest.careerPathways, !pathways.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Career Pathways")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(pathways, id: \.self) { pathway in
                                            Text(pathway.rawValue)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.orange.opacity(0.2))
                                                )
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Supporting Types

private let interestIcons = [
    "heart.fill", "book.fill", "graduationcap.fill", "atom", "fossil.shell.fill",
    "leaf.fill", "globe.americas.fill", "paintbrush.fill", "ruler.fill", "guitars.fill"
]

// MARK: - Preview

#if DEBUG
#Preview {
    InterestsAndHobbiesView()
        .environment(\.interestsStateModel, InterestsAndHobbiesStateModel())
}
#endif
