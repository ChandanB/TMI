//
//  AIInsightsService.swift
//  TMI
//
//  Created by Chandan Brown on 8/13/25.
//

import Foundation
import SwiftUI
import NaturalLanguage
// Import for iOS 26 Foundation Models (when available)
#if canImport(AppleIntelligence)
import AppleIntelligence
#endif

// MARK: - AI Insights Models

struct AIInsight: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let confidence: Double // 0.0 to 1.0
    let priority: InsightPriority
    let category: InsightCategory
    let actionItems: [String]
    let dataPoints: [String]
    let generatedAt: Date
    
    init(title: String, description: String, confidence: Double, priority: InsightPriority, category: InsightCategory, actionItems: [String] = [], dataPoints: [String] = []) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.confidence = confidence
        self.priority = priority
        self.category = category
        self.actionItems = actionItems
        self.dataPoints = dataPoints
        self.generatedAt = Date()
    }
}

enum InsightPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium" 
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

enum InsightCategory: String, CaseIterable, Codable {
    case engagement = "Student Engagement"
    case alignment = "Plan Alignment"
    case performance = "Performance Metrics"
    case recommendations = "Recommendations"
    case trends = "Trend Analysis"
    case interventions = "Intervention Opportunities"
    
    var icon: String {
        switch self {
        case .engagement: return "person.3.fill"
        case .alignment: return "target"
        case .performance: return "chart.bar.fill"
        case .recommendations: return "lightbulb.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .interventions: return "cross.case.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .engagement: return .blue
        case .alignment: return .teal
        case .performance: return .purple
        case .recommendations: return .yellow
        case .trends: return .green
        case .interventions: return .red
        }
    }
}

// MARK: - AI Insights Errors

enum AIInsightsError: Error, LocalizedError {
    case foundationModelsUnavailable
    case modelLoadingFailed(String)
    case promptGenerationFailed(String)
    case responseParsingFailed(String)
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .foundationModelsUnavailable:
            return "Apple Foundation Models are not available on this device"
        case .modelLoadingFailed(let message):
            return "Failed to load Foundation Model: \(message)"
        case .promptGenerationFailed(let message):
            return "Failed to generate analysis prompt: \(message)"
        case .responseParsingFailed(let message):
            return "Failed to parse Foundation Model response: \(message)"
        case .invalidConfiguration:
            return "Invalid Foundation Model configuration"
        }
    }
}

// MARK: - Foundation Models Configuration

struct FoundationModelConfiguration {
    let modelType: FoundationModelType
    let maxTokens: Int
    let temperature: Float
    let topP: Float
    let presencePenalty: Float
    let frequencyPenalty: Float
    
    init(modelType: FoundationModelType = .educationalAnalysis,
         maxTokens: Int = 2048,
         temperature: Float = 0.7,
         topP: Float = 0.9,
         presencePenalty: Float = 0.1,
         frequencyPenalty: Float = 0.1) {
        self.modelType = modelType
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }
}

enum FoundationModelType: String, CaseIterable {
    case educationalAnalysis = "educational-analysis-v1"
    case studentEngagement = "student-engagement-v1"
    case interventionPlanning = "intervention-planning-v1"
    case careerExploration = "career-exploration-v1"
    
    var systemPrompt: String {
        switch self {
        case .educationalAnalysis:
            return """
            You are an expert educational data analyst specializing in Tangible Modification Intervention (TMI) systems. 
            Your role is to analyze student engagement data, survey completion rates, and TMI plan effectiveness to provide actionable insights for educators.
            
            Focus on:
            - Identifying patterns in student engagement and participation
            - Predicting intervention success likelihood
            - Recommending specific actions to improve student outcomes
            - Detecting early warning signs of disengagement
            
            Provide insights with confidence scores and specific action items.
            """
        case .studentEngagement:
            return """
            You are a student engagement specialist with expertise in TMI methodologies.
            Analyze engagement patterns, survey data, and interaction frequency to identify students at risk and recommend targeted interventions.
            """
        case .interventionPlanning:
            return """
            You are an intervention planning expert focused on TMI strategies.
            Analyze student data to recommend optimal intervention approaches, timing, and resource allocation.
            """
        case .careerExploration:
            return """
            You are an expert career counselor and educational guide. Your role is to generate comprehensive career profiles and personalized recommendations based on user interests, skills, and academic data.
            
            Focus on:
            - Providing detailed career descriptions, required skills, education paths, salary ranges, and job outlooks.
            - Identifying emerging career opportunities.
            - Suggesting skill development paths and next steps for career exploration.
            - Tailoring recommendations to individual student profiles.
            
            Output should be structured as a JSON object containing an array of career profiles and a career discovery insights summary.
            """
        }
    }
}

