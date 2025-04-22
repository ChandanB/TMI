// EnhancedInterestsAndHobbiesView.swift

import SwiftUI

enum InterestsAndHobbiesItemType: String, CaseIterable, Identifiable {
    case interest = "Interest"
    case hobby = "Hobby"
    
    var id: String { self.rawValue }
}

struct InterestsAndHobbiesView: View {
    @State var interests: [Interest]
    @State var hobbies: [Hobby]
    @State private var showingAddSheet = false
    @State private var newItemType: InterestsAndHobbiesItemType = .interest
    @State private var newItemName = ""
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var selectedSegment: Segment = .interests
    
    // Animation states
    @State private var headerAppeared = false
    @State private var searchAppeared = false
    @State private var segmentAppeared = false
    @State private var gridAppeared = false
    @State private var fabAppeared = false
    
    enum Segment: String, CaseIterable, Identifiable {
        case interests = "Interests"
        case hobbies = "Hobbies"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ZStack {
            // Background
            interestsBackgroundView
            
            NavigationStack {
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(spacing: 24) {
                            enhancedHeaderView
                                .padding(.top, 16)
                                .padding(.horizontal, 20)
                                .offset(y: headerAppeared ? 0 : -20)
                                .opacity(headerAppeared ? 1 : 0)
                            
                            enhancedSearchBar
                                .padding(.horizontal, 20)
                                .offset(y: searchAppeared ? 0 : -20)
                                .opacity(searchAppeared ? 1 : 0)
                            
                            enhancedSegmentedControl
                                .padding(.horizontal, 20)
                                .offset(y: segmentAppeared ? 0 : 10)
                                .opacity(segmentAppeared ? 1 : 0)
                            
                            // Stats summary
                            itemStatsView
                                .padding(.horizontal, 20)
                                .offset(y: segmentAppeared ? 0 : 10)
                                .opacity(segmentAppeared ? 1 : 0)
                            
                            enhancedItemsGridView
                                .padding(.horizontal, 20)
                                .offset(y: gridAppeared ? 0 : 30)
                                .opacity(gridAppeared ? 1 : 0)
                        }
                        .padding(.bottom, 100)
                    }
                    
                    // Floating action button
                    FloatingAddButton(action: {
                        showingAddSheet = true
                    })
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .offset(y: fabAppeared ? 0 : 100)
                    .opacity(fabAppeared ? 1 : 0)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Interests & Hobbies")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                // Sort action
                            }) {
                                Label("Sort Alphabetically", systemImage: "arrow.up.arrow.down")
                            }
                            
                            Button(action: {
                                // Filter action
                            }) {
                                Label("Filter by Category", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                // Import action
                            }) {
                                Label("Import", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: {
                                // Export action
                            }) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showingAddSheet) {
                    EnhancedAddItemView(
                        itemType: $newItemType,
                        itemName: $newItemName,
                        onSave: addItem
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
                    .presentationSizing(.page)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            animateViews()
        }
    }
    
