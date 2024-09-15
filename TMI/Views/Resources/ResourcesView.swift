//
//  ResourcesView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct ResourcesView: View {
    @State private var resources: [Resource] = Resource.sampleResources
    @State private var showingAddResource = false
    @State private var searchText = ""
    @State private var selectedCategory: Resource.ResourceCategory?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker
                
                ZStack {
                    if filteredResources.isEmpty {
                        Text("No resources found")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                                ForEach(filteredResources) { resource in
                                    NavigationLink(destination: ResourceDetailView(resource: resource)) {
                                        ResourceCard(resource: resource)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Resource Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddResource = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.tmiPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddResource) {
                AddResourceView(resources: $resources)
            }
        }
        .searchable(text: $searchText, prompt: "Search resources")
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                CategoryButton(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(Resource.ResourceCategory.allCases, id: \.self) { category in
                    CategoryButton(title: category.rawValue.capitalized, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
        }
    }

    private var filteredResources: [Resource] {
        resources.filter { resource in
            let matchesSearch = searchText.isEmpty ||
                resource.title.lowercased().contains(searchText.lowercased()) ||
                resource.description.lowercased().contains(searchText.lowercased()) ||
                resource.tags.contains { $0.lowercased().contains(searchText.lowercased()) }
            
            let matchesCategory = selectedCategory == nil || resource.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.tmiPrimary : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}


struct ResourceCard: View {
    let resource: Resource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconForCategory(resource.category))
                .font(.largeTitle)
                .foregroundColor(.tmiPrimary)
            
            Text(resource.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(resource.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Spacer()
            
            HStack {
                Text(resource.category.rawValue.capitalized)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.tmiSecondary.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.tmiPrimary)
            }
        }
        .padding()
        .frame(height: 200)
        .background(Color.tmiBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func iconForCategory(_ category: Resource.ResourceCategory) -> String {
        switch category {
        case .article: return "doc.text"
        case .video: return "play.rectangle"
        case .course: return "book"
        case .book: return "book.closed"
        case .tool: return "hammer"
        case .interactiveContent: return "gamecontroller"
        }
    }
}

struct ResourceRow: View {
    let resource: Resource

    var body: some View {
        VStack(alignment: .leading) {
            Text(resource.title)
                .font(.headline)
            Text(resource.category.rawValue.capitalized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(resource.description)
                .font(.caption)
                .lineLimit(2)
        }
    }
}

struct ResourceDetailView: View {
    let resource: Resource

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(resource.title)
                    .font(.title)
                Text(resource.category.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(resource.description)
                    .font(.body)
                Link("Open Resource", destination: URL(string: resource.url)!)
                    .buttonStyle(.borderedProminent)
                TagsView(tags: resource.tags)
                Text("Recommended for:")
                    .font(.headline)
                Text(resource.recommendedFor.joined(separator: ", "))
            }
            .padding()
        }
        .navigationTitle("Resource Details")
    }
}

struct TagsView: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
}

struct AddResourceView: View {
    @Binding var resources: [Resource]
    @State private var title = ""
    @State private var description = ""
    @State private var category: Resource.ResourceCategory = .article
    @State private var url = ""
    @State private var tags = ""
    @State private var recommendedFor = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $description)
                Picker("Category", selection: $category) {
                    ForEach(Resource.ResourceCategory.allCases, id: \.self) { category in
                        Text(category.rawValue.capitalized).tag(category)
                    }
                }
                TextField("URL", text: $url)
                TextField("Tags (comma-separated)", text: $tags)
                TextField("Recommended for (comma-separated)", text: $recommendedFor)
            }
            .navigationTitle("Add Resource")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveResource()
                    }
                }
            }
        }
    }

    private func saveResource() {
        let newResource = Resource(
            title: title,
            description: description,
            category: category,
            url: url,
            createdAt: Date(),
            updatedAt: Date(),
            tags: tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) },
            recommendedFor: recommendedFor.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        )
        resources.append(newResource)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    ResourcesView()
}

