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

// MARK: - Foundation Models Service

@available(iOS 18.0, *)
final class FoundationModelsService: @unchecked Sendable {
    static let shared = FoundationModelsService()
    private init() {}
    
    // Foundation Models cache and configuration
    nonisolated(unsafe) private var foundationModel: Any? = nil
    nonisolated(unsafe) private var modelConfiguration = FoundationModelConfiguration()
    nonisolated(unsafe) private var modelCache: [FoundationModelType: Any] = [:]
    
    // MARK: - Model Management
    
    @available(iOS 26.0, *)
    @MainActor
    func clearModelCache() {
        modelCache.removeAll()
        foundationModel = nil
        print("[FoundationModelsService] Foundation Models cache cleared")
    }
    
    @available(iOS 26.0, *)
    @MainActor
    func preloadModels() async {
        let modelTypes: [FoundationModelType] = [.educationalAnalysis, .studentEngagement, .interventionPlanning]
        
        for modelType in modelTypes {
            do {
                let previousType = modelConfiguration.modelType
                configureFoundationModel(type: modelType)
                let _ = try await loadFoundationModel()
                modelConfiguration = FoundationModelConfiguration(modelType: previousType)
                print("[FoundationModelsService] Preloaded \(modelType.rawValue) model")
            } catch {
                print("[FoundationModelsService] Failed to preload \(modelType.rawValue) model: \(error)")
            }
        }
    }
    
    // MARK: - Configuration Methods
    
    @MainActor
    func configureFoundationModel(type: FoundationModelType, temperature: Float = 0.7) {
        modelConfiguration = FoundationModelConfiguration(
            modelType: type,
            temperature: temperature
        )
    }
    
    // MARK: - Apple Intelligence Integration
    
    func isAppleIntelligenceAvailable() async -> Bool {
        // Check if device supports Apple Intelligence and Foundation Models (iOS 26+)
        if #available(iOS 26.0, *) {
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
        return false
    }
    
    @available(iOS 26.0, *)
    func loadFoundationModel() async throws -> Any {
        // Check if we have a cached model for the current configuration
        if let cachedModel = modelCache[modelConfiguration.modelType] {
            return cachedModel
        }
        
        #if canImport(FoundationModels)
        // Create a language model session with system instructions
        let systemInstructions = modelConfiguration.modelType.systemPrompt
        let session = FoundationModels.LanguageModelSession(instructions: systemInstructions)
        
        // Cache the loaded model for this type
        modelCache[modelConfiguration.modelType] = session
        foundationModel = session
        return session
        #else
        throw AIInsightsError.foundationModelsUnavailable
        #endif
    }
    
    // MARK: - AI Generation Methods
    
