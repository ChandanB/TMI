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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCareers) { career in
                    NavigationLink(destination: CareerDetailView(career: career)) {
                        CareerRow(career: career)
                    }
                }
            }
            .navigationTitle("Career Explorer")
            .searchable(text: $searchText, prompt: "Search careers")
        }
    }
    
    private var filteredCareers: [Career] {
        if searchText.isEmpty {
            return careers
        } else {
            return careers.filter { career in
                career.title.lowercased().contains(searchText.lowercased()) ||
                career.description.lowercased().contains(searchText.lowercased()) ||
                career.skills.contains { $0.lowercased().contains(searchText.lowercased()) }
            }
        }
    }
}

struct CareerRow: View {
    let career: Career
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(career.title)
                .font(.headline)
            Text(career.field)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct CareerDetailView: View {
    let career: Career
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(career.title)
                    .font(.title)
                Text(career.field)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(career.description)
                    .font(.body)
                
                Text("Required Skills:")
                    .font(.headline)
                TagsView(tags: career.skills)
                
                Text("Education:")
                    .font(.headline)
                Text(career.education)
                
                Text("Salary Range:")
                    .font(.headline)
                Text("$\(career.salaryRange.lowerBound) - $\(career.salaryRange.upperBound) per year")
                
                Text("Job Outlook:")
                    .font(.headline)
                Text(career.jobOutlook)
            }
            .padding()
        }
        .navigationTitle("Career Details")
    }
}

#Preview {
    CareerExplorerView()
}

