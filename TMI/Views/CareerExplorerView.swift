//
//  CareerExplorerView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct CareerExplorerView: View {
    @State private var careers: [Career] = Career.sampleCareers
    @State private var searchText = ""
    @State private var selectedField: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                careerFieldPicker
                
                ZStack {
                    Color.tmiBackground.edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                            ForEach(filteredCareers) { career in
                                NavigationLink(destination: CareerDetailView(career: career)) {
                                    CareerCard(career: career)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Career Explorer")
            .searchable(text: $searchText, prompt: "Search careers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Implement filter or sort action
                    }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }
    
    private var careerFieldPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(Set(careers.map { $0.field })), id: \.self) { field in
                    Button(action: {
                        selectedField = selectedField == field ? nil : field
                    }) {
                        Text(field)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedField == field ? Color.tmiPrimary : Color.tmiSecondary.opacity(0.1))
                            .foregroundColor(selectedField == field ? .white : .tmiPrimary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding()
        }
    }
    
    private var filteredCareers: [Career] {
        careers.filter { career in
            let matchesSearch = searchText.isEmpty ||
                career.title.lowercased().contains(searchText.lowercased()) ||
                career.description.lowercased().contains(searchText.lowercased()) ||
                career.skills.contains { $0.lowercased().contains(searchText.lowercased()) }
            
            let matchesField = selectedField == nil || career.field == selectedField
            
            return matchesSearch && matchesField
        }
    }
}

struct CareerCard: View {
    let career: Career
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(career.title)
                .font(.headline)
                .foregroundColor(Color.tmiPrimary)
            Text(career.field)
                .font(.subheadline)
                .foregroundColor(Color.tmiSecondary)
            Text(career.description)
                .font(.caption)
                .foregroundColor(Color.tmiText)
                .lineLimit(3)
            HStack {
                Image(systemName: "dollarsign.circle")
                Text("$\(career.salaryRange.lowerBound/1000)k - $\(career.salaryRange.upperBound/1000)k")
                    .font(.caption2)
            }
            .foregroundColor(Color.tmiSecondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct CareerDetailView: View {
    let career: Career
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                descriptionSection
                skillsSection
                educationSection
                salarySection
                outlookSection
            }
            .padding()
        }
        .background(Color.tmiBackground.edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(career.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.tmiPrimary)
            Text(career.field)
                .font(.title3)
                .foregroundColor(Color.tmiSecondary)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this career")
                .font(.headline)
                .foregroundColor(Color.tmiPrimary)
            Text(career.description)
                .font(.body)
                .foregroundColor(Color.tmiText)
        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Required Skills")
                .font(.headline)
                .foregroundColor(Color.tmiPrimary)
            TagsView(tags: career.skills)
        }
    }
    
    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Education")
                .font(.headline)
                .foregroundColor(Color.tmiPrimary)
            Text(career.education)
                .font(.body)
                .foregroundColor(Color.tmiText)
        }
    }
    
    private var salarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Salary Range")
                .font(.headline)
                .foregroundColor(Color.tmiPrimary)
            Text("$\(career.salaryRange.lowerBound) - $\(career.salaryRange.upperBound) per year")
                .font(.body)
                .foregroundColor(Color.tmiText)
        }
    }
    
    private var outlookSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Job Outlook")
                .font(.headline)
                .foregroundColor(Color.tmiPrimary)
            Text(career.jobOutlook)
                .font(.body)
                .foregroundColor(Color.tmiText)
        }
    }
}

#Preview {
    CareerExplorerView()
}