    @available(iOS 26.0, *)
    @MainActor
    func generateCareerDataFromSearch(query: String, student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse {
        guard await isAppleIntelligenceAvailable() else {
            print("[FoundationModelsService] Apple Intelligence not available for career search, falling back to sample data.")
            return AICareerGenerator.shared.generateSampleCareerSearchResponse(query: query, student: student)
        }

        let previousType = modelConfiguration.modelType
        configureFoundationModel(type: .careerExploration)

        do {
            let model = try await loadFoundationModel()
            let prompt = promptBuilder.generateCareerSearchPrompt(query: query, student: student)
            
            var response: Any
            
            #if canImport(FoundationModels)
            guard let session = model as? FoundationModels.LanguageModelSession else {
                throw AIInsightsError.modelLoadingFailed("Failed to cast Foundation Model to expected type.")
            }
            
            // Use the actual Foundation Models API to generate response
            response = try await session.respond(to: prompt)
            print("[FoundationModelsService] Generated AI career response for query: '\(query)'")
            #else
            throw AIInsightsError.foundationModelsUnavailable
            #endif
            let aiResponse = try parseAICareerResponse(response)
            
            // Restore previous configuration
            modelConfiguration = FoundationModelConfiguration(modelType: previousType)
            return aiResponse
        } catch {
            print("[FoundationModelsService] AI career search failed: \(error), falling back to sample data.")
            // Restore previous configuration
            modelConfiguration = FoundationModelConfiguration(modelType: previousType)
            return AICareerGenerator.shared.generateSampleCareerSearchResponse(query: query, student: student)
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    func generateCareerData(for student: Student?, promptBuilder: AIPromptBuilder) async throws -> AICareerResponse {
        guard await isAppleIntelligenceAvailable() else {
            print("[FoundationModelsService] Apple Intelligence not available for career data, falling back to sample data.")
            return AICareerGenerator.shared.generateSampleAICareerResponse(for: student)
        }

        let previousType = modelConfiguration.modelType
        configureFoundationModel(type: .careerExploration)

        do {
            let model = try await loadFoundationModel()
            let prompt = promptBuilder.generateCareerPrompt(for: student)
            
            var response: Any // Declare response here
            
            #if canImport(FoundationModels)
            guard let session = model as? FoundationModels.LanguageModelSession else {
                throw AIInsightsError.modelLoadingFailed("Failed to cast Foundation Model to expected type.")
            }
            response = try await session.respond(to: prompt)
            #else
            // Fallback for when FoundationModels is not available
            throw AIInsightsError.foundationModelsUnavailable
            #endif
            let aiResponse = try parseAICareerResponse(response)
            
            // Restore previous configuration
            modelConfiguration = FoundationModelConfiguration(modelType: previousType)
            return aiResponse
        } catch {
            print("[FoundationModelsService] AI career data generation failed: \(error), falling back to sample data.")
            // Restore previous configuration
            modelConfiguration = FoundationModelConfiguration(modelType: previousType)
            return AICareerGenerator.shared.generateSampleAICareerResponse(for: student)
        }
    }
    
    @available(iOS 26.0, *)
    func generateAIInsights(from dashboardData: DashboardData, promptBuilder: AIPromptBuilder) async throws -> [AIInsight] {
        // Prepare data context for AI analysis
        let dataContext = prepareDataContext(from: dashboardData)
        
        #if canImport(FoundationModels)
        // Real Foundation Models implementation for iOS 26+
        do {
            // Load the Foundation Model
            let model = try await loadFoundationModel()
            
            guard let session = model as? FoundationModels.LanguageModelSession else {
                throw AIInsightsError.modelLoadingFailed("Failed to cast Foundation Model to expected type.")
            }
            // Generate comprehensive analysis prompt
            let prompt = promptBuilder.generateAnalysisPrompt(from: dataContext)
            
            // Generate insights using Foundation Models
            let response = try await session.respond(to: prompt)
            print("[FoundationModelsService] Generated AI insights with Foundation Models")
            
            // Parse the AI response into structured insights
            let insights = try parseFoundationModelResponse(response)
            
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
    
    // MARK: - Response Parsing
    
    @available(iOS 26.0, *)
    func parseAICareerResponse(_ response: Any) throws -> AICareerResponse {
        #if canImport(FoundationModels)
        let responseText: String
        if let stringResponse = response as? String {
            responseText = stringResponse
        } else {
            // Try to extract text from FoundationModels response object
            responseText = String(describing: response)
        }
        
        // Clean the response text to extract just the JSON
        let cleanedResponse = extractJSONFromResponse(responseText)
        
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw AIInsightsError.responseParsingFailed("Could not convert response to data")
        }
        
        do {
            // Parse the JSON response
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let careersArray = jsonObject["careers"] as? [[String: Any]],
               let insightsObject = jsonObject["insights"] as? [String: Any] {
                
                // Parse careers
                var careers: [Career] = []
                for careerData in careersArray {
                    if let career = parseCareerFromAI(careerData) {
                        careers.append(career)
                    }
                }
                
                // Parse insights
                let insights = parseInsightsFromAI(insightsObject, careers: careers)
                
                return AICareerResponse(careers: careers, insights: insights)
            } else {
                throw AIInsightsError.responseParsingFailed("Invalid JSON structure")
            }
        } catch {
            print("JSON Parsing Error: \(error)")
            print("Response text: \(cleanedResponse)")
            throw AIInsightsError.responseParsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
        #else
        throw AIInsightsError.foundationModelsUnavailable
        #endif
    }
    
    @available(iOS 26.0, *)
    func parseFoundationModelResponse(_ response: Any) throws -> [AIInsight] {
        #if canImport(FoundationModels)
        let responseText: String
        if let stringResponse = response as? String {
            responseText = stringResponse
        } else {
            // Try to extract text from FoundationModels response object
            responseText = String(describing: response)
        }
        
        // Parse the JSON response
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AIInsightsError.responseParsingFailed("Could not convert response to data")
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let insightsArray = jsonResponse?["insights"] as? [[String: Any]] else {
                throw AIInsightsError.responseParsingFailed("Invalid JSON structure")
            }
            
            var insights: [AIInsight] = []
            
            for insightData in insightsArray {
                if let insight = parseIndividualInsight(from: insightData) {
                    insights.append(insight)
                }
            }
            
            return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
            
        } catch {
            throw AIInsightsError.responseParsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
        #else
        throw AIInsightsError.foundationModelsUnavailable
        #endif
    }
    
    func parseIndividualInsight(from data: [String: Any]) -> AIInsight? {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let confidence = data["confidence"] as? Double,
              let priorityString = data["priority"] as? String,
              let categoryString = data["category"] as? String else {
            print("[FoundationModelsService] Failed to parse insight: missing required fields")
            return nil
        }
        
        // Map string values to enum cases
        let priority = mapStringToPriority(priorityString)
        let category = mapStringToCategory(categoryString)
        
        let actionItems = data["actionItems"] as? [String] ?? []
        let dataPoints = data["dataPoints"] as? [String] ?? []
        
        return AIInsight(
            title: title,
            description: description,
            confidence: min(max(confidence, 0.0), 1.0), // Clamp between 0.0 and 1.0
            priority: priority,
            category: category,
            actionItems: actionItems,
            dataPoints: dataPoints
        )
    }
    
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
    
    // MARK: - JSON Parsing Helpers
    
    func extractJSONFromResponse(_ text: String) -> String {
        // Remove markdown code blocks if present
        var cleanedText = text
        if cleanedText.contains("```json") {
            cleanedText = cleanedText.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedText.contains("```") {
            cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
        }
        
        // Remove any text after the JSON ends (like trailing prompt text)
        if let startIndex = cleanedText.firstIndex(of: "{") {
            // Find the last complete JSON object
            var braceCount = 0
            var endIndex = startIndex
            
            for (index, char) in cleanedText[startIndex...].enumerated() {
                let currentIndex = cleanedText.index(startIndex, offsetBy: index)
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        endIndex = currentIndex
                        break
                    }
                }
            }
            
            let jsonString = String(cleanedText[startIndex...endIndex])
            
            // Fix escaped quotes and newlines
            let fixedString = jsonString
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "")
                .replacingOccurrences(of: "\\'", with: "'")
            
            return fixedString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parseCareerFromAI(_ data: [String: Any]) -> Career? {
        guard let title = data["title"] as? String,
              let field = data["field"] as? String,
              let description = data["description"] as? String,
              let skills = data["skills"] as? [String],
              let education = data["education"] as? String,
              let lowerBound = data["salaryRangeLowerBound"] as? Double,
              let upperBound = data["salaryRangeUpperBound"] as? Double,
              let jobOutlook = data["jobOutlook"] as? String,
              let growthRate = data["growthRate"] as? Double else {
            print("[FoundationModelsService] Failed to parse career from AI data: missing required fields")
            return nil
        }
        
        return Career(
            title: title,
            field: field,
            description: description,
            skills: skills,
            education: education,
            salaryRange: lowerBound...upperBound,
            jobOutlook: jobOutlook,
            growthRate: growthRate
        )
    }
    
    func parseInsightsFromAI(_ data: [String: Any], careers: [Career]) -> CareerDiscoveryInsights {
        let totalCareersExplored = data["totalCareersExplored"] as? Int ?? careers.count
        let personalizedRecommendations = data["personalizedRecommendations"] as? Int ?? 0
        let topInterestCategory = data["topInterestCategory"] as? String ?? "General"
        let strongestCareerFields = data["strongestCareerFields"] as? [String] ?? Array(Set(careers.map { $0.field }))
        let skillGaps = data["skillGaps"] as? [String] ?? []
        let nextSteps = data["nextSteps"] as? [String] ?? []
        
        // Get emerging opportunities from careers with high growth rate
        let emergingOpportunities = careers.filter { $0.growthRate > 0.15 }.prefix(3).map { $0 }
        
        return CareerDiscoveryInsights(
            totalCareersExplored: totalCareersExplored,
            personalizedRecommendations: personalizedRecommendations,
            topInterestCategory: Array(strongestCareerFields.prefix(1)).first ?? topInterestCategory,
            strongestCareerFields: Array(strongestCareerFields.prefix(3)),
            emergingOpportunities: Array(emergingOpportunities),
            skillGaps: skillGaps,
            nextSteps: nextSteps
        )
    }
}
