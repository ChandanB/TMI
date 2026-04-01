//
//  ResourceDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

// Resource detail view with career connections and improved metadata
struct ResourceDetailView: View {
    let resource: Resource
    var onDelete: (() -> Void)? = nil

    @State private var animateContent = false
    @State private var showShareSheet = false
    @State private var isBookmarked = false
    @State private var isLoading = false
    @State private var relatedResources: [Resource] = []
    @State private var careerRecommendations: [Career] = []
    @State private var showWebView = false
    @State private var showBookmarkConfirmation = false
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private let resourceService = ResourceService.shared
    private let careerService = CareerService.shared

    var body: some View {
        ZStack {
            // Background
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero section
                    heroSection
                    
                    // Main content with glass morphism
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white.opacity(0.05))
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.9)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: -5)
                        
                        VStack(alignment: .leading, spacing: 24) {
                            // Resource description
                            descriptionSection
                            
                            // Enhanced metadata section
                            enhancedMetadataSection
                            
                            // Tags section
                            tagsSection
                            
                            // Action buttons
                            actionButtonsSection
                            
                            // Career connections section
                            if !careerRecommendations.isEmpty {
                                careerConnectionsSection
                            }
                            
                            // Related resources
                            if !relatedResources.isEmpty {
                                relatedResourcesSection
                            }
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .cornerRadius(30, corners: [.topLeft, .topRight])
                    .offset(y: -20)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await toggleBookmark()
                        }
                    }) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }

                    if onDelete != nil {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Resource", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .task {
            await loadResourceData()
        }
        .sheet(isPresented: $showWebView) {
            SafariWebView(url: URL(string: resource.url) ?? URL(string: "https://example.com")!)
                .tmiSheetStyle()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(url: resource.url)
                .tmiSheetStyle()
        }
        .alert("Resource Bookmarked", isPresented: $showBookmarkConfirmation) {
            Button("OK") { }
        } message: {
            Text("\(resource.title) has been added to your bookmarks.")
        }
        .alert("Delete Resource", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(resource.title)'? This action cannot be undone.")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background with category color
            LinearGradient(
                gradient: Gradient(colors: [
                    resource.category.color.opacity(0.8),
                    resource.category.color
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            
            // Category icon (watermarked)
            Image(systemName: resource.category.icon)
                .font(.system(size: 120))
                .foregroundColor(.white.opacity(0.1))
                .offset(x: 50, y: -30)
                .rotationEffect(.degrees(-15))
            
            // Content overlay
            VStack(alignment: .leading, spacing: 12) {
                // Category badge
                Text(resource.category.rawValue.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                    .foregroundColor(.white)
                
                // Title
                Text(resource.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(3)
                
                // Quick metadata
                HStack(spacing: 16) {
                    Label(formatDate(resource.createdAt), systemImage: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if resource.isFeatured {
                        Label("Featured", systemImage: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("About This Resource")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(resource.description)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(20)
        }
        .padding(.horizontal)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    // MARK: - Enhanced Metadata Section
    
    private var enhancedMetadataSection: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Resource Details")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    MetadataRow(icon: "calendar", label: "Published", value: formatDate(resource.createdAt))
                    MetadataRow(icon: "arrow.up.right.square", label: "Source", value: extractDomain(from: resource.url))
                    
                    if !resource.recommendedFor.isEmpty {
                        MetadataRow(icon: "person.2", label: "Recommended for", value: resource.recommendedFor.joined(separator: ", "))
                    }
                    
                    if resource.isFeatured {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text("Featured Resource")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(20)
        }
        .padding(.horizontal)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateContent)
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tags")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(resource.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(resource.category.color.opacity(0.2))
                                )
                                .foregroundColor(resource.category.color)
                        }
                    }
                }
            }
            .padding(20)
        }
        .padding(.horizontal)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            TMIButton(
                text: "Open Resource",
                icon: "arrow.up.right.square",
                style: .primary,
                action: {
                    showWebView = true
                }
            )
            
            HStack(spacing: 12) {
                TMIButton(
                    text: isBookmarked ? "Bookmarked" : "Bookmark",
                    icon: isBookmarked ? "bookmark.fill" : "bookmark",
                    style: .secondary,
                    action: {
                        Task {
                            await toggleBookmark()
                        }
                    }
                )
                
                TMIButton(
                    text: "Share",
                    icon: "square.and.arrow.up",
                    style: .secondary,
                    action: {
                        showShareSheet = true
                    }
                )
            }
        }
        .padding(.horizontal)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: animateContent)
    }
    
    // MARK: - Career Connections Section
    
    private var careerConnectionsSection: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Related Careers")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("View All") {
                        // Navigate to career explorer filtered by this resource's tags
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.tmiSecondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(careerRecommendations.prefix(3), id: \.id) { career in
                            NavigationLink(destination: CareerDetailView(career: career, student: nil)) {
                                CompactCareerCard(career: career)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
        .padding(.horizontal)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }
    
    // MARK: - Related Resources Section
    
    private var relatedResourcesSection: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Related Resources")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    ForEach(relatedResources.prefix(3), id: \.id) { relatedResource in
                        NavigationLink(destination: ResourceDetailView(resource: relatedResource)) {
                            CompactResourceRow(resource: relatedResource)
                        }
                    }
                }
            }
            .padding(20)
        }
        .padding(.horizontal)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: animateContent)
    }
    
    // MARK: - Data Loading
    
    private func loadResourceData() async {
        isLoading = true
        
        do {
            // Load related resources
            relatedResources = try await resourceService.fetchResources(withTags: resource.tags)
            
            // Load career recommendations based on resource content
            let allCareers = try await careerService.fetchAllCareers()
            careerRecommendations = findRelatedCareers(from: allCareers)
            
        } catch {
            print("Failed to load resource data: \(error)")
        }
        
        isLoading = false
    }
    
    private func findRelatedCareers(from careers: [Career]) -> [Career] {
        let resourceKeywords = Set(resource.tags.map { $0.lowercased() } + 
                                 [resource.title.lowercased(), resource.category.rawValue.lowercased()])
        
        return careers.filter { career in
            let careerKeywords = Set([career.field.lowercased(), career.title.lowercased()] + 
                                   career.skills.map { $0.lowercased() })
            return !careerKeywords.intersection(resourceKeywords).isEmpty
        }.prefix(5).map { $0 }
    }
    
    // MARK: - Helper Methods
    
    private func toggleBookmark() async {
        // Implement bookmark functionality
        isBookmarked.toggle()
        if isBookmarked {
            showBookmarkConfirmation = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Unknown" }
        return url.host ?? "Unknown"
    }
}

