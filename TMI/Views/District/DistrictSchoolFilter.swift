//
//  DistrictSchoolFilter.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import SwiftUI

struct DistrictSchoolFilter: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedSchoolId: String?
  @State private var selectedGrade: String?
  @State private var selectedDateRange: DistrictFilter.DateRange?

  let filter: DistrictFilter
  let onApply: (DistrictFilter) -> Void

  init(filter: DistrictFilter, onApply: @escaping (DistrictFilter) -> Void) {
    self.filter = filter
    self.onApply = onApply
    _selectedSchoolId = State(initialValue: filter.schoolId)
    _selectedGrade = State(initialValue: filter.grade)
    _selectedDateRange = State(initialValue: filter.dateRange)
  }

  var body: some View {
    NavigationStack {
      List {
        // School filter
        Section {
          Picker("School", selection: $selectedSchoolId) {
            Text("All Schools").tag(nil as String?)
            ForEach(School.sampleSchools, id: \.id) { school in
              Text(school.name).tag(school.id as String?)
            }
          }
        } header: {
          Text("School")
        }

        // Grade filter
        Section {
          Picker("Grade", selection: $selectedGrade) {
            Text("All Grades").tag(nil as String?)
            ForEach(["K", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], id: \.self) { grade in
              Text(grade).tag(grade as String?)
            }
          }
        } header: {
          Text("Grade Level")
        }

        // Date range filter
        Section {
          Picker("Date Range", selection: $selectedDateRange) {
            Text("All Time").tag(nil as DistrictFilter.DateRange?)
            ForEach(DistrictFilter.DateRange.allCases, id: \.self) { range in
              Text(range.rawValue).tag(range as DistrictFilter.DateRange?)
            }
          }
        } header: {
          Text("Time Period")
        }

        // Clear filters
        Section {
          Button(role: .destructive) {
            selectedSchoolId = nil
            selectedGrade = nil
            selectedDateRange = nil
          } label: {
            Label("Clear All Filters", systemImage: "xmark.circle")
          }
        }
      }
      .navigationTitle("Filter Dashboard")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") {
            let newFilter = DistrictFilter(
              schoolId: selectedSchoolId,
              grade: selectedGrade,
              dateRange: selectedDateRange
            )
            onApply(newFilter)
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  DistrictSchoolFilter(filter: DistrictFilter()) { _ in }
}
