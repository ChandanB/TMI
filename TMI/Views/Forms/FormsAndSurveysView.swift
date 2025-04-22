import SwiftUI
import Foundation


// MARK: - Core Views

struct FormsAndSurveysView: View {
    @State private var viewModel = FormStoreViewModel()
    @State private var showingAddForm = false
    @State private var selectedFilter: FormFilter = .all
    @State private var showingFormBuilder = false
    @State private var searchText = ""
    
    // Animation states
    @State private var isLoaded = false
    @State private var hasScrolled = false
    
    enum FormFilter: String, CaseIterable {
        case all = "All"
        case surveys = "Surveys"
        case otherForms = "Other Forms"
    }
    
    var body: some View {
        ZStack {
            // Background
            formBackgroundView
            
            NavigationStack {
                ZStack {
                    // Main content
                    VStack(spacing: 0) {
                        // Search and Filter
                        searchAndFilterBar
                            .padding(.top, 10)
                            .padding(.horizontal)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : -20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isLoaded)
                        
                        // Categories
                        categoryView
                            .padding(.top, 15)
                            .padding(.horizontal)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: isLoaded)
                        
                        // Content
                        if viewModel.isLoading {
                            loadingView
                        } else if filteredForms.isEmpty {
                            emptyStateView
                        } else {
                            formsList
                        }
                    }
                    
                    // Floating Action Button
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button {
                                showingFormBuilder = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: Color.tmiSecondary.opacity(0.3), radius: 10, x: 0, y: 5)
                                    )
                            }
                            .offset(y: isLoaded ? 0 : 100)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isLoaded)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .navigationTitle("Forms & Surveys")
                .foregroundColor(.white)
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingFormBuilder = true
                            } label: {
                                Label("Create New Form", systemImage: "square.and.pencil")
                            }
                            
                            Button {
                                showingAddForm = true
                            } label: {
                                Label("Import Form", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showingAddForm) {
                    FormCreationView()
                }
                .sheet(isPresented: $showingFormBuilder) {
                    FormTemplateBuilderView()
                }
            }
        }
        .onAppear {
            viewModel.loadTemplates()
            
            // Animate appearance
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                isLoaded = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Background
    
    private var formBackgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated blob overlay
            AnimatedBlobView()
                .opacity(0.15)
            
            // Particle effect
            FormParticleEffect()
                .opacity(0.3)
        }
    }
    
    // MARK: - Search & Filter
    
    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
                    .padding(.leading, 8)
                
                TextField("Search forms", text: $searchText)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.07))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
    
    // MARK: - Category View
    
    private var categoryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FormFilter.allCases, id: \.self) { filter in
                    FormCategoryButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Forms List
    
    private var formsList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(filteredForms) { template in
                    NavigationLink(destination: FormTemplateDetailView(template: template)) {
                        FormStoreCardView(template: template)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 50)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(0.3 + Double(filteredForms.firstIndex(where: { $0.id == template.id }) ?? 0) * 0.05),
                                value: isLoaded
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(20)
            .padding(.bottom, 80) // Add extra padding for the FAB
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            FormLoadingIndicator()
            
            Text("Loading Forms")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Empty illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.2), Color.clear]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 60)
            
            Text("No Forms Found")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Create your first form to start collecting data for TMI")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingFormBuilder = true
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Create Form")
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tmiSecondary)
                )
                .foregroundColor(.white)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.top, 60)
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 20)
        .animation(.easeInOut(duration: 0.5).delay(0.3), value: isLoaded)
    }
    
    // MARK: - Filtered Forms
    
    private var filteredForms: [FormTemplate] {
        viewModel.formTemplates.filter { template in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .surveys:
                matchesFilter = template.category == "Survey"
            case .otherForms:
                matchesFilter = template.category != "Survey"
            }
            
            let matchesSearch = searchText.isEmpty ||
                                template.name.lowercased().contains(searchText.lowercased()) ||
                                (template.category?.lowercased().contains(searchText.lowercased()) ?? false)
            
            return matchesFilter && matchesSearch
        }
    }
}

// MARK: - Form Card

