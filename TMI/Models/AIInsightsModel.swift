//
//  AIInsight.swift
//  TMI
//
//  Created by Chandan Brown on 8/20/25.
//

import Foundation
import SwiftUI

// MARK: - AI Insights Models

struct AIInsight: Identifiable, Codable, Sendable {
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

enum InsightPriority: String, CaseIterable, Codable, Sendable {
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

enum InsightCategory: String, CaseIterable, Codable, Sendable {
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

// MARK: - Search Context Types

enum SearchType: String {
    case general
    case field
    case subject
    case skill
    case specificCareer
}

struct SearchContext {
    let type: SearchType
    let info: String?
}

// MARK: - AI Career Response Model

struct AICareerResponse: Codable, Sendable {
    let careers: [Career]
    let insights: CareerDiscoveryInsights
}
