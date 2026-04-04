//
//  RecommendationsView.swift
//  TMI
//
//  Created by Chandan Brown on 8/11/25.
//

import SwiftUI

struct RecommendationsView: View {
    let student: Student
    @State private var dashboard: PersonalizedDashboard?
    @State private var suggestions: [TMIPlanSuggestion] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var animateContent = false
    @State private var interests: [Interest] = []
    @State private var interestCount: Int = 0

    private let recommendationsService = RecommendationsService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Student header
                            studentHeaderView
                            
                            // Recommended careers section
                            if let dashboard = dashboard, !dashboard.trendingCareers.isEmpty {
                                recommendedCareersSection(dashboard.trendingCareers)
                            }
                            
                            // Recommended resources section
                            if let dashboard = dashboard, !dashboard.recommendedResources.isEmpty {
                                recommendedResourcesSection(dashboard.recommendedResources)
                            }
                            
                            // TMI Plan suggestions
                            if !suggestions.isEmpty {
                                tmiSuggestionsSection
                            }
                            
                            // Trending section
                            if let dashboard = dashboard {
                                trendingSection(dashboard)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .foregroundColor(.white)
            .task {
                await loadRecommendations()
                await loadInterests()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateContent = true
                }
            }
            .refreshable {
                await loadRecommendations()
            }
        }
    }

    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Generating personalized recommendations...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Student Header
    
    private var studentHeaderView: some View {
        VStack(spacing: 16) {
            Text("Personalized for \(student.displayName)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
            
            HStack(spacing: 16) {
                InterestPill(text: "Grade \(student.grade)", color: .blue)

                if let topInterest = interests.max(by: { ($0.popularityScore ?? 0) < ($1.popularityScore ?? 0) }) {
                    InterestPill(text: topInterest.name, color: .tmiSecondary)
                }

                InterestPill(text: "\(interestCount) interests", color: .purple)
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recommended Careers Section
    
    private func recommendedCareersSection(_ careers: [Career]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Careers")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink("View All") {
                    CareerExplorerView()
                }
                .font(.subheadline)
                .foregroundColor(.tmiSecondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(careers.prefix(5), id: \.id) { career in
                        NavigationLink(destination: CareerDetailView(career: career, student: student)) {
                            RecommendedCareerCard(career: career)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
    }
    
    // MARK: - Recommended Resources Section
    
    private func recommendedResourcesSection(_ resources: [Resource]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Resources")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                NavigationLink("View All") {
                    ResourcesView()
                }
                .font(.subheadline)
                .foregroundColor(.tmiSecondary)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(resources.prefix(5), id: \.id) { resource in
                        NavigationLink(destination: ResourceDetailView(resource: resource)) {
                            RecommendedResourceCard(resource: resource)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
    }
    
    // MARK: - TMI Suggestions Section
    
    private var tmiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Suggestions")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            LazyVStack(spacing: 12) {
                ForEach(suggestions.prefix(3), id: \.id) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                        .padding(.horizontal, 20)
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
    }
    
    // MARK: - Trending Section
    
    private func trendingSection(_ dashboard: PersonalizedDashboard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trending Now")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                if !dashboard.trendingCareers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trending Careers")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dashboard.trendingCareers.prefix(4), id: \.id) { career in
                                    NavigationLink(destination: CareerDetailView(career: career, student: student)) {
                                        TrendingItemCard(
                                            title: career.title,
                                            subtitle: career.field,
                                            icon: "briefcase.fill",
                                            color: .blue
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                if !dashboard.recommendedResources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Featured Resources")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dashboard.recommendedResources.prefix(4), id: \.id) { resource in
                                    NavigationLink(destination: ResourceDetailView(resource: resource)) {
                                        TrendingItemCard(
                                            title: resource.title,
                                            subtitle: resource.category.rawValue.capitalized,
                                            icon: resource.category.icon,
                                            color: resource.category.color
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateContent)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadRecommendations() async {
        isLoading = true
        error = nil
        
        do {
            async let dashboardLoad = recommendationsService.getPersonalizedDashboard(for: student)
            async let suggestionsLoad = recommendationsService.getTMIPlanSuggestions(for: student)
            
            dashboard = try await dashboardLoad
            suggestions = try await suggestionsLoad
            
        } catch {
            self.error = error
            print("Failed to load recommendations: \(error)")
        }
        
        isLoading = false
    }

    @MainActor
    private func loadInterests() async {
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
            interestCount = try await student.getInterestCount()
        } catch {
            print("[RecommendationsView] Error loading interests: \(error.localizedDescription)")
            interests = []
            interestCount = 0
        }
    }
}

// MARK: - Supporting Views

struct InterestPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .foregroundColor(color)
    }
}

struct RecommendedCareerCard: View {
    let career: Career
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("+\(Int(career.growthRate * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            }
            
            Text(career.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(career.field)
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

struct RecommendedResourceCard: View {
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

struct SuggestionCard: View {
    let suggestion: TMIPlanSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerContent
            
            Text(suggestion.rationale)
                .font(.system(size: 13))
                .foregroundColor(.tmiSecondary)
                .lineLimit(2)
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
    }
    
    private var headerContent: some View {
        HStack {
            Image(systemName: suggestion.type.icon)
                .font(.system(size: 20))
                .foregroundColor(.tmiSecondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(suggestion.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        }
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
    }
}

struct TrendingItemCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 120, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .opacity(0.2)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    RecommendationsView(student: Student.sampleStudents.first!)
}
