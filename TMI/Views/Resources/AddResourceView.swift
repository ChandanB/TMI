//
//  AddResourceView.swift
//  TMI
//
//  Created by Chandan Brown on 10/26/24.
//

import SwiftUI

struct AddResourceView: View {
    let onResourceAdded: (Resource) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var category: Resource.ResourceCategory = .article
    @State private var url = ""
    @State private var tags = ""
    @State private var recommendedFor = ""
    @State private var isFeatured = false
    
    // Animation states
    @State private var showAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                resourceBackgroundView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Form fields in glass cards
                        Group {
                            // Title
                            ResourceFormField(
                                title: "Title",
                                placeholder: "Enter resource title",
                                text: $title
                            )
                            
                            // Description
                            LongResourceFormField(
                                title: "Description",
                                placeholder: "Enter a detailed description of the resource",
                                text: $description
                            )
                            
                            // Category picker
                            CategoryPickerView(category: $category)
                            
                            // URL
                            ResourceFormField(
                                title: "URL",
                                placeholder: "Enter resource URL",
                                icon: "link",
                                text: $url
                            )
                            
                            // Tags
                            ResourceFormField(
                                title: "Tags",
                                placeholder: "Enter comma-separated tags",
                                icon: "tag",
                                text: $tags
                            )
                            
                            // Recommended For
                            ResourceFormField(
                                title: "Recommended For",
                                placeholder: "Enter comma-separated roles",
                                icon: "person.2",
                                text: $recommendedFor
                            )
                            
                            // Featured toggle
                            FeatureToggleView(isFeatured: $isFeatured)
                        }
                        .opacity(showAnimation ? 1 : 0)
                        .offset(y: showAnimation ? 0 : 20)
                        
                        // Save button
                        Button {
                            saveResource()
                        } label: {
                            Text("Save Resource")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isFormValid ? Color.tmiSecondary : Color.gray.opacity(0.3))
                                )
                                .foregroundColor(.white)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 20)
                        .opacity(showAnimation ? 1 : 0)
                        .offset(y: showAnimation ? 0 : 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                    showAnimation = true
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var resourceBackgroundView: some View {
        TMIBackgroundView(variant: .default)
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty && !url.isEmpty
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
            recommendedFor: recommendedFor.split(separator: ",").map {
                String($0.trimmingCharacters(in: .whitespaces))
            },
            isFeatured: isFeatured
        )
        onResourceAdded(newResource)
        dismiss()
    }
}

// MARK: - Form Components

struct CategoryPickerView: View {
    @Binding var category: Resource.ResourceCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Resource.ResourceCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation {
                                category = cat
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(category == cat ? cat.color.opacity(0.3) : Color.white.opacity(0.05))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(category == cat ? cat.color : .white.opacity(0.6))
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            category == cat ? cat.color : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                                
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 14))
                                    .foregroundColor(category == cat ? .white : .white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct FeatureToggleView: View {
    @Binding var isFeatured: Bool
    
    var body: some View {
        HStack {
            Text("Featured Resource")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isFeatured)
                .toggleStyle(SwitchToggleStyle(tint: Color.tmiSecondary))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ResourceFormField: View {
    var title: String
    var placeholder: String
    var icon: String? = nil
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct LongResourceFormField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 16)
                        .padding(.leading, 16)
                }
                
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .frame(height: 120)
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