// MARK: - AI Insights Service

@available(iOS 18.0, *)
class AIInsightsService {
    static let shared = AIInsightsService()
    private init() {}
    
    // Foundation Models cache and configuration
    private var foundationModel: Any? = nil
    private var modelConfiguration = FoundationModelConfiguration()
    private var modelCache: [FoundationModelType: Any] = [:]
    
    // MARK: - Model Management
    
    @available(iOS 26.0, *)
    @MainActor
    func clearModelCache() {
        modelCache.removeAll()
        foundationModel = nil
        print("[AIInsightsService] Foundation Models cache cleared")
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
                print("[AIInsightsService] Preloaded \(modelType.rawValue) model")
            } catch {
                print("[AIInsightsService] Failed to preload \(modelType.rawValue) model: \(error)")
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
    
    @available(iOS 26.0, *)
    @MainActor
    func generateSpecializedInsights(from dashboardData: DashboardData, analysisType: FoundationModelType) async -> [AIInsight] {
        let previousType = modelConfiguration.modelType
        configureFoundationModel(type: analysisType)
        
        let insights = await generateInsights(from: dashboardData)
        
        // Restore previous configuration
        modelConfiguration = FoundationModelConfiguration(modelType: previousType)
        
        return insights
    }
    
    // MARK: - Main Insights Generation
    
    // Define a new struct to hold the AI-generated career data and insights
    struct AICareerResponse: Codable {
        let careers: [Career]
        let insights: CareerDiscoveryInsights
    }

    @available(iOS 26.0, *)
    @MainActor
    func generateCareerData(for student: Student?) async throws -> AICareerResponse {
        guard await isAppleIntelligenceAvailable() else {
            print("[AIInsightsService] Apple Intelligence not available for career data, falling back to sample data.")
            return generateSampleAICareerResponse(for: student)
        }

        let previousType = modelConfiguration.modelType
        configureFoundationModel(type: .careerExploration)

        do {
            let model = try await loadFoundationModel()
            let prompt = generateCareerPrompt(for: student)
            
            var response: Any // Declare response here
            
            #if canImport(AppleIntelligence)
            guard let foundationModel = model as? AppleIntelligence.FoundationModels.Model else {
                throw AIInsightsError.modelLoadingFailed("Failed to cast Foundation Model to expected type.")
            }
            response = try await foundationModel.generateResponse(for: prompt)
            #else
            // Fallback for when AppleIntelligence is not available
            throw AIInsightsError.foundationModelsUnavailable
            #endif
            let aiResponse = try parseAICareerResponse(response)
            
            // Restore previous configuration
            modelConfiguration = FoundationModelConfiguration(modelType: previousType)
            return aiResponse
        } catch {
            print("[AIInsightsService] AI career data generation failed: \(error), falling back to sample data.")
            // Restore previous configuration
            modelConfiguration = FoundationModelConfiguration(modelType: previousType)
            return generateSampleAICareerResponse(for: student)
        }
    }

    private func generateCareerPrompt(for student: Student?) -> String {
        var prompt = """
        Generate a JSON object containing an array of diverse career profiles and a career discovery insights summary.
        
        **CAREER PROFILE STRUCTURE:**
        Each career profile in the 'careers' array should have the following keys:
        - \"id\": String (UUID)
        - \"title\": String (e.g., \"Software Engineer\")
        - \"field\": String (e.g., \"Technology\", \"Healthcare\", \"Business\")
        - \"description\": String (detailed overview)
        - \"skills\": [String] (key skills required)
        - \"education\": String (typical education path)
        - \"salaryRange\": {\"lowerBound\": Double, \"upperBound\": Double} (annual salary range in USD)
        - \"jobOutlook\": String (e.g., \"Rapid growth\", \"Stable\", \"Declining\")
        - \"growthRate\": Double (e.g., 0.22 for 22% growth)

        **CAREER DISCOVERY INSIGHTS STRUCTURE:**
        The 'insights' object should have the following keys:
        - \"totalCareersExplored\": Int
        - \"personalizedRecommendations\": Int
        - \"topInterestCategory\": String
        - \"strongestCareerFields\": [String]
        - \"emergingOpportunities\": [Career] (array of Career objects)
        - \"skillGaps\": [String]
        - \"nextSteps\": [String]
        - \"generatedAt\": Double (Unix timestamp)

        **INSTRUCTIONS:**
        - Generate 10-15 diverse career profiles.
        - Ensure 'salaryRange' values are realistic.
        - 'growthRate' should be a decimal (e.g., 0.15 for 15%).
        - For 'insights', populate based on the generated careers and any provided student data.
        - 'emergingOpportunities' should be a subset of the generated careers with high growth potential.
        - 'skillGaps' and 'nextSteps' should be relevant to the generated careers and student profile.
        """

        if let student = student {
            prompt += """
            
            **STUDENT PROFILE FOR PERSONALIZATION:**
            - Name: \(student.name)
            - Grade: \(student.grade)
            - Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
            - Hobbies: \(student.hobbies.map { $0.name }.joined(separator: ", "))
            - Academic Performance (GPA): \(student.academicPerformance?.gpa ?? 0.0)
            - Academic Subjects: \(student.academicPerformance?.subjects.map { "\($0.name) (\($0.grade))" }.joined(separator: ", ") ?? "N/A")
            
            **PERSONALIZATION FOCUS:**
            - Prioritize careers that align with the student's interests, hobbies, and academic strengths.
            - Identify specific skill gaps for this student based on recommended careers.
            - Suggest actionable next steps tailored to this student's profile.
            """
        }
        
        prompt += "\n\nGenerate the JSON response now:"
        return prompt
    }

    @available(iOS 26.0, *)
    private func parseAICareerResponse(_ response: Any) throws -> AICareerResponse {
        #if canImport(AppleIntelligence)
        guard let modelResponse = response as? AppleIntelligence.ModelResponse else {
            throw AIInsightsError.responseParsingFailed("Invalid response type")
        }
        
        guard let responseText = modelResponse.text else {
            throw AIInsightsError.responseParsingFailed("No text in response")
        }
        
        guard let jsonData = responseText.data(using: .utf8) else {
            throw AIInsightsError.responseParsingFailed("Could not convert response to data")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970 // For generatedAt in insights
        
        do {
            let aiResponse = try decoder.decode(AICareerResponse.self, from: jsonData)
            return aiResponse
        } catch {
            print("JSON Decoding Error: \(error)")
            throw AIInsightsError.responseParsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
        #else
        throw AIInsightsError.foundationModelsUnavailable
        #endif
    }

    private func generateSampleAICareerResponse(for student: Student?) -> AICareerResponse {
        let sampleCareers = Career.sampleCareers
        let sampleInsights = CareerDiscoveryInsights(
            totalCareersExplored: sampleCareers.count,
            personalizedRecommendations: student != nil ? 5 : 0, // Placeholder
            topInterestCategory: student?.interests.first?.category.first?.rawValue ?? "General",
            strongestCareerFields: Array(Set(sampleCareers.map { $0.field }).prefix(3)),
            emergingOpportunities: sampleCareers.filter { $0.growthRate > 0.15 }.prefix(3).map { $0 },
            skillGaps: student != nil ? ["Data Analysis", "Cloud Computing"] : [], // Placeholder
            nextSteps: student != nil ? ["Explore online courses in recommended fields", "Attend career fairs"] : [] // Placeholder
        )
        return AICareerResponse(careers: sampleCareers, insights: sampleInsights)
    }

    @MainActor
    func generateInsights(from dashboardData: DashboardData) async -> [AIInsight] {
        // Check if Apple Intelligence is available
        guard await isAppleIntelligenceAvailable() else {
            print("[AIInsightsService] Apple Intelligence not available, falling back to rule-based insights")
            return generateRuleBasedInsights(from: dashboardData)
        }
        
        do {
            // Generate insights using Apple's Foundation Models (iOS 26+)
            if #available(iOS 26.0, *) {
                let insights = try await generateAIInsights(from: dashboardData)
                print("[AIInsightsService] Generated \(insights.count) Foundation Model insights")
                return insights
            } else {
                // Enhanced rule-based insights for iOS 18.0-25.x
                print("[AIInsightsService] Using enhanced rule-based insights (iOS 18-25)")
                return generateRuleBasedInsights(from: dashboardData)
            }
        } catch {
            print("[AIInsightsService] AI generation failed: \(error), falling back to rule-based")
            return generateRuleBasedInsights(from: dashboardData)
        }
    }
    
    // MARK: - Apple Intelligence Integration
    
    private func isAppleIntelligenceAvailable() async -> Bool {
        // Check if device supports Apple Intelligence and Foundation Models (iOS 26+)
        if #available(iOS 26.0, *) {
            #if canImport(AppleIntelligence)
            // Check if Foundation Models are available and enabled
            do {
                let availability = try await AppleIntelligence.FoundationModels.checkAvailability()
                return availability.isEnabled && availability.supportsEducationalAnalysis
            } catch {
                print("[AIInsightsService] Foundation Models availability check failed: \(error)")
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
    private func generateAIInsights(from dashboardData: DashboardData) async throws -> [AIInsight] {
        // Prepare data context for AI analysis
        let dataContext = prepareDataContext(from: dashboardData)
        
        #if canImport(AppleIntelligence)
        // Real Foundation Models implementation for iOS 26+
        do {
            // Load the Foundation Model
            let model = try await loadFoundationModel()
            
            #if canImport(AppleIntelligence)
            guard let foundationModel = model as? AppleIntelligence.FoundationModels.Model else {
                throw AIInsightsError.modelLoadingFailed("Failed to cast Foundation Model to expected type.")
            }
            // Generate comprehensive analysis prompt
            let prompt = generateAnalysisPrompt(from: dataContext)
            
            // Generate insights using Foundation Models
            let response = try await foundationModel.generateResponse(for: prompt)
            #else
            // Fallback for when AppleIntelligence is not available
            throw AIInsightsError.foundationModelsUnavailable
            #endif
            
            // Parse the AI response into structured insights
            let insights = try parseFoundationModelResponse(response)
            
            print("[AIInsightsService] Generated \(insights.count) Foundation Model insights")
            return insights
            
        } catch {
            print("[AIInsightsService] Foundation Models failed: \(error), falling back to enhanced simulation")
            // Fallback to enhanced simulation
            return await simulateAIInsights(from: dataContext)
        }
        #else
        // Fallback for development/simulator
        print("[AIInsightsService] Foundation Models not available, using enhanced simulation")
        return await simulateAIInsights(from: dataContext)
        #endif
    }
    
    @available(iOS 26.0, *)
    private func loadFoundationModel() async throws -> Any {
        // Check if we have a cached model for the current configuration
        if let cachedModel = modelCache[modelConfiguration.modelType] {
            return cachedModel
        }
        
        #if canImport(AppleIntelligence)
        // Load the Foundation Model with educational analysis specialization
        let model = try await AppleIntelligence.FoundationModels.load(
            type: .educationalAnalysis,
            configuration: AppleIntelligence.ModelConfiguration(
                maxTokens: modelConfiguration.maxTokens,
                temperature: modelConfiguration.temperature,
                topP: modelConfiguration.topP,
                presencePenalty: modelConfiguration.presencePenalty,
                frequencyPenalty: modelConfiguration.frequencyPenalty
            )
        )
        
        // Set system prompt for educational context
        try await model.setSystemPrompt(modelConfiguration.modelType.systemPrompt)
        
        // Cache the loaded model for this type
        modelCache[modelConfiguration.modelType] = model
        foundationModel = model
        return model
        #else
        throw AIInsightsError.foundationModelsUnavailable
        #endif
    }
    
    // MARK: - Foundation Models Prompt Generation
    
    private func generateAnalysisPrompt(from context: [String: Any]) -> String {
        let totalStudents = context["totalStudents"] as? Int ?? 0
        let completionRate = context["completionRate"] as? Double ?? 0
        let alignmentRate = context["alignmentRate"] as? Double ?? 0
        let engagementTrend = context["engagementTrend"] as? String ?? "stable"
        let recentActivities = context["recentActivities"] as? Int ?? 0
        let activePlans = context["activePlans"] as? Int ?? 0
        let interestsIdentified = context["interestsIdentified"] as? Int ?? 0
        
        let prompt = """
        Analyze the following TMI (Tangible Modification Intervention) educational data and provide actionable insights:

        **STUDENT POPULATION METRICS:**
        - Total Students: \(totalStudents)
        - Survey Completion Rate: \(String(format: "%.1f", completionRate * 100))%
        - Plan Alignment Rate: \(String(format: "%.1f", alignmentRate * 100))%
        - Active TMI Plans: \(activePlans)
        - Interests Identified: \(interestsIdentified)
        - Recent Activities (7 days): \(recentActivities)
        - Engagement Trend: \(engagementTrend)

        **ANALYSIS REQUIREMENTS:**
        
        1. **Critical Issues Identification**: Identify any urgent concerns requiring immediate intervention
        2. **Engagement Pattern Analysis**: Analyze student engagement patterns and predict future trends
        3. **Intervention Effectiveness**: Evaluate current TMI plan effectiveness and coverage gaps
        4. **Predictive Insights**: Forecast potential outcomes and success likelihood
        5. **Actionable Recommendations**: Provide specific, prioritized action items for educators
        
        **OUTPUT FORMAT:**
        Return insights as JSON array with this structure:
        {
            "insights": [
                {
                    "title": "Clear, concise insight title",
                    "description": "Detailed explanation with specific metrics and context",
                    "confidence": 0.85,
                    "priority": "high|medium|low|critical",
                    "category": "engagement|alignment|performance|recommendations|trends|interventions",
                    "actionItems": ["Specific action 1", "Specific action 2"],
                    "dataPoints": ["Supporting metric 1", "Supporting metric 2"]
                }
            ]
        }
        
        **FOCUS AREAS:**
        - Provide 3-6 highest-priority insights
        - Include confidence scores (0.0-1.0) based on data quality and pattern strength
        - Prioritize actionable recommendations over general observations
        - Consider both immediate needs and long-term trends
        - Highlight both concerning patterns and positive achievements
        
        Generate insights now:
        """
        
        return prompt
    }
    
    // MARK: - Foundation Models Response Parsing
    
    @available(iOS 26.0, *)
    private func parseFoundationModelResponse(_ response: Any) throws -> [AIInsight] {
        #if canImport(AppleIntelligence)
        guard let modelResponse = response as? AppleIntelligence.ModelResponse else {
            throw AIInsightsError.responseParsingFailed("Invalid response type")
        }
        
        guard let responseText = modelResponse.text else {
            throw AIInsightsError.responseParsingFailed("No text in response")
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
    
    private func parseIndividualInsight(from data: [String: Any]) -> AIInsight? {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let confidence = data["confidence"] as? Double,
              let priorityString = data["priority"] as? String,
              let categoryString = data["category"] as? String else {
            print("[AIInsightsService] Failed to parse insight: missing required fields")
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
    
    // MARK: - String to Enum Mapping
    
    private func mapStringToPriority(_ priorityString: String) -> InsightPriority {
        switch priorityString.lowercased() {
        case "critical": return .critical
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .medium
        }
    }
    
    private func mapStringToCategory(_ categoryString: String) -> InsightCategory {
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
    
    private func prepareDataContext(from dashboardData: DashboardData) -> [String: Any] {
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
    
    private func calculateEngagementTrend(_ engagementData: [EngagementData]) -> String {
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
    
    // MARK: - AI Simulation (Enhanced Rule-Based)
    
    private func simulateAIInsights(from context: [String: Any]) async -> [AIInsight] {
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
    
    private func analyzeEngagementPatterns(completionRate: Double, alignmentRate: Double, trend: String, activities: Int, totalStudents: Int) -> [AIInsight] {
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
    
    private func generatePredictiveInsights(from context: [String: Any]) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        let completionRate = context["completionRate"] as? Double ?? 0
        let alignmentRate = context["alignmentRate"] as? Double ?? 0
        let _ = context["totalStudents"] as? Int ?? 0
        
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
    
    private func generateInterventionRecommendations(from context: [String: Any]) -> [AIInsight] {
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
    
    // MARK: - Fallback Rule-Based Insights
    
    private func generateRuleBasedInsights(from dashboardData: DashboardData) -> [AIInsight] {
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
}