struct FormStoreCardView: View {
    var template: FormTemplate
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon with category color
            ZStack {
                Circle()
                    .fill(template.themeColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 22))
                    .foregroundColor(template.themeColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title and badge
                HStack {
                    Text(template.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if template.isActive {
                        Text("Active")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.2))
                            )
                            .foregroundColor(.green)
                    }
                }
                
                // Description
                if !template.templateDescription.isEmpty {
                    Text(template.templateDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                // Metadata
                HStack(spacing: 16) {
                    // Sections
                    Label("\(template.sections.count) sections", systemImage: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Category
                    if let category = template.category {
                        Label(category, systemImage: "tag")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Date
                    Text((template.updatedAt ?? template.createdAt) ?? Date(), style: .date)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
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
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // Icon based on category
    private var categoryIcon: String {
        switch template.category {
        case "Survey":
            return "list.clipboard.fill"
        case "Assessment":
            return "chart.bar.fill"
        case "Feedback":
            return "text.bubble.fill"
        default:
            return "doc.text.fill"
        }
    }
}

// MARK: - Form Template Detail View

struct FormTemplateDetailView: View {
    var template: FormTemplate
    
    @State private var isAddingTemplate = false
    @State private var showingDynamicForm = false
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background
            formBackgroundView
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    formHeader
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateContent)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Description")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(template.templateDescription)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.03))
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
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animateContent)
                    
                    // Preview Button
                    Button {
                        showingDynamicForm = true
                    } label: {
                        HStack {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16))
                            
                            Text("Preview Form")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.tmiSecondary)
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: animateContent)
                    
                    // Form Preview
                    formPreview
                        .padding(.horizontal, 20)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: animateContent)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        Task {
                            await saveTemplateToMyCollection()
                        }
                    }) {
                        Label("Add to My Forms", systemImage: "plus.circle")
                    }
                    
                    Button(action: {
                        // Edit action
                    }) {
                        Label("Edit Template", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        // Share action
                    }) {
                        Label("Share Template", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        // Delete action
                    }) {
                        Label("Delete Template", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                }
            }
        }
        .sheet(isPresented: $showingDynamicForm) {
            if let templateID = template.id {
                DynamicFormView(templateId: templateID)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                animateContent = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var formBackgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated blob overlay
            AnimatedBlobView()
                .opacity(0.15)
        }
    }
    
    private var formHeader: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(template.themeColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 36))
                    .foregroundColor(template.themeColor)
            }
            
            // Stats
            HStack(spacing: 24) {
                // Sections
                VStack(spacing: 4) {
                    Text("\(template.sections.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sections")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Fields
                VStack(spacing: 4) {
                    Text("\(template.sections.flatMap { $0.fields }.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Fields")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Created
                VStack(spacing: 4) {
                    Text(template.createdAt ?? Date(), style: .date)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Created")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
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
            .padding(.horizontal, 20)
        }
    }
    
    private var formPreview: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Form Structure")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            ForEach(template.sections) { section in
                SectionPreviewCard(section: section)
            }
        }
    }
    
    // Icon based on category
    private var categoryIcon: String {
        switch template.category {
        case "Survey":
            return "list.clipboard.fill"
        case "Assessment":
            return "chart.bar.fill"
        case "Feedback":
            return "text.bubble.fill"
        default:
            return "doc.text.fill"
        }
    }
    
    private func saveTemplateToMyCollection() async {
        isAddingTemplate = true
        // Implement the logic to save the template to the user's collection
        // This would typically involve a call to your Firebase service
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isAddingTemplate = false
    }
}

// MARK: - Section Preview Card