    private func animateViews() {
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
            gridAppeared = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
            fabAppeared = true
        }
    }
    
    // MARK: - Background
    
    private var interestsBackgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated blobs
            InterestsBackgroundBlob(selectedSegment: selectedSegment)
        }
    }
    
    // MARK: - Header View
    
    private var enhancedHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedSegment == .interests ? "Your Interests" : "Your Hobbies")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(selectedSegment == .interests ?
                 "Explore and manage your academic and personal interests" :
                    "Discover and track your favorite pastimes and activities")
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Search Bar
    
    private var enhancedSearchBar: some View {
        ZStack(alignment: .leading) {
            if searchText.isEmpty && !isSearchFocused {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(selectedSegment == .interests ? "Search interests" : "Search hobbies")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.leading, 12)
            }
            
            TextField("", text: $searchText)
                .font(.system(size: 16))
                .padding(12)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .onTapGesture {
                    isSearchFocused = true
                }
                .onSubmit {
                    isSearchFocused = false
                }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSearchFocused ?
                    LinearGradient(
                        colors: [Color.tmiSecondary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    :
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }
    
    // MARK: - Segmented Control
    
    private var enhancedSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(Segment.allCases) { segment in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSegment = segment
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(segment.rawValue)
                            .font(.system(size: 16, weight: selectedSegment == segment ? .semibold : .medium))
                            .foregroundColor(selectedSegment == segment ? .white : .white.opacity(0.6))
                        
                        if selectedSegment == segment {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(segmentColor)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "SegmentIndicator", in: namespace)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
    }
    
    // MARK: - Stats View
    
    private var itemStatsView: some View {
        HStack(spacing: 15) {
            ItemStatCard(
                icon: selectedSegment == .interests ? "heart.fill" : "gamecontroller.fill",
                count: selectedSegment == .interests ? filteredInterests.count : filteredHobbies.count,
                label: "Total",
                color: segmentColor
            )
            
            ItemStatCard(
                icon: "chart.bar.fill",
                count: selectedSegment == .interests ?
                categoryCount(from: filteredInterests.map { $0.category.first ?? .academics }) :
                    categoryCount(from: filteredHobbies.map { $0.category.first ?? .sports }),
                label: "Categories",
                color: segmentColor
            )
            
            ItemStatCard(
                icon: "person.fill",
                count: selectedSegment == .interests ? 5 : 3, // This would be dynamic in a real app
                label: "Students",
                color: segmentColor
            )
        }
    }
    
    private func categoryCount<T: Hashable>(from items: [T]) -> Int {
        return Set(items).count
    }
    
    // MARK: - Items Grid View
    
    private var enhancedItemsGridView: some View {
        VStack {
            if (selectedSegment == .interests && filteredInterests.isEmpty) ||
                (selectedSegment == .hobbies && filteredHobbies.isEmpty) {
                emptyStateView
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 20)],
                    spacing: 20
                ) {
                    if selectedSegment == .interests {
                        ForEach(filteredInterests) { interest in
                            NavigationLink(destination: EnhancedInterestDetailView(interest: interest)) {
                                EnhancedItemCardView(
                                    title: interest.name,
                                    icon: interest.iconName,
                                    color: interest.color,
                                    category: interest.category.first?.rawValue ?? "Other"
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    } else {
                        ForEach(filteredHobbies) { hobby in
                            NavigationLink(destination: EnhancedHobbyDetailView(hobby: hobby)) {
                                EnhancedItemCardView(
                                    title: hobby.name,
                                    icon: hobby.iconName,
                                    color: hobby.color,
                                    category: hobby.category.first?.rawValue ?? "Other"
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                // Glowing background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [segmentColor.opacity(0.3), Color.clear]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 10)
                
                Image(systemName: selectedSegment == .interests ? "heart.slash" : "gamecontroller.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(selectedSegment == .interests ? "No Interests Found" : "No Hobbies Found")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(selectedSegment == .interests ?
                 "Add your first interest to start tracking student alignments" :
                    "Add your first hobby to start exploring student activities")
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            
            Button {
                showingAddSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(selectedSegment == .interests ? "Add Interest" : "Add Hobby")
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [segmentColor, segmentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: segmentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .frame(minHeight: 400)
    }
    
    // MARK: - Namespace and Colors
    
    @Namespace private var namespace
    
    private var segmentColor: Color {
        selectedSegment == .interests ? .pink : .green
    }
    
    // MARK: - Filtering
    
    private var filteredInterests: [Interest] {
        interests.filter { $0.name.localizedCaseInsensitiveContains(searchText) || searchText.isEmpty }
    }
    
    private var filteredHobbies: [Hobby] {
        hobbies.filter { $0.name.localizedCaseInsensitiveContains(searchText) || searchText.isEmpty }
    }
    
    // MARK: - Data Manipulation
    
    private func addItem() {
        withAnimation {
            if newItemType == .interest {
                let newInterest = Interest(
                    name: newItemName,
                    category: [.academics]
                )
                interests.append(newInterest)
            } else {
                let newHobby = Hobby(
                    name: newItemName,
                    category: [.sports]
                )
                hobbies.append(newHobby)
            }
            newItemName = ""
            showingAddSheet = false
        }
    }
}

// MARK: - Supporting Types & Views

struct InterestsBackgroundBlob: View {
    var selectedSegment: InterestsAndHobbiesView.Segment
    
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    
    var body: some View {
        ZStack {
            // Blob 1
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            selectedSegment == .interests ?
                            Color.pink.opacity(0.3) :
                                Color.green.opacity(0.3),
                            selectedSegment == .interests ?
                            Color.purple.opacity(0.1) :
                                Color.teal.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animateBlob1 ? -30 : -130, y: animateBlob1 ? -100 : -60)
                .rotationEffect(Angle(degrees: animateBlob1 ? 30 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 8)
                        .repeatForever(autoreverses: true),
                    value: animateBlob1
                )
            
            // Blob 2
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            selectedSegment == .interests ?
                            Color.blue.opacity(0.2) :
                                Color.yellow.opacity(0.2),
                            selectedSegment == .interests ?
                            Color.purple.opacity(0.1) :
                                Color.orange.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 250, height: 250)
                .offset(x: animateBlob2 ? 100 : 160, y: animateBlob2 ? 300 : 250)
                .rotationEffect(Angle(degrees: animateBlob2 ? -20 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 10)
                        .repeatForever(autoreverses: true),
                    value: animateBlob2
                )
        }
        .onAppear {
            animateBlob1 = true
            animateBlob2 = true
        }
    }
}

// MARK: - Item Card View

struct EnhancedItemCardView: View {
    let title: String
    let icon: String
    let color: Color
    let category: String
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            // Title
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            // Category badge
            Text(category)
                .font(.system(size: 12))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Stat Card

struct ItemStatCard: View {
    var icon: String
    var count: Int
    var label: String
    var color: Color
    
    @State private var isAnimated = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .scaleEffect(isAnimated ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimated
                    )
            }
            
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            isAnimated = true
        }
    }
}

// MARK: - Floating Add Button

struct FloatingAddButton: View {
    var action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Slight delay to show press effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.tmiSecondary.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 15 : 10, x: 0, y: 5)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Add Item View

struct EnhancedAddItemView: View {
    @Binding var itemType: InterestsAndHobbiesItemType
    @Binding var itemName: String
    @State private var selectedCategory = InterestCategory.academics
    @State private var selectedHobbyCategory = HobbyCategory.sports
    @State private var selectedIcon = "heart.fill"
    @Environment(\.dismiss) var dismiss
    
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.15),
                        Color(red: 0.14, green: 0.14, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Type selection
                        typeSelectionSection
                        
                        // Name input
                        nameInputSection
                        
                        // Category selection
                        categorySelectionSection
                        
                        // Icon selection
                        iconSelectionSection
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
                
                // Save button
                saveButtonSection
            }
            .navigationTitle(itemType == .interest ? "Add Interest" : "Add Hobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Item Type")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(InterestsAndHobbiesItemType.allCases) { type in
                    TypeSelectionButton(
                        type: type,
                        isSelected: itemType == type,
                        action: {
                            withAnimation {
                                itemType = type
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            TextField("", text: $itemName)
                .placeholder(when: itemName.isEmpty, content: {
                    Text(itemType == .interest ? "Enter interest name" : "Enter hobby name")
                        .foregroundColor(.white.opacity(0.6))
                })
                .font(.system(size: 16))
                .padding(16)
                .foregroundColor(.white)
                .background(nameInputBackground)
        }
    }
    
    private var nameInputBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            if itemType == .interest {
                interestCategorySelector
            } else {
                hobbyCategorySelector
            }
        }
    }
    
    private var interestCategorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InterestCategory.allCases, id: \.self) { category in
                    IHCategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        color: .pink,
                        action: {
                            selectedCategory = category
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var hobbyCategorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HobbyCategory.allCases, id: \.self) { category in
                    IHCategoryButton(
                        title: category.rawValue,
                        isSelected: selectedHobbyCategory == category,
                        color: .green,
                        action: {
                            selectedHobbyCategory = category
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(itemType == .interest ? interestIcons : hobbyIcons, id: \.self) { icon in
                        IconSelectionButton(
                            icon: icon,
                            isSelected: selectedIcon == icon,
                            color: itemType == .interest ? .pink : .green,
                            action: {
                                selectedIcon = icon
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var saveButtonSection: some View {
        VStack {
            Spacer()
            
            Button {
                onSave()
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(saveButtonBackground)
                    .cornerRadius(14)
                    .shadow(
                        color: saveButtonShadowColor,
                        radius: 10,
                        x: 0,
                        y: 5
                    )
            }
            .buttonStyle(ScaleButtonStyle())
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
    
    private var saveButtonBackground: some View {
        Group {
            if itemName.isEmpty {
                Color.gray.opacity(0.5)
            } else {
                LinearGradient(
                    colors: [
                        itemType == .interest ? Color.pink : Color.green,
                        itemType == .interest ? Color.pink.opacity(0.8) : Color.green.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var saveButtonShadowColor: Color {
        if itemName.isEmpty {
            return Color.clear
        } else {
            return itemType == .interest ? Color.pink.opacity(0.3) : Color.green.opacity(0.3)
        }
    }
}

private let interestIcons = [
    "heart.fill", "book.fill", "graduationcap.fill", "atom", "fossil.shell.fill",
    "leaf.fill", "globe.americas.fill", "paintbrush.fill", "ruler.fill", "guitars.fill"
]

private let hobbyIcons = [
    "gamecontroller.fill", "figure.run", "basketball.fill", "music.note", "camera.fill",
    "theatermasks.fill", "mountain.2.fill", "airplane", "bike", "baseball.fill"
]

// MARK: - Supporting Views for Add Item

struct TypeSelectionButton: View {
    var type: InterestsAndHobbiesItemType
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: type == .interest ? "heart.fill" : "gamecontroller.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? color : .white.opacity(0.7))
                }
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color.white.opacity(0.03))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .opacity(0.2)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ?
                        LinearGradient(
                            colors: [color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        :
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    private var color: Color {
        type == .interest ? .pink : .green
    }
}

struct IHCategoryButton: View {
    var title: String
    var isSelected: Bool
    var color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ?
                            color.opacity(0.5) :
                                Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct IconSelectionButton: View {
    var icon: String
    var isSelected: Bool
    var color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? color : .white.opacity(0.7))
            }
            .overlay(
                Circle()
                    .stroke(
                        isSelected ?
                        color.opacity(0.5) :
                            Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Views

struct EnhancedInterestDetailView: View {
    let interest: Interest
    
    @State private var headerAppeared = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated blob
            InterestDetailBlob(color: interest.color)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(interest.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: interest.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(interest.color)
                        }
                        
                        VStack(spacing: 8) {
                            Text(interest.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(interest.category.first?.rawValue ?? "General")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(interest.color.opacity(0.15))
                                )
                        }
                    }
                    .padding(.top, 40)
                    .offset(y: headerAppeared ? 0 : -30)
                    .opacity(headerAppeared ? 1 : 0)
                    
                    // Stats
                    HStack(spacing: 20) {
                        DetailStatCard(
                            value: "32",
                            label: "Students",
                            icon: "person.2.fill",
                            color: interest.color
                        )
                        
                        DetailStatCard(
                            value: "78%",
                            label: "Engagement",
                            icon: "chart.line.uptrend.xyaxis.fill",
                            color: interest.color
                        )
                        
                        DetailStatCard(
                            value: "5",
                            label: "TMI Plans",
                            icon: "doc.fill",
                            color: interest.color
                        )
                    }
                    .padding(.horizontal, 20)
                    .offset(y: contentAppeared ? 0 : 30)
                    .opacity(contentAppeared ? 1 : 0)
                    
                    // Content
                    VStack(spacing: 20) {
                        // Related activities
                        IHDetailSection(title: "Related Activities", color: interest.color) {
                            Text("Activities related to this interest will be displayed here. "
                                 + "Connect activities to this interest to help align TMI plans with student interests.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                        }
                        
                        // Connected TMI Plans
                        IHDetailSection(title: "Connected TMI Plans", color: interest.color) {
                            Text("TMI plans that involve this interest will be shown here. "
                                 + "Create new plans or connect existing ones to track student progress.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                        }
                        
                        // Student Alignment
                        IHDetailSection(title: "Student Alignment", color: interest.color) {
                            Text("Students who have expressed this interest will appear here. "
                                 + "Track alignment between interests and academic performance.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .offset(y: contentAppeared ? 0 : 50)
                    .opacity(contentAppeared ? 1 : 0)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Interest Details")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        // Edit action
                    }) {
                        Label("Edit Interest", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        // Connect student action
                    }) {
                        Label("Connect Student", systemImage: "person.badge.plus")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        // Delete action
                    }) {
                        Label("Delete Interest", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                headerAppeared = true
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                contentAppeared = true
            }
        }
    }
}

struct EnhancedHobbyDetailView: View {
    let hobby: Hobby
    
    @State private var headerAppeared = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated blob
            InterestDetailBlob(color: hobby.color)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(hobby.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: hobby.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(hobby.color)
                        }
                        
                        VStack(spacing: 8) {
                            Text(hobby.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(hobby.category.first?.rawValue ?? "General")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(hobby.color.opacity(0.15))
                                )
                        }
                    }
                    .padding(.top, 40)
                    .offset(y: headerAppeared ? 0 : -30)
                    .opacity(headerAppeared ? 1 : 0)
                    
                    // Stats
                    HStack(spacing: 20) {
                        DetailStatCard(
                            value: "24",
                            label: "Students",
                            icon: "person.2.fill",
                            color: hobby.color
                        )
                        
                        DetailStatCard(
                            value: "65%",
                            label: "Engagement",
                            icon: "chart.line.uptrend.xyaxis.fill",
                            color: hobby.color
                        )
                        
                        DetailStatCard(
                            value: "3",
                            label: "TMI Plans",
                            icon: "doc.fill",
                            color: hobby.color
                        )
                    }
                    .padding(.horizontal, 20)
                    .offset(y: contentAppeared ? 0 : 30)
                    .opacity(contentAppeared ? 1 : 0)
                    
                    // Content
                    VStack(spacing: 20) {
                        // Related activities
                        IHDetailSection(title: "Related Activities", color: hobby.color) {
                            Text("Activities related to this hobby will be displayed here. "
                                 + "Connect activities to this hobby to help align TMI plans with student interests.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                        }
                        
                        // Connected TMI Plans
                        IHDetailSection(title: "Connected TMI Plans", color: hobby.color) {
                            Text("TMI plans that involve this hobby will be shown here. "
                                 + "Create new plans or connect existing ones to track student progress.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                        }
                        
                        // Student Engagement
                        IHDetailSection(title: "Student Engagement", color: hobby.color) {
                            Text("Students who participate in this hobby will appear here. "
                                 + "Track engagement and connections to academic performance.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .offset(y: contentAppeared ? 0 : 50)
                    .opacity(contentAppeared ? 1 : 0)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Hobby Details")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        // Edit action
                    }) {
                        Label("Edit Hobby", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        // Connect student action
                    }) {
                        Label("Connect Student", systemImage: "person.badge.plus")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        // Delete action
                    }) {
                        Label("Delete Hobby", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                headerAppeared = true
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                contentAppeared = true
            }
        }
    }
}

// MARK: - Detail Supporting Views

struct InterestDetailBlob: View {
    var color: Color
    
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    
    var body: some View {
        ZStack {
            // Blob 1
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.3),
                            color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animateBlob1 ? -30 : -130, y: animateBlob1 ? -100 : -60)
                .rotationEffect(Angle(degrees: animateBlob1 ? 30 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 8)
                        .repeatForever(autoreverses: true),
                    value: animateBlob1
                )
            
            // Blob 2
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.2),
                            Color.purple.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 250, height: 250)
                .offset(x: animateBlob2 ? 100 : 160, y: animateBlob2 ? 300 : 250)
                .rotationEffect(Angle(degrees: animateBlob2 ? -20 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 10)
                        .repeatForever(autoreverses: true),
                    value: animateBlob2
                )
        }
        .onAppear {
            animateBlob1 = true
            animateBlob2 = true
        }
    }
}

struct DetailStatCard: View {
    var value: String
    var label: String
    var icon: String
    var color: Color
    
    @State private var isAnimated = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .scaleEffect(isAnimated ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimated
                    )
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            isAnimated = true
        }
    }
}

struct IHDetailSection<Content: View>: View {
    var title: String
    var color: Color
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color.opacity(0.8))
            }
            
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}


// MARK: - Preview

#Preview {
    InterestsAndHobbiesView(
        interests: [],
        hobbies: []
    )
}
