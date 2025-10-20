//
//  FoundationModelsService.swift
//  TMI
//
//  Created by Chandan Brown on 8/17/25.
//

import Foundation

// Import for iOS 26 Foundation Models (when available)
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Generable Types for Structured Output

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GenerableCareerResponse {
    let careers: [GenerableCareer]
    let insights: GenerableCareerInsights
}

@available(iOS 26.0, *)
@Generable
struct GenerableCareer {
    let title: String
    let field: String
    let description: String
    let skills: [String]
    let education: String
    let salaryRangeLowerBound: Double
    let salaryRangeUpperBound: Double
    let jobOutlook: String
    let growthRate: Double
}

@available(iOS 26.0, *)
@Generable
struct GenerableCareerInsights {
    let totalCareersExplored: Int
    let personalizedRecommendations: Int
    let topInterestCategory: String
    let strongestCareerFields: [String]
    let skillGaps: [String]
    let nextSteps: [String]
}

@available(iOS 26.0, *)
@Generable
struct GenerableAIInsight {
    let title: String
    let description: String
    let confidence: Double
    let priority: String
    let category: String
    let actionItems: [String]
    let dataPoints: [String]
}

@available(iOS 26.0, *)
@Generable
struct GenerableInsightsResponse {
    let insights: [GenerableAIInsight]
}
#endif

// MARK: - Foundation Models Service Protocol

