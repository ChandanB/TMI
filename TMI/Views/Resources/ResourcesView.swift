import SwiftUI
import FirebaseFirestore
// MARK: - Models

struct Resource: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let description: String
    let category: ResourceCategory
    let url: String
    let createdAt: Date
    let updatedAt: Date
    let tags: [String]
    let recommendedFor: [String]
    var isFeatured: Bool = false
    var thumbnail: String? = nil
    
    enum ResourceCategory: String, CaseIterable, Codable {
        case article, video, course, book, tool, interactiveContent
        
        var color: Color {
            switch self {
            case .article: return .blue
            case .video: return .red
            case .course: return .green
            case .book: return .purple
            case .tool: return .orange
            case .interactiveContent: return .pink
            }
        }
        
        var icon: String {
            switch self {
            case .article: return "doc.text.fill"
            case .video: return "play.rectangle.fill"
            case .course: return "book.fill"
            case .book: return "book.closed.fill"
            case .tool: return "hammer.fill"
            case .interactiveContent: return "gamecontroller.fill"
            }
        }
    }
    
    static var sampleResources: [Resource] {
        [
            Resource(
                title: "Understanding Student Engagement",
                description: "A comprehensive guide to measuring and improving student engagement in educational settings.",
                category: .article,
                url: "https://example.com/article1",
                createdAt: Date().addingTimeInterval(-86400 * 7),
                updatedAt: Date().addingTimeInterval(-86400 * 7),
                tags: ["engagement", "research", "metrics"],
                recommendedFor: ["Teachers", "Counselors"],
                isFeatured: true
            ),
            Resource(
                title: "Aligning Interests with Academic Performance",
                description: "Video series exploring how student interests can be leveraged to improve academic outcomes.",
                category: .video,
                url: "https://example.com/video1",
                createdAt: Date().addingTimeInterval(-86400 * 14),
                updatedAt: Date().addingTimeInterval(-86400 * 14),
                tags: ["interests", "academic performance", "motivation"],
                recommendedFor: ["All Educators"]
            ),
            Resource(
                title: "TMI Implementation Course",
                description: "Step-by-step course on implementing Tangible Modification Intervention in your school or district.",
                category: .course,
                url: "https://example.com/course1",
                createdAt: Date().addingTimeInterval(-86400 * 30),
                updatedAt: Date().addingTimeInterval(-86400 * 30),
                tags: ["implementation", "training", "certification"],
                recommendedFor: ["Administrators", "Program Coordinators"],
                isFeatured: true
            ),
            Resource(
                title: "Interest-Based Learning: A Practical Guide",
                description: "Book on developing curriculum and learning activities based on student interests.",
                category: .book,
                url: "https://example.com/book1",
                createdAt: Date().addingTimeInterval(-86400 * 60),
                updatedAt: Date().addingTimeInterval(-86400 * 60),
                tags: ["curriculum", "interest-based learning"],
                recommendedFor: ["Curriculum Developers", "Teachers"]
            ),
            Resource(
                title: "Interest Survey Builder",
                description: "Interactive tool for creating customized student interest surveys.",
                category: .tool,
                url: "https://example.com/tool1",
                createdAt: Date().addingTimeInterval(-86400 * 90),
                updatedAt: Date().addingTimeInterval(-86400 * 90),
                tags: ["surveys", "assessment", "tools"],
                recommendedFor: ["All Educators"]
            ),
            Resource(
                title: "Student Interest Exploration Game",
                description: "Interactive game designed to help students explore and articulate their interests and passions.",
                category: .interactiveContent,
                url: "https://example.com/interactive1",
                createdAt: Date().addingTimeInterval(-86400 * 120),
                updatedAt: Date().addingTimeInterval(-86400 * 120),
                tags: ["games", "student self-discovery"],
                recommendedFor: ["Students", "Counselors"]
            )
        ]
    }
}

// MARK: - Main View

struct ResourcesView: View {
    @State private var resources: [Resource] = Resource.sampleResources
    @State private var showingAddResource = false
    @State private var searchText = ""
    @State private var selectedCategory: Resource.ResourceCategory?
    
    // Animation states
    @State private var isLoaded = false
    @State private var showSearchBar = false
    
