//
//  Models.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct InsightRecommendation: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var icon: String
    var color: Color
    
    static let sampleRecommendations: [InsightRecommendation] = [
        InsightRecommendation(
            title: "Increase survey completion rate",
            description: "25 students haven't completed their interest surveys. Consider sending a reminder notification.",
            icon: "bell.fill",
            color: .orange
        ),
        InsightRecommendation(
            title: "Review alignment scores",
            description: "Several students show low alignment between interests and academic performance. Schedule individual meetings.",
            icon: "person.2.fill",
            color: .blue
        ),
        InsightRecommendation(
            title: "New career path identified",
            description: "5 students have shown consistent interest in medical fields. Consider organizing a healthcare career workshop.",
            icon: "heart.text.square.fill",
            color: .pink
        )
    ]
}

extension TimeFrame {
    public static var allCases: [TimeFrame] {
        [.day, .week, .month, .year]
    }
}

// Helper functions to create bindings from state model
func binding<T>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String) -> Binding<Bool> {
    Binding(
        get: { stateModel.ui.get(key) ?? false },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

func binding<T, V>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String) -> Binding<V> where V: Equatable {
    Binding(
        get: { stateModel.ui.get(key) ?? (false as! V) },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

// For optional values
func optionalBinding<T, V>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String) -> Binding<V?> where V: Equatable {
    Binding(
        get: { stateModel.ui.get(key) as V? },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

// For values with a default
func binding<T, V>(_ stateModel: BaseStateModel<T, IdentifiableError>, _ key: String, defaultValue: V) -> Binding<V> where V: Equatable {
    Binding(
        get: { stateModel.ui.get(key) ?? defaultValue },
        set: { stateModel.ui.set(key, value: $0) }
    )
}

struct AlignmentData: Identifiable, Equatable {
    var id = UUID()
    var timePeriod: String
    var alignmentPercentage: Double
}

// MARK: - Sample Data

let alignmentData: [AlignmentData] = [
    AlignmentData(timePeriod: "Jan", alignmentPercentage: 0.45),
    AlignmentData(timePeriod: "Feb", alignmentPercentage: 0.52),
    AlignmentData(timePeriod: "Mar", alignmentPercentage: 0.48),
    AlignmentData(timePeriod: "Apr", alignmentPercentage: 0.60),
    AlignmentData(timePeriod: "May", alignmentPercentage: 0.55),
    AlignmentData(timePeriod: "Jun", alignmentPercentage: 0.72),
    AlignmentData(timePeriod: "Jul", alignmentPercentage: 0.68)
]