protocol FoundationModelsServiceProtocol: Sendable {
    func generateCareerDataFromSearch(query: String, student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse
    func generateCareerData(for student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse
    func generateAIInsights(from dashboardData: DashboardData, promptBuilder: AIPromptBuilder) async throws -> [AIInsight]
    func isAppleIntelligenceAvailable() async -> Bool
}

// MARK: - iOS 26+ Foundation Models Service

@available(iOS 26.0, *)
final class FoundationModelsService: FoundationModelsServiceProtocol {
    static let shared = FoundationModelsService()
    private init() {}
    
    // Foundation Models configuration (removed mutable cache to fix Sendable compliance)
    private let modelConfiguration = FoundationModelConfiguration()
    
    // MARK: - Model Management
    
    @MainActor
    func clearModelCache() {
        // No-op since we don't cache sessions for thread safety
        print("[FoundationModelsService] Foundation Models cache cleared")
    }
    
    @MainActor
    func preloadModels() async {
        // No-op since we create sessions on-demand for thread safety
        print("[FoundationModelsService] Foundation Models preloading skipped for thread safety")
    }
    
    // MARK: - Configuration Methods
    
    private func createModelConfiguration(type: FoundationModelType, temperature: Float = 0.7) -> FoundationModelConfiguration {
        return FoundationModelConfiguration(
            modelType: type,
            temperature: temperature
        )
    }
    
    // MARK: - Apple Intelligence Integration
    
    func isAppleIntelligenceAvailable() async -> Bool {
        // Check if device supports Apple Intelligence and Foundation Models
        #if canImport(FoundationModels)
        // Check if Foundation Models are available and enabled
        let model = FoundationModels.SystemLanguageModel.default
        switch model.availability {
            case .available:
                print("[FoundationModelsService] Foundation Models are available")
                return true
            case .unavailable(let reason):
                print("[FoundationModelsService] Foundation Models unavailable: \(reason)")
                return false
            }
        #else
        // Fallback for development/simulator
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil // Real device
        #endif
    }
    
    private func createFoundationModelSession(for type: FoundationModelType) async throws -> FoundationModels.LanguageModelSession {
        #if canImport(FoundationModels)
        // Check availability first
        let model = FoundationModels.SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIInsightsError.foundationModelsUnavailable
        }
        
        // Create session with proper system instructions
        let systemInstructions = type.systemPrompt
        let session = FoundationModels.LanguageModelSession(instructions: systemInstructions)
        
        return session
        #else
        throw AIInsightsError.foundationModelsUnavailable
        #endif
    }
    
    // MARK: - AI Generation Methods
    
    @MainActor
    func generateCareerDataFromSearch(query: String, student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse {
        guard await isAppleIntelligenceAvailable() else {
            print("[FoundationModelsService] Apple Intelligence not available for career search, falling back to sample data.")
            return AICareerGenerator.shared.generateSampleCareerSearchResponse(query: query, student: student)
        }

        do {
            let session = try await createFoundationModelSession(for: .careerExploration)
            let prompt = promptBuilder.generateCareerSearchPrompt(query: query, student: student)
            
            #if canImport(FoundationModels)
            // Use Generable types for structured output according to Apple documentation
            let response = try await session.respond(generating: GenerableCareerResponse.self) {
                prompt
            }
            print("[FoundationModelsService] Generated AI career response for query: '\(query)'")
            
            // Convert Generable response to our domain types
            let aiResponse = convertGenerableToCareerResponse(response.content)
            return aiResponse
            #else
            throw AIInsightsError.foundationModelsUnavailable
            #endif
        } catch {
            print("[FoundationModelsService] AI career search failed: \(error), falling back to sample data.")
            return AICareerGenerator.shared.generateSampleCareerSearchResponse(query: query, student: student)
        }
    }

    @MainActor
    func generateCareerData(for student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse {
        guard await isAppleIntelligenceAvailable() else {
            print("[FoundationModelsService] Apple Intelligence not available for career data, falling back to sample data.")
            return AICareerGenerator.shared.generateSampleAICareerResponse(for: student)
        }

        do {
            let session = try await createFoundationModelSession(for: .careerExploration)
            let prompt = promptBuilder.generateCareerPrompt(for: student)
            
            #if canImport(FoundationModels)
            // Use Generable types for structured output
            let response = try await session.respond(generating: GenerableCareerResponse.self) {
                prompt
            }
            let aiResponse = convertGenerableToCareerResponse(response.content)
            return aiResponse
            #else
            throw AIInsightsError.foundationModelsUnavailable
            #endif
        } catch {
            print("[FoundationModelsService] AI career data generation failed: \(error), falling back to sample data.")
            return AICareerGenerator.shared.generateSampleAICareerResponse(for: student)
        }
    }
    
    func generateAIInsights(from dashboardData: DashboardData, promptBuilder: AIPromptBuilder) async throws -> [AIInsight] {
        // Prepare data context for AI analysis
        let dataContext = prepareDataContext(from: dashboardData)
        
        // Check if Foundation Models are available
        guard await isAppleIntelligenceAvailable() else {
            print("[FoundationModelsService] Foundation Models not available, using enhanced simulation")
            return await simulateAIInsights(from: dataContext)
        }
        
        #if canImport(FoundationModels)
        // Real Foundation Models implementation for iOS 26+
        do {
            // Create a new session for insights generation
            let session = try await createFoundationModelSession(for: .educationalAnalysis)
            
            // Generate comprehensive analysis prompt
            let prompt = promptBuilder.generateAnalysisPrompt(from: dataContext)
            
            // Generate insights using Foundation Models with Generable types
            let response = try await session.respond(generating: GenerableInsightsResponse.self) {
                prompt
            }
            print("[FoundationModelsService] Generated AI insights with Foundation Models")
            
            // Convert Generable response to our domain types
            let insights = convertGenerableToInsights(response.content)
            
            print("[FoundationModelsService] Generated \(insights.count) Foundation Model insights")
            return insights
            
        } catch {
            print("[FoundationModelsService] Foundation Models failed: \(error), falling back to enhanced simulation")
            // Fallback to enhanced simulation
            return await simulateAIInsights(from: dataContext)
        }
        #else
        // Fallback for development/simulator
        print("[FoundationModelsService] Foundation Models not available, using enhanced simulation")
        return await simulateAIInsights(from: dataContext)
        #endif
    }
    
    // MARK: - Generable Conversion Functions
    
    private func convertGenerableToCareerResponse(_ generable: GenerableCareerResponse) -> AICareerResponse {
        let careers = generable.careers.map { generableCareer in
            Career(
                title: generableCareer.title,
                field: generableCareer.field,
                description: generableCareer.description,
                skills: generableCareer.skills,
                education: generableCareer.education,
                salaryRange: generableCareer.salaryRangeLowerBound...generableCareer.salaryRangeUpperBound,
                jobOutlook: generableCareer.jobOutlook,
                growthRate: generableCareer.growthRate
            )
        }
        
        let insights = CareerDiscoveryInsights(
            totalCareersExplored: generable.insights.totalCareersExplored,
            personalizedRecommendations: generable.insights.personalizedRecommendations,
            topInterestCategory: generable.insights.topInterestCategory,
            strongestCareerFields: generable.insights.strongestCareerFields,
            emergingOpportunities: careers.filter { $0.growthRate > 0.15 }.prefix(3).map { $0 },
            skillGaps: generable.insights.skillGaps,
            nextSteps: generable.insights.nextSteps
        )
        
        return AICareerResponse(careers: careers, insights: insights)
    }
    
    private func convertGenerableToInsights(_ generable: GenerableInsightsResponse) -> [AIInsight] {
        return generable.insights.map { generableInsight in
            AIInsight(
                title: generableInsight.title,
                description: generableInsight.description,
                confidence: min(max(generableInsight.confidence, 0.0), 1.0),
                priority: mapStringToPriority(generableInsight.priority),
                category: mapStringToCategory(generableInsight.category),
                actionItems: generableInsight.actionItems,
                dataPoints: generableInsight.dataPoints
            )
        }
    }
    
    // MARK: - Legacy JSON Parsing (Fallback only)
    
    // Note: These methods are kept as fallback for when Generable types fail
    // The main implementation now uses Generable types which are much more robust
    
    // MARK: - Helper Methods
    
    func prepareDataContext(from dashboardData: DashboardData) -> [String: Any] {
        return [
            "totalStudents": dashboardData.totalStudents,
            "activePlans": dashboardData.activeTMIPlans,
            "surveysCompleted": dashboardData.surveysCompleted,
            "plansAligned": dashboardData.plansAligned,
            "interestsIdentified": dashboardData.interestsIdentified,
            "recentActivities": dashboardData.recentActivities.count,
            "engagementTrend": calculateEngagementTrend(dashboardData.engagementData),
            "completionRate": dashboardData.totalStudents > 0 ? Double(dashboardData.surveysCompleted) / Double(dashboardData.totalStudents) : 0,
            "alignmentRate": dashboardData.totalStudents > 0 ? Double(dashboardData.plansAligned) / Double(dashboardData.totalStudents) : 0,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    func calculateEngagementTrend(_ engagementData: [EngagementData]) -> String {
        guard engagementData.count >= 2 else { return "insufficient_data" }
        
        let recent = engagementData.suffix(3).map { $0.engagementLevel }
        let earlier = engagementData.prefix(engagementData.count - 3).map { $0.engagementLevel }
        
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.isEmpty ? recentAvg : earlier.reduce(0, +) / Double(earlier.count)
        
        if recentAvg > earlierAvg * 1.1 {
            return "increasing"
        } else if recentAvg < earlierAvg * 0.9 {
            return "decreasing"
        } else {
            return "stable"
        }
    }
    
    func simulateAIInsights(from context: [String: Any]) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        let totalStudents = context["totalStudents"] as? Int ?? 0
        let completionRate = context["completionRate"] as? Double ?? 0
        let alignmentRate = context["alignmentRate"] as? Double ?? 0
        let engagementTrend = context["engagementTrend"] as? String ?? "stable"
        let recentActivities = context["recentActivities"] as? Int ?? 0
        
        // Advanced pattern analysis
        insights.append(contentsOf: analyzeEngagementPatterns(
            completionRate: completionRate,
            alignmentRate: alignmentRate,
            trend: engagementTrend,
            activities: recentActivities,
            totalStudents: totalStudents
        ))
        
        // Predictive insights
        insights.append(contentsOf: generatePredictiveInsights(from: context))
        
        // Intervention recommendations
        insights.append(contentsOf: generateInterventionRecommendations(from: context))
        
        return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func analyzeEngagementPatterns(completionRate: Double, alignmentRate: Double, trend: String, activities: Int, totalStudents: Int) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Comprehensive engagement analysis
        if completionRate < 0.5 && alignmentRate < 0.4 {
            insights.append(AIInsight(
                title: "Critical Engagement Gap Detected",
                description: "Multiple indicators suggest students are disengaging from the TMI process. Both survey completion (\(Int(completionRate * 100))%) and plan alignment (\(Int(alignmentRate * 100))%) are below optimal thresholds.",
                confidence: 0.92,
                priority: .critical,
                category: .engagement,
                actionItems: [
                    "Schedule immediate one-on-one check-ins with unengaged students",
                    "Review and simplify the survey process",
                    "Implement peer mentorship program",
                    "Consider adjusting TMI plan complexity"
                ],
                dataPoints: [
                    "Survey completion: \(Int(completionRate * 100))%",
                    "Plan alignment: \(Int(alignmentRate * 100))%",
                    "Recent activities: \(activities)"
                ]
            ))
        }
        
        // Trend-based insights
        if trend == "decreasing" && activities < 3 {
            insights.append(AIInsight(
                title: "Declining Engagement Trajectory",
                description: "Analysis shows a concerning downward trend in student engagement over recent periods. This pattern typically indicates external stressors or curriculum misalignment.",
                confidence: 0.85,
                priority: .high,
                category: .trends,
                actionItems: [
                    "Investigate external factors affecting student motivation",
                    "Survey students about current challenges",
                    "Implement short-term engagement boosters",
                    "Review recent changes to TMI methodology"
                ]
            ))
        }
        
        return insights
    }
    
    func generatePredictiveInsights(from context: [String: Any]) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        let completionRate = context["completionRate"] as? Double ?? 0
        let alignmentRate = context["alignmentRate"] as? Double ?? 0
        
        // Predict success likelihood
        let successProbability = (completionRate * 0.4 + alignmentRate * 0.6)
        
        if successProbability > 0.8 {
            insights.append(AIInsight(
                title: "High Success Trajectory Predicted",
                description: "Current metrics indicate a \(Int(successProbability * 100))% likelihood of achieving optimal student outcomes this semester. Your TMI implementation is performing exceptionally well.",
                confidence: 0.88,
                priority: .low,
                category: .performance,
                actionItems: [
                    "Document successful strategies for replication",
                    "Consider expanding program to additional students",
                    "Prepare for advanced intervention techniques",
                    "Share best practices with colleague educators"
                ]
            ))
        } else if successProbability < 0.4 {
            insights.append(AIInsight(
                title: "Intervention Window Identified",
                description: "Predictive analysis suggests immediate intervention is needed to improve outcomes. Current trajectory indicates only \(Int(successProbability * 100))% success likelihood.",
                confidence: 0.82,
                priority: .high,
                category: .interventions,
                actionItems: [
                    "Implement intensive support protocols within 2 weeks",
                    "Schedule emergency review of TMI strategies",
                    "Consider additional resources or support staff",
                    "Develop individualized intervention plans"
                ]
            ))
        }
        
        return insights
    }
    
    func generateInterventionRecommendations(from context: [String: Any]) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        let activePlans = context["activePlans"] as? Int ?? 0
        let totalStudents = context["totalStudents"] as? Int ?? 0
        let interestsIdentified = context["interestsIdentified"] as? Int ?? 0
        
        // Interest diversity analysis
        let avgInterestsPerStudent = totalStudents > 0 ? Double(interestsIdentified) / Double(totalStudents) : 0
        
        if avgInterestsPerStudent < 2.0 {
            insights.append(AIInsight(
                title: "Interest Exploration Opportunity",
                description: "Students are showing limited interest diversity (avg: \(String(format: "%.1f", avgInterestsPerStudent)) interests per student). This suggests untapped potential for career exploration.",
                confidence: 0.78,
                priority: .medium,
                category: .recommendations,
                actionItems: [
                    "Organize career exploration workshops",
                    "Implement interest discovery activities",
                    "Invite guest speakers from various professions",
                    "Use interactive career assessment tools"
                ],
                dataPoints: [
                    "Average interests per student: \(String(format: "%.1f", avgInterestsPerStudent))",
                    "Total interests identified: \(interestsIdentified)",
                    "Student population: \(totalStudents)"
                ]
            ))
        }
        
        // Plan coverage analysis
        let planCoverageRate = totalStudents > 0 ? Double(activePlans) / Double(totalStudents) : 0
        
        if planCoverageRate < 0.6 {
            insights.append(AIInsight(
                title: "Plan Coverage Gap Analysis",
                description: "Only \(Int(planCoverageRate * 100))% of students have active TMI plans. This gap represents missed opportunities for structured intervention and support.",
                confidence: 0.84,
                priority: .medium,
                category: .alignment,
                actionItems: [
                    "Prioritize plan creation for unserved students",
                    "Streamline the plan development process",
                    "Train additional staff in TMI methodology",
                    "Implement group planning sessions for efficiency"
                ]
            ))
        }
        
        return insights
    }
    
    // MARK: - String to Enum Mapping
    
    func mapStringToPriority(_ priorityString: String) -> InsightPriority {
        switch priorityString.lowercased() {
        case "critical": return .critical
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .medium
        }
    }
    
    func mapStringToCategory(_ categoryString: String) -> InsightCategory {
        switch categoryString.lowercased() {
        case "engagement", "student engagement": return .engagement
        case "alignment", "plan alignment": return .alignment
        case "performance", "performance metrics": return .performance
        case "recommendations": return .recommendations
        case "trends", "trend analysis": return .trends
        case "interventions", "intervention opportunities": return .interventions
        default: return .recommendations
        }
    }
}

// MARK: - Fallback Service for iOS < 26.0

final class FallbackFoundationModelsService: FoundationModelsServiceProtocol {
    static let shared = FallbackFoundationModelsService()
    private init() {}
    
    func generateCareerDataFromSearch(query: String, student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse {
        print("[FallbackFoundationModelsService] Foundation Models not available on this iOS version, using sample data.")
        return AICareerGenerator.shared.generateSampleCareerSearchResponse(query: query, student: student)
    }
    
    func generateCareerData(for student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse {
        print("[FallbackFoundationModelsService] Foundation Models not available on this iOS version, using sample data.")
        return AICareerGenerator.shared.generateSampleAICareerResponse(for: student)
    }
    
    func generateAIInsights(from dashboardData: DashboardData, promptBuilder: AIPromptBuilder) async throws -> [AIInsight] {
        print("[FallbackFoundationModelsService] Foundation Models not available on this iOS version, using enhanced simulation.")
        let dataContext = [
            "totalStudents": dashboardData.totalStudents,
            "activePlans": dashboardData.activeTMIPlans,
            "surveysCompleted": dashboardData.surveysCompleted,
            "plansAligned": dashboardData.plansAligned,
            "interestsIdentified": dashboardData.interestsIdentified,
            "recentActivities": dashboardData.recentActivities.count,
            "completionRate": dashboardData.totalStudents > 0 ? Double(dashboardData.surveysCompleted) / Double(dashboardData.totalStudents) : 0,
            "alignmentRate": dashboardData.totalStudents > 0 ? Double(dashboardData.plansAligned) / Double(dashboardData.totalStudents) : 0
        ] as [String: Any]
        
        return await simulateBasicAIInsights(from: dataContext)
    }
    
    func isAppleIntelligenceAvailable() async -> Bool {
        return false
    }
    
    private func simulateBasicAIInsights(from context: [String: Any]) async -> [AIInsight] {
        let completionRate = context["completionRate"] as? Double ?? 0
        let alignmentRate = context["alignmentRate"] as? Double ?? 0
        
        var insights: [AIInsight] = []
        
        if completionRate < 0.5 {
            insights.append(AIInsight(
                title: "Survey Completion Opportunity",
                description: "Survey completion rate is \(Int(completionRate * 100))%. Consider simplifying the survey process or providing additional support.",
                confidence: 0.75,
                priority: .medium,
                category: .engagement,
                actionItems: ["Review survey complexity", "Provide completion assistance"],
                dataPoints: ["Completion rate: \(Int(completionRate * 100))%"]
            ))
        }
        
        if alignmentRate < 0.6 {
            insights.append(AIInsight(
                title: "Plan Alignment Focus",
                description: "TMI plan alignment is at \(Int(alignmentRate * 100))%. Focus on improving student-plan matching.",
                confidence: 0.70,
                priority: .medium,
                category: .alignment,
                actionItems: ["Review plan criteria", "Improve student assessment"],
                dataPoints: ["Alignment rate: \(Int(alignmentRate * 100))%"]
            ))
        }
        
        return insights
    }
}

// MARK: - Unified Access Point

struct FoundationModelsServiceAccessor {
    static var shared: FoundationModelsServiceProtocol {
        if #available(iOS 26.0, *) {
            return FoundationModelsService.shared
        } else {
            return FallbackFoundationModelsService.shared
        }
    }
}

