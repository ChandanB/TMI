//
//  AIInsightsService.swift
//  TMI
//
//  Created by Chandan Brown on 8/13/25.
//

import Foundation
import SwiftUI
import NaturalLanguage

// MARK: - AI Insights Service (Refactored)

@available(iOS 18.0, *)
final class AIInsightsService: Sendable  {
    static let shared = AIInsightsService()
    private init() {}
    
    // Dependency injection for separated services
    private let foundationModelsService = FoundationModelsServiceAccessor.shared
    private let careerGenerator = AICareerGenerator.shared
    private let promptBuilder = AIPromptBuilder.shared
    
    // MARK: - Model Management
    
    @MainActor
    func clearModelCache() {
        // No-op since we use the unified accessor
        print("[AIInsightsService] Model cache cleared")
    }
    
    @MainActor
    func preloadModels() async {
        // No-op since we use the unified accessor
        print("[AIInsightsService] Model preloading skipped")
    }
    
    @MainActor
    func generateSpecializedInsights(from dashboardData: DashboardData, analysisType: FoundationModelType) async -> [AIInsight] {
        // Use the unified service to generate insights
        do {
            return try await foundationModelsService.generateAIInsights(from: dashboardData, promptBuilder: promptBuilder)
        } catch {
            print("[AIInsightsService] Failed to generate specialized insights: \(error)")
            return []
        }
    }
    
    // MARK: - Main Career Generation Methods
    
    @MainActor
    func generateCareerDataFromSearch(query: String, student: Student?) async throws -> AICareerResponse {
        return try await foundationModelsService.generateCareerDataFromSearch(
            query: query,
            student: student,
            promptBuilder: promptBuilder
        )
    }

    @MainActor
    func generateCareerData(for student: Student?) async throws -> AICareerResponse {
        return try await foundationModelsService.generateCareerData(
            for: student,
            promptBuilder: promptBuilder
        )
    }
    
    // MARK: - Main Insights Generation
    
    @MainActor
    func generateInsights(from dashboardData: DashboardData) async -> [AIInsight] {
        // Check if Apple Intelligence is available
        guard await foundationModelsService.isAppleIntelligenceAvailable() else {
            print("[AIInsightsService] Apple Intelligence not available, falling back to rule-based insights")
            return generateRuleBasedInsights(from: dashboardData)
        }
        
        do {
            // Generate insights using Apple's Foundation Models (iOS 26+)
            if #available(iOS 26.0, *) {
                let insights = try await foundationModelsService.generateAIInsights(
                    from: dashboardData,
                    promptBuilder: promptBuilder
                )
                print("[AIInsightsService] Generated \(insights.count) Foundation Model insights")
                return insights
            } else {
                // Rule-based insights for iOS 18.0-25.x
                print("[AIInsightsService] Using enhanced rule-based insights (iOS 18-25)")
                return generateRuleBasedInsights(from: dashboardData)
            }
        } catch {
            print("[AIInsightsService] AI generation failed: \(error), falling back to rule-based")
            return generateRuleBasedInsights(from: dashboardData)
        }
    }
    
    // MARK: - Fallback Rule-Based Insights
    
    func generateRuleBasedInsights(from dashboardData: DashboardData) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        let completionRate = dashboardData.totalStudents > 0 ?
            Double(dashboardData.surveysCompleted) / Double(dashboardData.totalStudents) : 0
        let alignmentRate = dashboardData.totalStudents > 0 ?
            Double(dashboardData.plansAligned) / Double(dashboardData.totalStudents) : 0
        
        // Basic rule-based insights for older iOS versions
        if completionRate < 0.7 {
            insights.append(AIInsight(
                title: "Survey Completion Below Target",
                description: "Survey completion rate is \(Int(completionRate * 100))%. Consider implementing reminder systems.",
                confidence: 0.75,
                priority: .medium,
                category: .engagement,
                actionItems: ["Send survey reminders", "Simplify survey process"]
            ))
        }
        
        if alignmentRate < 0.6 {
            insights.append(AIInsight(
                title: "Plan Alignment Needs Attention",
                description: "Plan alignment rate is \(Int(alignmentRate * 100))%. Focus on individual student meetings.",
                confidence: 0.70,
                priority: .medium,
                category: .alignment,
                actionItems: ["Schedule individual meetings", "Review plan effectiveness"]
            ))
        }
        
        if dashboardData.recentActivities.count < 3 {
            insights.append(AIInsight(
                title: "Low Recent Activity",
                description: "Minimal recent activity detected. Consider engaging students more actively.",
                confidence: 0.65,
                priority: .low,
                category: .engagement,
                actionItems: ["Plan interactive sessions", "Check student availability"]
            ))
        }
        
        return insights
    }
    
    // MARK: - Career Generation Delegation
    
    func generateIntelligentCareers(for query: String, student: Student?) -> [Career] {
        return careerGenerator.generateIntelligentCareers(for: query, student: student)
    }
    
    func generatePersonalizedCareers(for student: Student?) async -> [Career] {
        return await careerGenerator.generatePersonalizedCareers(for: student)
    }
    
    func generateSampleCareerSearchResponse(query: String, student: Student?) -> AICareerResponse {
        return careerGenerator.generateSampleCareerSearchResponse(query: query, student: student)
    }
    
    func generateSampleAICareerResponse(for student: Student?) async -> AICareerResponse {
        return await careerGenerator.generateSampleAICareerResponse(for: student)
    }
    
    // MARK: - Basketball Career Generation (Delegated)
    
    func generateBasketballCareers() -> [Career] {
        return careerGenerator.generateBasketballCareers()
    }
    
    // MARK: - Prompt Generation Delegation
    
    func generateCareerSearchPrompt(query: String, student: Student?) -> String {
        return promptBuilder.generateCareerSearchPrompt(query: query, student: student)
    }
    
    func generateCareerPrompt(for student: Student?) -> String {
        return promptBuilder.generateCareerPrompt(for: student)
    }
    
    func generateAnalysisPrompt(from context: [String: Any]) -> String {
        return promptBuilder.generateAnalysisPrompt(from: context)
    }
    
    // MARK: - Utility Methods (Delegated to appropriate services)
    
    func isAppleIntelligenceAvailable() async -> Bool {
        return await foundationModelsService.isAppleIntelligenceAvailable()
    }
    
    func analyzeSearchContext(query: String) -> SearchContext {
        return careerGenerator.analyzeSearchContext(query: query)
    }
    
    // MARK: - Backward Compatibility Aliases
    
    /// Alias for generateCareerDataFromSearch for backward compatibility
    @MainActor
    func searchCareersWithAI(query: String, student: Student?) async throws -> AICareerResponse {
        return try await generateCareerDataFromSearch(query: query, student: student)
    }
    
    /// Alias for generateCareerData for backward compatibility
    @MainActor
    func getCareerRecommendations(for student: Student?) async throws -> AICareerResponse {
        return try await generateCareerData(for: student)
    }
}
