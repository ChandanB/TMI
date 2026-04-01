//
//  PlanTemplateLibraryView.swift
//  TMI
//
//  Library view for browsing and selecting TMI Plan templates
//  Created for Phase 3: Polish & Reporting
//

import SwiftUI
import Observation

// MARK: - View Model

@Observable
@MainActor
class PlanTemplateLibraryViewModel {
    var templates: [PlanTemplate] = []
    var filteredTemplates: [PlanTemplate] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""
    var selectedCategory: PlanTemplate.Category?
    var selectedModel: TMIPlanModel?
    
    private let service = PlanTemplateService.shared
    
    func loadTemplates(districtId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            templates = try await service.fetchTemplates(districtId: districtId)
            applyFilters()
        } catch {
            errorMessage = "Failed to load templates: \(error.localizedDescription)"
        }
    }
    
    func applyFilters() {
        var result = templates
        
        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        // Apply model filter
        if let model = selectedModel {
            result = result.filter { $0.model == model }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by usage count (most popular first)
        result.sort { $0.usageCount > $1.usageCount }
        
        filteredTemplates = result
    }
    
    func selectCategory(_ category: PlanTemplate.Category?) {
        selectedCategory = category
        applyFilters()
    }
    
    func selectModel(_ model: TMIPlanModel?) {
        selectedModel = model
        applyFilters()
    }
    
    func clearFilters() {
        selectedCategory = nil
        selectedModel = nil
        searchText = ""
        applyFilters()
    }
}

// MARK: - Library View

struct PlanTemplateLibraryView: View {
    @State private var viewModel = PlanTemplateLibraryViewModel()
    @Environment(\.authStateModel) private var authStateModel
    @State private var selectedTemplate: PlanTemplate?
    @State private var showingTemplateDetail = false
    
    let onSelectTemplate: (PlanTemplate) -> Void
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .dashboard)
            
            if viewModel.isLoading && viewModel.templates.isEmpty {
                ProgressView("Loading templates...")
            } else if viewModel.templates.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Plan Templates")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Search templates")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.applyFilters()
        }
        .task {
            await viewModel.loadTemplates(districtId: authStateModel.currentUser?.districtId)
        }
        .sheet(isPresented: $showingTemplateDetail) {
            if let template = selectedTemplate {
                PlanTemplateDetailSheet(template: template) {
                    showingTemplateDetail = false
                    onSelectTemplate(template)
                }
                .tmiSheetStyle()
            }
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: TMISpacing.lg) {
                // Category Filter
                categoryFilter
                
                // Model Filter
                modelFilter
                
                // Templates Grid
                if viewModel.filteredTemplates.isEmpty {
                    noResultsState
                } else {
                    templatesGrid
                }
            }
            .padding()
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.sm) {
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectCategory(nil)
                }
                
                ForEach(PlanTemplate.Category.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectCategory(category)
                    }
                }
            }
        }
    }
    
    // MARK: - Model Filter
    
    private var modelFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.sm) {
                ModelChip(
                    title: "All Models",
                    isSelected: viewModel.selectedModel == nil
                ) {
                    viewModel.selectModel(nil)
                }
                
                ForEach(TMIPlanModel.allCases, id: \.self) { model in
                    ModelChip(
                        title: model.rawValue,
                        isSelected: viewModel.selectedModel == model
                    ) {
                        viewModel.selectModel(model)
                    }
                }
            }
        }
    }
    
    // MARK: - Templates Grid
    
    private var templatesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMISpacing.md) {
            ForEach(viewModel.filteredTemplates) { template in
                PlanTemplateCard(template: template) {
                    selectedTemplate = template
                    showingTemplateDetail = true
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        TMIEmptyState(
            icon: "doc.text.magnifyingglass",
            title: "No Templates Yet",
            message: "Templates will appear here once created by your district or shared publicly."
        )
    }
    
    private var noResultsState: some View {
        VStack(spacing: TMISpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.tmiTextTertiary)
            
            Text("No Matching Templates")
                .font(.tmiHeading2)
                .foregroundColor(.tmiTextSecondary)
            
            Button("Clear Filters") {
                viewModel.clearFilters()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.xxl)
    }
}

// MARK: - Template Card

struct PlanTemplateCard: View {
    let template: PlanTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                // Header
                HStack {
                    Image(systemName: template.category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(categoryColor)
                    
                    Spacer()
                    
                    if template.usageCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(template.usageCount)")
                                .font(.tmiFootnote)
                        }
                        .foregroundColor(.tmiTextTertiary)
                    }
                }
                
                // Title
                Text(template.title)
                    .font(.tmiHeading2)
                    .foregroundColor(.tmiTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Description
                Text(template.description)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Footer
                HStack {
                    Text(template.model.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.tmiPrimary)
                        .cornerRadius(TMIRadius.xs)
                    
                    Spacer()
                    
                    Text("\(template.suggestedDurationWeeks)w")
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextTertiary)
                }
            }
            .padding(TMISpacing.md)
            .frame(minHeight: 160)
            .background(Color.tmiBackground)
            .cornerRadius(TMIRadius.md)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        switch template.category.color {
        case "orange": return .orange
        case "blue": return .blue
        case "pink": return .pink
        case "green": return .green
        case "purple": return .purple
        case "yellow": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.tmiCaption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.tmiPrimary : Color.tmiBackground)
            .foregroundColor(isSelected ? .white : .tmiTextPrimary)
            .cornerRadius(TMIRadius.full)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Chip