struct SectionPreviewCard: View {
    var section: FormSection
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(section.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(section.fields.count) fields")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(Angle(degrees: isExpanded ? 90 : 0))
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Fields (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(section.fields) { field in
                        FieldPreviewRow(field: field)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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

// MARK: - Field Preview Row

struct FieldPreviewRow: View {
    var field: FormField
    
    var body: some View {
        HStack(spacing: 12) {
            // Field type icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 36, height: 36)
                
                Image(systemName: field.type.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Field label and type
            VStack(alignment: .leading, spacing: 4) {
                Text(field.label)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(field.type.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if field.isRequired {
                        Text("Required")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.2))
                            )
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}



// MARK: - Dynamic Field View

struct DynamicFieldView: View {
    var field: FormField
    var onValueChange: (Any) -> Void
    
    @State private var textValue = ""
    @State private var numberValue = ""
    @State private var dateValue = Date()
    @State private var selectedOption = ""
    @State private var selectedOptions: [String] = []
    @State private var ratingValue = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Field label
            HStack(spacing: 4) {
                Text(field.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if field.isRequired {
                    Text("*")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            // Field input based on type
            fieldContent
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
    
    @ViewBuilder
    private var fieldContent: some View {
        switch field.type {
        case .text:
            TextField(field.placeholder ?? "Enter text", text: $textValue)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
                .onChange(of: textValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
            
        case .longText:
            TextEditor(text: $textValue)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
                .frame(height: 120)
                .onChange(of: textValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
            
        case .number:
            TextField(field.placeholder ?? "Enter number", text: $numberValue)
                .keyboardType(.numberPad)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
                .onChange(of: numberValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
            
        case .date:
            DatePicker("", selection: $dateValue, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.tmiSecondary)
                .onChange(of: dateValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
            
        case .time:
            DatePicker("", selection: $dateValue, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.tmiSecondary)
                .onChange(of: dateValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
            
        case .multipleChoice:
            if let options = field.options {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selectedOption = option
                            onValueChange(option)
                        } label: {
                            HStack {
                                Image(systemName: selectedOption == option ? "circle.inset.filled" : "circle")
                                    .foregroundColor(selectedOption == option ? Color.tmiSecondary : .white.opacity(0.6))
                                
                                Text(option)
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No options available")
                    .foregroundColor(.white.opacity(0.5))
            }
            
        case .checkbox:
            if let options = field.options {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            if selectedOptions.contains(option) {
                                selectedOptions.removeAll { $0 == option }
                            } else {
                                selectedOptions.append(option)
                            }
                            onValueChange(selectedOptions)
                        } label: {
                            HStack {
                                Image(systemName: selectedOptions.contains(option) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedOptions.contains(option) ? Color.tmiSecondary : .white.opacity(0.6))
                                
                                Text(option)
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No options available")
                    .foregroundColor(.white.opacity(0.5))
            }
            
        case .dropdown:
            if let options = field.options {
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            selectedOption = option
                            onValueChange(option)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedOption.isEmpty ? "Select an option" : selectedOption)
                            .foregroundColor(selectedOption.isEmpty ? .white.opacity(0.5) : .white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            } else {
                Text("No options available")
                    .foregroundColor(.white.opacity(0.5))
            }
            
        case .rating:
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        ratingValue = rating
                        onValueChange(rating)
                    } label: {
                        Image(systemName: rating <= ratingValue ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundColor(rating <= ratingValue ? .yellow : .white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            
        case .file:
            Button {
                // File upload logic would go here
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Upload File")
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
            }
            
        case .table, .signature:
            Text("This field type is only available in the full version")
                .foregroundColor(.white.opacity(0.5))
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
        case .dateTime:
            DatePicker("", selection: $dateValue, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.tmiSecondary)
                .onChange(of: dateValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
        case .email:
            TextField(field.placeholder ?? "Enter email", text: $textValue)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
                .onChange(of: textValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
        case .phoneNumber:
            TextField(field.placeholder ?? "Enter phone number", text: $textValue)
                .keyboardType(.phonePad)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
                .onChange(of: textValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
        case .url:
            TextField(field.placeholder ?? "Enter URL", text: $textValue)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
                .foregroundColor(.white)
                .onChange(of: textValue) { oldValue, newValue in
                    onValueChange(newValue)
                }
        case .allCases:
            EmptyView()
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    var current: Int
    var total: Int
    
    private var progress: CGFloat {
        total > 0 ? CGFloat(current) / CGFloat(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 8)
            
            // Text indicator
            HStack {
                Text("Section \(current) of \(total)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Form Creation View

struct FormCreationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                formBackgroundView
                
                VStack {
                    Text("Form Creation view placeholder")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Create Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationSizing(.page)
    }
    
    private var formBackgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.15),
                    Color(red: 0.14, green: 0.14, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}


// MARK: - Reusable Components

struct FormCategoryButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.tmiSecondary.opacity(0.2) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.tmiSecondary : Color.clear,
                            lineWidth: 1
                        )
                )
                .foregroundColor(isSelected ? Color.tmiSecondary : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct FormLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.tmiSecondary.opacity(0),
                            Color.tmiSecondary
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: 6
                )
                .frame(width: 80, height: 80)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Inner pulsing circle
            Circle()
                .fill(Color.tmiSecondary.opacity(0.3))
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 0.8 : 0.6)
                .opacity(isAnimating ? 0.6 : 0.3)
                .animation(
                    Animation.easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Form icon
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct FormParticleEffect: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var size: CGFloat
        var opacity: Double
        var speed: Double
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Update particle positions
                for index in particles.indices {
                    particles[index].position.y -= particles[index].speed
                    particles[index].opacity -= 0.003
                    
                    if particles[index].position.y < 0 || particles[index].opacity <= 0 {
                        // Replace particle
                        particles[index] = createParticle(size: size)
                    }
                }
                
                // Draw particles
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x,
                        y: particle.position.y,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    context.opacity = particle.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .onAppear {
            // Initialize particles
            for _ in 0..<40 {
                particles.append(createParticle(size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)))
            }
        }
    }
    
    private func createParticle(size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ),
            size: CGFloat.random(in: 1...3),
            opacity: Double.random(in: 0.1...0.3),
            speed: Double.random(in: 0.2...0.6)
        )
    }
}

struct AnimatedBlobView: View {
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    
    var body: some View {
        ZStack {
            // Blob 1
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tmiSecondary.opacity(0.4),
                            Color.tmiSecondary.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animateBlob1 ? -30 : -130, y: animateBlob1 ? -100 : -60)
                .rotationEffect(Angle(degrees: animateBlob1 ? 30 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 8)
                        .repeatForever(autoreverses: true),
                    value: animateBlob1
                )
            
            // Blob 2
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 250, height: 250)
                .offset(x: animateBlob2 ? 100 : 160, y: animateBlob2 ? 300 : 250)
                .rotationEffect(Angle(degrees: animateBlob2 ? -20 : 0))
                .blur(radius: 60)
                .animation(
                    Animation.easeInOut(duration: 10)
                        .repeatForever(autoreverses: true),
                    value: animateBlob2
                )
        }
        .onAppear {
            animateBlob1 = true
            animateBlob2 = true
        }
    }
}

// MARK: - Preview

#Preview {
    FormsAndSurveysView()
}
