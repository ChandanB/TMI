//
//  TimeFrame.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI

/// Represents different time periods for data filtering and display
enum TimeFrame: String, CaseIterable, Identifiable, Hashable {
    // MARK: - Cases
    
    /// Represents a single day period
    case day = "Day"
    
    /// Represents a week period (7 days)
    case week = "Week"
    
    /// Represents a month period
    case month = "Month"
    
    /// Represents a quarter (3 months)
    case quarter = "Quarter"
    
    /// Represents a year period
    case year = "Year"
    
    // MARK: - Identifiable Conformance
    
    /// The identifier for this time frame
    var id: Self { self }
    
    // MARK: - Display Properties
    
    /// Returns a user-friendly display name with "This" prefix
    var displayName: String {
        switch self {
        case .day:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .quarter:
            return "This Quarter"
        case .year:
            return "This Year"
        }
    }
    
    /// Returns the SF Symbol icon name associated with this time frame
    var iconName: String {
        switch self {
        case .day:
            return "clock"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        case .quarter:
            return "calendar.badge.exclamationmark"
        case .year:
            return "calendar.circle"
        }
    }
    
    /// Returns a color associated with this time frame for UI consistency
    var color: Color {
        switch self {
        case .day:
            return .blue
        case .week:
            return .green
        case .month:
            return .purple
        case .quarter:
            return .orange
        case .year:
            return .red
        }
    }
    
    // MARK: - Date Calculation
    
    /// Returns the start date for this time frame relative to the current date
    func startDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        switch self {
        case .day:
            // Start of today
            return calendar.startOfDay(for: date)
            
        case .week:
            // Start of current week (Sunday or Monday depending on locale)
            var dateComponents = DateComponents()
            dateComponents.weekday = calendar.firstWeekday
            dateComponents.weekOfYear = calendar.component(.weekOfYear, from: date)
            dateComponents.year = components.year
            return calendar.date(from: dateComponents) ?? date
            
        case .month:
            // Start of current month
            var dateComponents = DateComponents()
            dateComponents.day = 1
            dateComponents.month = components.month
            dateComponents.year = components.year
            return calendar.date(from: dateComponents) ?? date
            
        case .quarter:
            // Start of current quarter
            let month = components.month ?? 1
            let quarterMonth = ((month - 1) / 3) * 3 + 1
            var dateComponents = DateComponents()
            dateComponents.day = 1
            dateComponents.month = quarterMonth
            dateComponents.year = components.year
            return calendar.date(from: dateComponents) ?? date
            
        case .year:
            // Start of current year
            var dateComponents = DateComponents()
            dateComponents.day = 1
            dateComponents.month = 1
            dateComponents.year = components.year
            return calendar.date(from: dateComponents) ?? date
        }
    }
    
    /// Returns the end date for this time frame relative to the current date
    func endDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .day:
            // End of today
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))?.addingTimeInterval(-1) ?? date
            
        case .week:
            // End of current week
            let startOfWeek = self.startDate(from: date)
            return calendar.date(byAdding: .day, value: 7, to: startOfWeek)?.addingTimeInterval(-1) ?? date
            
        case .month:
            // End of current month
            let startOfMonth = self.startDate(from: date)
            return calendar.date(byAdding: .month, value: 1, to: startOfMonth)?.addingTimeInterval(-1) ?? date
            
        case .quarter:
            // End of current quarter
            let startOfQuarter = self.startDate(from: date)
            return calendar.date(byAdding: .month, value: 3, to: startOfQuarter)?.addingTimeInterval(-1) ?? date
            
        case .year:
            // End of current year
            let startOfYear = self.startDate(from: date)
            return calendar.date(byAdding: .year, value: 1, to: startOfYear)?.addingTimeInterval(-1) ?? date
        }
    }
    
    // MARK: - Utility Methods
    
    /// Returns the number of days in this time frame
    var approximateDayCount: Int {
        switch self {
        case .day:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .quarter:
            return 90
        case .year:
            return 365
        }
    }
    
    /// Returns the next smaller time frame, or nil if already at the smallest
    var nextSmallerTimeFrame: TimeFrame? {
        switch self {
        case .year:
            return .quarter
        case .quarter:
            return .month
        case .month:
            return .week
        case .week:
            return .day
        case .day:
            return nil
        }
    }
    
    /// Returns the next larger time frame, or nil if already at the largest
    var nextLargerTimeFrame: TimeFrame? {
        switch self {
        case .day:
            return .week
        case .week:
            return .month
        case .month:
            return .quarter
        case .quarter:
            return .year
        case .year:
            return nil
        }
    }
}

// MARK: - UI Extensions

extension TimeFrame {
    /// Returns a picker with all time frame options
    static func picker(selection: Binding<TimeFrame>) -> some View {
        Picker("Time Frame", selection: selection) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Text(timeFrame.displayName).tag(timeFrame)
            }
        }
        .pickerStyle(.menu)
    }
    
    /// Returns a segmented picker with all time frame options
    static func segmentedPicker(selection: Binding<TimeFrame>) -> some View {
        Picker("Time Frame", selection: selection) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Text(timeFrame.rawValue).tag(timeFrame)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Date Extension

extension Date {
    /// Returns a date that is offset by the specified time frame
    func adding(timeFrame: TimeFrame, value: Int = 1) -> Date {
        let calendar = Calendar.current
        
        switch timeFrame {
        case .day:
            return calendar.date(byAdding: .day, value: value, to: self) ?? self
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: value, to: self) ?? self
        case .month:
            return calendar.date(byAdding: .month, value: value, to: self) ?? self
        case .quarter:
            return calendar.date(byAdding: .month, value: value * 3, to: self) ?? self
        case .year:
            return calendar.date(byAdding: .year, value: value, to: self) ?? self
        }
    }
    
    /// Returns true if this date is within the specified time frame from now
    func isWithin(timeFrame: TimeFrame, from referenceDate: Date = Date()) -> Bool {
        let startDate = timeFrame.startDate(from: referenceDate)
        let endDate = timeFrame.endDate(from: referenceDate)
        return self >= startDate && self <= endDate
    }
}