// MARK: - Supporting Views

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
}

struct CompactCareerCard: View {
    let career: Career
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: getCareerIcon(field: career.field))
                    .font(.system(size: 16))
                    .foregroundColor(.tmiSecondary)
                
                Spacer()
                
                Text(career.field)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text(career.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text("$\(Int(career.salaryRange.lowerBound/1000))k+")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.tmiSecondary)
        }
        .padding(12)
        .frame(width: 140, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func getCareerIcon(field: String) -> String {
        switch field {
        case "Technology": return "desktopcomputer"
        case "Healthcare": return "heart.text.square"
        case "Education": return "book"
        case "Business": return "briefcase"
        case "Engineering": return "gearshape.2"
        case "Arts": return "paintpalette"
        case "Science": return "atom"
        default: return "star"
        }
    }
}

struct CompactResourceRow: View {
    let resource: Resource
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(resource.category.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: resource.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(resource.category.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(resource.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Safari Web View

#if canImport(UIKit) && canImport(SafariServices)
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}
#else
struct SafariWebView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.largeTitle)
            Link("Open Resource in Browser", destination: url)
        }
        .padding()
    }
}
#endif

// MARK: - Share Sheet

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let url: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = [url]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
#else
struct ShareSheet: View {
    let url: String

    var body: some View {
        ShareLink(item: url) {
            Label("Share Resource", systemImage: "square.and.arrow.up")
        }
        .padding()
    }
}
#endif


// MARK: - Preview

#Preview {
    NavigationView {
        ResourceDetailView(resource: Resource.sampleResources.first!)
    }
}
