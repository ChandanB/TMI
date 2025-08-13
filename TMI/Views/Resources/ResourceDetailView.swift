//
//  ResourceDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 8/11/25.
//

import SwiftUI

struct ResourceDetailView: View {
    let resource: Resource
    @State private var animateContent = false
    @State private var showShareSheet = false
    @State private var isBookmarked = false
    @State private var isLoading = false
    @State private var relatedResources: [Resource] = []
    @State private var showWebView = false
    @State private var showBookmarkConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    private let resourceService = ResourceService.shared
    
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
                            
                            // Tags section
                            tagsSection
                            
                            // Recommended for section
                            recommendedForSection
                            
                            // Action buttons
                            actionButtonsSection
                            
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
                }
            }
        }
        .task {
            await loadResourceData()
        }
        .sheet(isPresented: $showWebView) {
            SafariWebView(url: URL(string: resource.url) ?? URL(string: "https://example.com")!)
        }
        .alert("Resource Bookmarked", isPresented: $showBookmarkConfirmation) {
            Button("OK") { }
        } message: {
            Text("\(resource.title) has been added to your bookmarks.")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(url: resource.url)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            resource.category.color.opacity(0.8),
                            resource.category.color,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 280)
            
            // Content overlay
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Category badge
                        HStack(spacing: 8) {
                            Image(systemName: resource.category.icon)
                                .font(.system(size: 14))
                            
                            Text(resource.category.rawValue.capitalized)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                        .foregroundColor(.white)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
                        
                        // Title
                        Text(resource.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
                    }
                    
                    Spacer()
                }
                
                // Resource metadata
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(formatDate(resource.createdAt))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    if resource.isFeatured {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                
                                Text("Featured")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(resource.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !resource.tags.isEmpty {
                Text("Tags")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                FlowLayout(spacing: 8) {
                    ForEach(resource.tags, id: \.self) { tag in
                        TagView(title: tag)
                    }
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
    }
    
    // MARK: - Recommended For Section
    
    private var recommendedForSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !resource.recommendedFor.isEmpty {
                Text("Recommended For")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                FlowLayout(spacing: 8) {
                    ForEach(resource.recommendedFor, id: \.self) { role in
                        RoleView(role: role)
                    }
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateContent)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Open Resource button
            Button(action: {
                if let url = URL(string: resource.url) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 20))
                    
                    Text("Open Resource")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [resource.category.color, resource.category.color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: resource.category.color.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Secondary actions
            HStack(spacing: 12) {
                Button(action: {
                    // Copy URL action
                    UIPasteboard.general.string = resource.url
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy URL")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .background(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .background(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateContent)
    }
    
    // MARK: - Related Resources Section
    
    private var relatedResourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Related Resources")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(relatedResources.prefix(5), id: \.id) { relatedResource in
                        NavigationLink(destination: ResourceDetailView(resource: relatedResource)) {
                            RelatedResourceCard(resource: relatedResource)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: animateContent)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadResourceData() async {
        isLoading = true
        
        do {
            // Load related resources based on tags and category
            relatedResources = try await resourceService.fetchResources(withTags: resource.tags)
                .filter { $0.id != resource.id }
            
            // If not enough related by tags, add some by category
            if relatedResources.count < 3 {
                let categoryResources = try await resourceService.fetchResources(category: resource.category)
                    .filter { categoryResource in
                        categoryResource.id != resource.id && !relatedResources.contains(where: { $0.id == categoryResource.id })
                    }
                
                relatedResources.append(contentsOf: Array(categoryResources.prefix(3 - relatedResources.count)))
            }
            
        } catch {
            // Fallback to sample data
            relatedResources = Resource.sampleResources.filter {
                $0.category == resource.category && $0.id != resource.id
            }.prefix(3).map { $0 }
        }
        
        isLoading = false
    }
    
    @MainActor
    private func toggleBookmark() async {
        // This would integrate with a bookmark service
        isBookmarked.toggle()
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct TagView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(.blue)
    }
}

struct RoleView: View {
    let role: String
    
    var body: some View {
        Text(role)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.tmiSecondary.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.tmiSecondary.opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(.tmiSecondary)
    }
}

struct RelatedResourceCard: View {
    let resource: Resource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: resource.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(resource.category.color)
                
                Spacer()
                
                if resource.isFeatured {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
            }
            
            Text(resource.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(resource.category.rawValue.capitalized)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
        .padding(16)
        .frame(width: 160, height: 120)
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
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
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

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [URL(string: url) ?? url],
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationView {
        ResourceDetailView(resource: Resource.sampleResources.first!)
    }
}