    var body: some View {
        ZStack {
            // Background
            resourceBackgroundView
            
            NavigationStack {
                ZStack {
                    // Main content
                    VStack(spacing: 0) {
                        // Search bar - appears when scrolled
                        if showSearchBar {
                            searchBarView
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Scrollable content
                        ScrollView {
                            VStack(spacing: 24) {
                                // Featured resources section
                                if hasFeaturedResources {
                                    featuredResourcesSection
                                        .opacity(isLoaded ? 1 : 0)
                                        .offset(y: isLoaded ? 0 : 20)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isLoaded)
                                }
                                
                                // Category filter
                                categoryPickerView
                                    .padding(.horizontal, 20)
                                    .opacity(isLoaded ? 1 : 0)
                                    .offset(y: isLoaded ? 0 : 20)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: isLoaded)
                                
                                // Resources grid
                                if filteredResources.isEmpty {
                                    emptyStateView
                                        .opacity(isLoaded ? 1 : 0)
                                        .offset(y: isLoaded ? 0 : 30)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: isLoaded)
                                } else {
                                    resourcesGridView
                                }
                            }
                            .padding(.top, 20)
                        }
                        .coordinateSpace(name: "scroll")
                        .safeAreaInset(edge: .top, content: {
                            searchBarView
                                .opacity(showSearchBar ? 0 : 1)
                        })
                    }
                    
                    // Floating Add Button
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                showingAddResource = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(20)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: Color.tmiSecondary.opacity(0.4), radius: 10, x: 0, y: 5)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(24)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 100)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isLoaded)
                        }
                    }
                }
                .navigationTitle("Resource Library")
                .foregroundColor(.white)
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                showingAddResource = true
                            }) {
                                Label("Add Resource", systemImage: "plus")
                            }
                            
                            Button(action: {
                                // Implement import function
                            }) {
                                Label("Import Resources", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: {
                                // Implement filtering options
                            }) {
                                Label("Filter Options", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showingAddResource) {
                    AddResourceView(resources: $resources)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    isLoaded = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Background
    
    private var resourceBackgroundView: some View {
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
            
            // Animated blob overlay
            ResourcesAnimatedBlobView()
                .opacity(0.15)
            
            // Particle effect
            ResourcesParticleEffect()
                .opacity(0.3)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search resources", text: $searchText)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
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
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // MARK: - Category Picker
    
    private var categoryPickerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryButton(
                        title: "All",
                        icon: "square.grid.2x2.fill",
                        isSelected: selectedCategory == nil,
                        color: .blue
                    ) {
                        withAnimation {
                            selectedCategory = nil
                        }
                    }
                    
                    ForEach(Resource.ResourceCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            title: category.rawValue.capitalized,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            color: category.color
                        ) {
                            withAnimation {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Featured Resources
    
    private var hasFeaturedResources: Bool {
        resources.contains(where: { $0.isFeatured })
    }
    
    private var featuredResourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(resources.filter { $0.isFeatured }) { resource in
                        NavigationLink(destination: ResourceDetailView(resource: resource)) {
                            FeaturedResourceCard(resource: resource)
                                .frame(width: 300, height: 180)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Resources Grid
    
    private var resourcesGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
            spacing: 16
        ) {
            ForEach(filteredResources) { resource in
                NavigationLink(destination: ResourceDetailView(resource: resource)) {
                    ResourceCard(resource: resource)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 30)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7)
                            .delay(0.3 + Double(filteredResources.firstIndex(where: { $0.id == resource.id }) ?? 0) * 0.05),
                            value: isLoaded
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100) // Extra padding for FAB
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Empty illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.2), Color.clear]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 40)
            
            Text("No Resources Found")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            if searchText.isEmpty && selectedCategory == nil {
                Text("Add your first resource to build your library")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    showingAddResource = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Add Resource")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tmiSecondary)
                    )
                    .foregroundColor(.white)
                }
                .padding(.top, 10)
            } else {
                Text("Try changing your search or filter")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    searchText = ""
                    selectedCategory = nil
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Reset Filters")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tmiSecondary)
                    )
                    .foregroundColor(.white)
                }
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Filtered Resources
    
    private var filteredResources: [Resource] {
        resources.filter { resource in
            let matchesSearch = searchText.isEmpty ||
                resource.title.lowercased().contains(searchText.lowercased()) ||
                resource.description.lowercased().contains(searchText.lowercased()) ||
                resource.tags.contains { $0.lowercased().contains(searchText.lowercased()) }
            
            let matchesCategory = selectedCategory == nil || resource.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? color.opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .foregroundColor(isSelected ? color : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Featured Resource Card

struct FeaturedResourceCard: View {
    let resource: Resource
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background with gradient overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: resource.category.color.opacity(0.5), location: 0),
                            .init(color: Color.black.opacity(0.8), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Category icon (watermarked)
            Image(systemName: resource.category.icon)
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.1))
                .offset(x: -20, y: -20)
                .rotationEffect(.degrees(-15))
            
            // Content
            VStack(alignment: .leading, spacing: 10) {
                // Category pill
                Text(resource.category.rawValue.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(resource.category.color.opacity(0.3))
                    )
                    .foregroundColor(resource.category.color)
                
                // Title
                Text(resource.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Description
                Text(resource.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(resource.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        if resource.tags.count > 3 {
                            Text("+\(resource.tags.count - 3)")
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [resource.category.color.opacity(0.5), .clear, resource.category.color.opacity(0.2)],
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

// MARK: - Resource Card

struct ResourceCard: View {
    let resource: Resource
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(resource.category.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: resource.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(resource.category.color)
                }
                
                Spacer()
                
                // Category indicator
                Text(resource.category.rawValue.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(resource.category.color.opacity(0.2))
                    )
                    .foregroundColor(resource.category.color)
            }
            
            // Title
            Text(resource.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(height: 44, alignment: .top)
            
            // Description
            Text(resource.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(3)
                .frame(height: 60, alignment: .top)
            
            Spacer()
            
            // Tags
            if !resource.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(resource.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if resource.tags.count > 2 {
                        Text("+\(resource.tags.count - 2)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(16)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
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

// MARK: - Resource Detail View

struct ResourceDetailView: View {
    let resource: Resource
    
    @State private var animateContent = false
    @State private var showingWeb = false
    
    var body: some View {
        ZStack {
            // Background
            resourceBackgroundView
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    resourceHeader
                        .padding(.horizontal, 20)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateContent)
                    
                    // Description section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About this Resource")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(resource.description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Open Resource button
                        Button {
                            showingWeb = true
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text("Open Resource")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(resource.category.color)
                            )
                            .foregroundColor(.white)
                        }
                        .sheet(isPresented: $showingWeb) {
                            // This would be a WebView in a real app
                            VStack {
                                Text("Web view for: \(resource.url)")
                                    .padding()
                                
                                Button("Close") {
                                    showingWeb = false
                                }
                                .padding()
                            }
                            .presentationDetents([.medium, .large])
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.02))
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
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animateContent)
                    
                    // Tags and metadata
                    VStack(alignment: .leading, spacing: 20) {
                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ResourcesFlowLayout(spacing: 8) {
                                ForEach(resource.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Recommended for section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended For")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(resource.recommendedFor, id: \.self) { role in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(resource.category.color)
                                        
                                        Text(role)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Date info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resource Information")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("Created")
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Spacer()
                                
                                Text("\(resource.createdAt, formatter: dateFormatter)")
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("Last Updated")
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Spacer()
                                
                                Text("\(resource.updatedAt, formatter: dateFormatter)")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.02))
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
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: animateContent)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle(resource.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        // Share action
                    }) {
                        Label("Share Resource", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        // Open in browser
                        showingWeb = true
                    }) {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        // Bookmark
                    }) {
                        Label("Add to Bookmarks", systemImage: "bookmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    animateContent = true
                }
            }
        }
    }
    
    private var resourceBackgroundView: some View {
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
            
            // Animated blob overlay
            ResourcesAnimatedBlobView()
                .opacity(0.15)
        }
    }
    
    private var resourceHeader: some View {
        VStack(spacing: 20) {
            // Category icon
            ZStack {
                Circle()
                    .fill(resource.category.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: resource.category.icon)
                    .font(.system(size: 36))
                    .foregroundColor(resource.category.color)
            }
            
            VStack(spacing: 10) {
                // Category pill
                Text(resource.category.rawValue.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(resource.category.color.opacity(0.2))
                    )
                    .foregroundColor(resource.category.color)
                
                // Title
                Text(resource.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: resource.category.color.opacity(0.3), location: 0),
                            .init(color: resource.category.color.opacity(0.1), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [resource.category.color.opacity(0.5), .clear, resource.category.color.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Add Resource View

struct AddResourceView: View {
    @Binding var resources: [Resource]
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var category: Resource.ResourceCategory = .article
    @State private var url = ""
    @State private var tags = ""
    @State private var recommendedFor = ""
    @State private var isFeatured = false
    
    // Animation states
    @State private var showAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                resourceBackgroundView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Form fields in glass cards
                        Group {
                            // Title
                            ResourceFormField(
                                title: "Title",
                                placeholder: "Enter resource title",
                                text: $title
                            )
                            
                            // Description
                            LongResourceFormField(
                                title: "Description",
                                placeholder: "Enter a detailed description of the resource",
                                text: $description
                            )
                            
                            // Category picker
                            CategoryPickerView(category: $category)
                            
                            // URL
                            ResourceFormField(
                                title: "URL",
                                placeholder: "Enter resource URL",
                                icon: "link",
                                text: $url
                            )
                            
                            // Tags
                            ResourceFormField(
                                title: "Tags",
                                placeholder: "Enter comma-separated tags",
                                icon: "tag",
                                text: $tags
                            )
                            
                            // Recommended For
                            ResourceFormField(
                                title: "Recommended For",
                                placeholder: "Enter comma-separated roles",
                                icon: "person.2",
                                text: $recommendedFor
                            )
                            
                            // Featured toggle
                            FeatureToggleView(isFeatured: $isFeatured)
                        }
                        .opacity(showAnimation ? 1 : 0)
                        .offset(y: showAnimation ? 0 : 20)
                        
                        // Save button
                        Button {
                            saveResource()
                        } label: {
                            Text("Save Resource")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isFormValid ? Color.tmiSecondary : Color.gray.opacity(0.3))
                                )
                                .foregroundColor(.white)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 20)
                        .opacity(showAnimation ? 1 : 0)
                        .offset(y: showAnimation ? 0 : 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                    showAnimation = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var resourceBackgroundView: some View {
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
            
            // Animated blob overlay
            ResourcesAnimatedBlobView()
                .opacity(0.15)
        }
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty && !url.isEmpty
    }
    
    private func saveResource() {
        let newResource = Resource(
            title: title,
            description: description,
            category: category,
            url: url,
            createdAt: Date(),
            updatedAt: Date(),
            tags: tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) },
            recommendedFor: recommendedFor.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) },
            isFeatured: isFeatured
        )
        resources.append(newResource)
        dismiss()
    }
}

// MARK: - Form Components

struct CategoryPickerView: View {
    @Binding var category: Resource.ResourceCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Resource.ResourceCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation {
                                category = cat
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(category == cat ? cat.color.opacity(0.3) : Color.white.opacity(0.05))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(category == cat ? cat.color : .white.opacity(0.6))
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            category == cat ? cat.color : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 14))
                                    .foregroundColor(category == cat ? .white : .white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
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

struct FeatureToggleView: View {
    @Binding var isFeatured: Bool
    
    var body: some View {
        HStack {
            Text("Featured Resource")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isFeatured)
                .toggleStyle(SwitchToggleStyle(tint: Color.tmiSecondary))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
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

struct ResourceFormField: View {
    var title: String
    var placeholder: String
    var icon: String? = nil
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
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

struct LongResourceFormField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 16)
                        .padding(.leading, 16)
                }
                
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .frame(height: 120)
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
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

// MARK: - Flow Layout

struct ResourcesFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        
        return layout(width: width, subviews: subviews)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = proposal.width ?? bounds.width
        
        var origin = bounds.origin
        var maxHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if origin.x + size.width > width {
                // Move to next row
                origin.x = bounds.origin.x
                origin.y += maxHeight + spacing
                maxHeight = 0
            }
            
            subview.place(at: origin, proposal: ProposedViewSize(size))
            
            maxHeight = max(maxHeight, size.height)
            origin.x += size.width + spacing
        }
    }
    
    private func layout(width: CGFloat, subviews: Subviews) -> CGSize {
        var origin = CGPoint.zero
        var maxHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if origin.x + size.width > width {
                // Move to next row
                origin.x = 0
                origin.y += maxHeight + spacing
                totalHeight += maxHeight + spacing
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, size.height)
            origin.x += size.width + spacing
        }
        
        totalHeight += maxHeight
        
        return CGSize(width: width, height: totalHeight)
    }
}

// MARK: - Helper Views

struct ResourcesAnimatedBlobView: View {
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    
    var body: some View {
        ZStack {
            // Blob 1
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tmiSecondary.opacity(0.4),
                            Color.tmiSecondary.opacity(0.2)
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
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
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


struct ResourcesParticleEffect: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var size: CGFloat
        var opacity: Double
        var speed: Double
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Update particle positions
                for index in particles.indices {
                    particles[index].position.y -= particles[index].speed
                    particles[index].opacity -= 0.003
                    
                    if particles[index].position.y < 0 || particles[index].opacity <= 0 {
                        // Replace particle
                        particles[index] = createParticle(size: size)
                    }
                }
                
                // Draw particles
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x,
                        y: particle.position.y,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    context.opacity = particle.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .onAppear {
            // Initialize particles
            for _ in 0..<40 {
                particles.append(createParticle(size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)))
            }
        }
    }
    
    private func createParticle(size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ),
            size: CGFloat.random(in: 1...3),
            opacity: Double.random(in: 0.1...0.3),
            speed: Double.random(in: 0.2...0.6)
        )
    }
}

// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


// MARK: - Preview

#Preview {
    ResourcesView()
}