struct ModelChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.tmiCaption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.tmiSecondary : Color.tmiBackground)
                .foregroundColor(isSelected ? .white : .tmiTextPrimary)
                .cornerRadius(TMIRadius.full)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Detail Sheet

struct PlanTemplateDetailSheet: View {
    let template: PlanTemplate
    let onUseTemplate: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TMISpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: TMISpacing.sm) {
                        HStack {
                            Image(systemName: template.category.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.tmiPrimary)
                            
                            Text(template.category.rawValue)
                                .font(.tmiCaption)
                                .foregroundColor(.tmiTextSecondary)
                        }
                        
                        Text(template.title)
                            .font(.tmiTitle2)
                            .foregroundColor(.tmiTextPrimary)
                        
                        Text(template.description)
                            .font(.tmiBody)
                            .foregroundColor(.tmiTextSecondary)
                    }
                    
                    TMIDivider()
                    
                    // Metadata
                    metadataSection
                    
                    TMIDivider()
                    
                    // Goals Preview
                    goalsSection
                    
                    TMIDivider()
                    
                    // Strategies Preview
                    strategiesSection
                }
                .padding()
            }
            .background(Color.tmiBackground)
            .navigationTitle("Template Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Template") {
                        onUseTemplate()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var metadataSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMISpacing.sm) {
            MetadataItem(label: "Model", value: template.model.rawValue, icon: "sparkles")
            MetadataItem(label: "Duration", value: "\(template.suggestedDurationWeeks) weeks", icon: "calendar")
            MetadataItem(label: "Goals", value: "\(template.goalsTemplate.count)", icon: "flag.fill")
            MetadataItem(label: "Used", value: "\(template.usageCount) times", icon: "person.2.fill")
        }
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("Goals Included")
                .font(.tmiHeading2)
                .foregroundColor(.tmiTextPrimary)
            
            ForEach(template.goalsTemplate) { goal in
                HStack(alignment: .top, spacing: TMISpacing.sm) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.tmiPrimary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title)
                            .font(.tmiBody)
                            .foregroundColor(.tmiTextPrimary)
                        
                        Text("\(goal.milestones.count) milestones")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextTertiary)
                    }
                }
            }
        }
    }
    
    private var strategiesSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            Text("Suggested Strategies")
                .font(.tmiHeading2)
                .foregroundColor(.tmiTextPrimary)
            
            ForEach(template.strategiesTemplate, id: \.self) { strategy in
                HStack(alignment: .top, spacing: TMISpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    Text(strategy)
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)
                }
            }
        }
    }
}

// MARK: - Metadata Item

struct MetadataItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: TMISpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.tmiPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextTertiary)
                Text(value)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TMISpacing.sm)
        .background(Color.tmiBackground)
        .cornerRadius(TMIRadius.sm)
    }
}

#Preview {
    NavigationStack {
        PlanTemplateLibraryView { template in
            print("Selected: \(template.title)")
        }
    }
}
