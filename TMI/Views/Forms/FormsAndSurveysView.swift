import Foundation
import SwiftUI

// MARK: - Core Views

struct FormsAndSurveysView: View {
  @State private var viewModel = FormStoreViewModel()
  @State private var selectedFilter: FormFilter = .all
  @State private var searchText = ""

  // Animation states
  @State private var isLoaded = false
  @State private var hasScrolled = false
  
  // Sheet states
  @State private var showingFormCreation = false
  @State private var showingFormBuilder = false
  @State private var showingFormImport = false

  enum FormFilter: String, CaseIterable {
    case all = "All"
    case surveys = "Surveys"
    case otherForms = "Other Forms"
  }

  var body: some View {
    ZStack {
      // Unified Background
      TMIBackgroundView(variant: .default)

      VStack(spacing: 0) {
        // Search and Filter - Using unified TMITextField
        searchAndFilterBar
          .padding(.top, 16)
          .padding(.horizontal, 20)
          .opacity(isLoaded ? 1 : 0)
          .offset(y: isLoaded ? 0 : -20)
          .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isLoaded)

        // Categories
        categoryView
          .padding(.top, 16)
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

      // Unified Floating Action Button
      VStack {
        Spacer()

        HStack {
          Spacer()

          TMIButton(
            text: "Create",
            icon: "plus",
            style: .floating,
            action: {
              showingFormCreation = true
            }
          )
          .offset(y: isLoaded ? 0 : 100)
          .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: isLoaded)
          .padding(.trailing, 24)
          .padding(.bottom, 24)
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
            showingFormImport = true
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
    .onAppear {
      viewModel.loadTemplates()

      // Animate appearance
      withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
        isLoaded = true
      }
    }
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showingFormCreation) {
      FormCreationView()
    }
    .sheet(isPresented: $showingFormBuilder) {
      FormBuilderView()
    }
    .sheet(isPresented: $showingFormImport) {
      FormImportView()
    }
  }

  // MARK: - Search & Filter (Updated)

  private var searchAndFilterBar: some View {
    TMITextField(
      icon: "magnifyingglass",
      placeholder: "Search forms",
      text: $searchText
    )
  }

  // MARK: - Category View (Updated)

  private var categoryView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 16) {
        ForEach(FormFilter.allCases, id: \.self) { filter in
          TMIButton(
            text: filter.rawValue,
            style: .filter(isSelected: selectedFilter == filter),
            action: {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = filter
              }
            }
          )
          .fixedSize(horizontal: true, vertical: false)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 8)
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
                  .delay(
                    0.3 + Double(filteredForms.firstIndex(where: { $0.id == template.id }) ?? 0)
                      * 0.05),
                value: isLoaded
              )
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 100)  // Extra padding for the FAB
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

  // MARK: - Empty State (Updated)

  private var emptyStateView: some View {
    VStack(spacing: 32) {
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
      .padding(.top, 80)

      Text("No Forms Found")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(.white)

      Text("Create your first form to start collecting data for TMI")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      TMIButton(
        text: "Create Form",
        icon: "square.and.pencil",
        style: .primary,
        action: {
          showingFormCreation = true
        }
      )
      .padding(.top, 16)

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.top, 40)
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
        matchesFilter = template.category?.lowercased() == "survey" || template.category?.lowercased().contains("survey") == true
      case .otherForms:
        matchesFilter = template.category?.lowercased() != "survey" && !(template.category?.lowercased().contains("survey") == true)
      }

      let matchesSearch =
        searchText.isEmpty || template.name.lowercased().contains(searchText.lowercased())
        || (template.category?.lowercased().contains(searchText.lowercased()) ?? false)

      return matchesFilter && matchesSearch
    }
  }
}

// MARK: - Form Card (Updated)

struct FormStoreCardView: View {
  var template: FormTemplate

  @State private var isHovered = false

  var body: some View {
    TMIGlassCard(style: .default) {
      HStack(alignment: .top, spacing: 20) {
        // Icon with category color
        ZStack {
          Circle()
            .fill(template.themeColor.opacity(0.2))
            .frame(width: 56, height: 56)

          Image(systemName: categoryIcon)
            .font(.system(size: 26))
            .foregroundColor(template.themeColor)
        }

        // Content
        VStack(alignment: .leading, spacing: 12) {
          // Title and badge
          HStack(alignment: .top) {
            Text(template.name)
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.white)
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            Spacer()

            if template.isActive {
              Text("Active")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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
              .font(.system(size: 15))
              .foregroundColor(.white.opacity(0.8))
              .lineLimit(3)
              .multilineTextAlignment(.leading)
          }

          // Metadata
          VStack(spacing: 8) {
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
            }
            
            HStack {
              // Date
              Text((template.updatedAt ?? template.createdAt) ?? Date(), style: .date)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
              
              Spacer()
            }
          }
          .padding(.top, 4)
        }
      }
    }
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

// MARK: - Form Template Detail View (Updated)

struct FormTemplateDetailView: View {
  var template: FormTemplate

  @State private var isAddingTemplate = false
  @State private var animateContent = false
  @State private var showingPreview = false

  var body: some View {
    ZStack {
      // Unified Background
      TMIBackgroundView(variant: .default)

      ScrollView {
        VStack(spacing: 24) {
          // Header
          formHeader
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : -20)
            .animation(
              .spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateContent)

          // Description
          TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 16) {
              Text("Description")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

              Text(template.templateDescription)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(.horizontal, 20)
          .opacity(animateContent ? 1 : 0)
          .offset(y: animateContent ? 0 : 20)
          .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animateContent)

          // Preview Button
          TMIButton(
            text: "Preview Form",
            icon: "eye.fill",
            style: .primary,
            action: {
              showingPreview = true
            }
          )
          .padding(.horizontal, 20)
          .opacity(animateContent ? 1 : 0)
          .offset(y: animateContent ? 0 : 20)
          .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: animateContent)

          // Form Preview
          formPreview
            .padding(.horizontal, 20)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 30)
            .animation(
              .spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: animateContent)

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

          Button(
            role: .destructive,
            action: {
              // Delete action
            }
          ) {
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
    .onAppear {
      withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
        animateContent = true
      }
    }
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showingPreview) {
      FormPreviewView(template: template)
    }
  }

  private var formHeader: some View {
    TMIGlassCard(style: .default) {
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
      }
    }
    .padding(.horizontal, 20)
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

// MARK: - Section Preview Card (Updated)

struct SectionPreviewCard: View {
  var section: FormSection

  @State private var isExpanded = false

  var body: some View {
    TMIGlassCard(style: .minimal) {
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
    }
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
    TMIGlassCard(style: .minimal) {
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
    }
  }

  @ViewBuilder
  private var fieldContent: some View {
    switch field.type {
    case .text:
      TMITextField(
        icon: "text.cursor",
        placeholder: field.placeholder ?? "Enter text",
        text: $textValue
      )
      .onChange(of: textValue) { _, newValue in
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
        .onChange(of: textValue) { _, newValue in
          onValueChange(newValue)
        }

    case .number:
      TMITextField(
        icon: "number",
        placeholder: field.placeholder ?? "Enter number",
        text: $numberValue,
        keyboardType: .numberPad
      )
      .onChange(of: numberValue) { _, newValue in
        onValueChange(newValue)
      }

    case .date:
      DatePicker("", selection: $dateValue, displayedComponents: .date)
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Color.tmiSecondary)
        .onChange(of: dateValue) { _, newValue in
          onValueChange(newValue)
        }

    case .time:
      DatePicker("", selection: $dateValue, displayedComponents: .hourAndMinute)
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Color.tmiSecondary)
        .onChange(of: dateValue) { _, newValue in
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
                  .foregroundColor(
                    selectedOption == option ? Color.tmiSecondary : .white.opacity(0.6))

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
                Image(
                  systemName: selectedOptions.contains(option) ? "checkmark.square.fill" : "square"
                )
                .foregroundColor(
                  selectedOptions.contains(option) ? Color.tmiSecondary : .white.opacity(0.6))

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
      TMIButton(
        text: "Upload File",
        icon: "doc.badge.plus",
        style: .secondary,
        action: {
          // File upload logic would go here
        }
      )

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
        .onChange(of: dateValue) { _, newValue in
          onValueChange(newValue)
        }
    case .email:
      TMITextField(
        icon: "envelope",
        placeholder: field.placeholder ?? "Enter email",
        text: $textValue,
        keyboardType: .emailAddress
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }
    case .phoneNumber:
      TMITextField(
        icon: "phone",
        placeholder: field.placeholder ?? "Enter phone number",
        text: $textValue,
        keyboardType: .phonePad
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }
    case .url:
      TMITextField(
        icon: "link",
        placeholder: field.placeholder ?? "Enter URL",
        text: $textValue,
        keyboardType: .URL
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }
    case .allCases:
      EmptyView()
    }
  }
}

// MARK: - Progress Indicator

struct FormsProgressIndicator: View {
  var current: Int
  var total: Int

  private var progress: CGFloat {
    total > 0 ? CGFloat(current) / CGFloat(total) : 0
  }

  var body: some View {
    VStack(spacing: 8) {
      // Progress bar
      ProgressView(value: progress)
        .tmiProgressStyle(color: .tmiSecondary)

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

// MARK: - Form Creation View (Updated)

struct FormCreationView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var formName = ""
  @State private var formDescription = ""
  @State private var selectedCategory = "Survey"
  
  let categories = ["Survey", "Assessment", "Feedback", "Registration", "Other"]

  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            TMIGlassCard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "square.and.pencil")
                  .font(.system(size: 40))
                  .foregroundColor(.tmiSecondary)
                
                Text("Create New Form")
                  .font(.title2.bold())
                  .foregroundColor(.white)
                
                Text("Start building your custom form from scratch")
                  .font(.body)
                  .foregroundColor(.white.opacity(0.8))
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)
            
            // Form details
            TMIGlassCard(style: .default) {
              VStack(spacing: 20) {
                TMITextField(
                  icon: "doc.text",
                  placeholder: "Form Name",
                  text: $formName
                )
                
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Image(systemName: "text.alignleft")
                      .font(.system(size: 16))
                      .foregroundColor(.tmiSecondary)
                    Text("Description")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.white)
                  }
                  
                  TextEditor(text: $formDescription)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                      RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white)
                    .frame(height: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Image(systemName: "tag")
                      .font(.system(size: 16))
                      .foregroundColor(.tmiSecondary)
                    Text("Category")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.white)
                  }
                  
                  Menu {
                    ForEach(categories, id: \.self) { category in
                      Button(category) {
                        selectedCategory = category
                      }
                    }
                  } label: {
                    HStack {
                      Text(selectedCategory)
                        .foregroundColor(.white)
                      Spacer()
                      Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(12)
                    .background(
                      RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                    )
                  }
                }
              }
            }
            
            // Action buttons
            VStack(spacing: 12) {
              TMIButton(
                text: "Continue to Builder",
                icon: "arrow.right",
                style: .primary,
                isDisabled: formName.isEmpty,
                action: {
                  // Navigate to form builder with these details
                  dismiss()
                }
              )
              
              TMIButton(
                text: "Start from Template",
                icon: "doc.on.doc",
                style: .secondary,
                action: {
                  // Show template selection
                  dismiss()
                }
              )
            }
            .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
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
      .preferredColorScheme(.dark)
  }
}

// MARK: - Form Builder View

struct FormBuilderView: View {
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            // Header
            TMIGlassCard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                  .font(.system(size: 40))
                  .foregroundColor(.tmiSecondary)
                
                Text("Form Builder")
                  .font(.title2.bold())
                  .foregroundColor(.white)
                
                Text("Drag and drop fields to create your custom form")
                  .font(.body)
                  .foregroundColor(.white.opacity(0.8))
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)
            
            // Coming soon message
            TMIGlassCard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "wrench.and.screwdriver.fill")
                  .font(.system(size: 60))
                  .foregroundColor(.orange)
                
                Text("Coming Soon")
                  .font(.title.bold())
                  .foregroundColor(.white)
                
                Text("The drag-and-drop form builder is currently under development. For now, you can use our pre-built templates from the Forms & Surveys library.")
                  .font(.body)
                  .foregroundColor(.white.opacity(0.8))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal)
              }
            }
            
            TMIButton(
              text: "View Templates",
              icon: "doc.on.doc.fill",
              style: .primary,
              action: {
                dismiss()
              }
            )
            .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
        }
      }
      .navigationTitle("Form Builder")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .preferredColorScheme(.dark)
  }
}

// MARK: - Form Preview View

struct FormPreviewView: View {
  let template: FormTemplate
  @Environment(\.dismiss) private var dismiss
  @State private var currentSectionIndex = 0
  @State private var fieldValues: [String: Any] = [:]
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Progress indicator
          if template.sections.count > 1 {
            FormsProgressIndicator(
              current: currentSectionIndex + 1,
              total: template.sections.count
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
          }
          
          // Current section
          ScrollView {
            VStack(spacing: 20) {
              if currentSectionIndex < template.sections.count {
                let currentSection = template.sections[currentSectionIndex]
                
                // Section header
                TMIGlassCard(style: .default) {
                  VStack(spacing: 12) {
                    Text(currentSection.title)
                      .font(.title2.bold())
                      .foregroundColor(.white)
                    
                    if let description = currentSection.description, !description.isEmpty {
                      Text(description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    }
                  }
                }
                .padding(.top, 20)
                
                // Fields
                ForEach(currentSection.fields) { field in
                  DynamicFieldView(field: field) { value in
                    if let fieldId = field.id {
                      fieldValues[fieldId] = value
                    }
                  }
                }
              }
              
              Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
          }
          
          // Navigation buttons
          HStack(spacing: 16) {
            if currentSectionIndex > 0 {
              TMIButton(
                text: "Previous",
                icon: "chevron.left",
                style: .secondary,
                action: {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentSectionIndex -= 1
                  }
                }
              )
            }
            
            Spacer()
            
            if currentSectionIndex < template.sections.count - 1 {
              TMIButton(
                text: "Next",
                icon: "chevron.right",
                style: .primary,
                action: {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentSectionIndex += 1
                  }
                }
              )
            } else {
              TMIButton(
                text: "Complete Preview",
                icon: "checkmark",
                style: .primary,
                action: {
                  dismiss()
                }
              )
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
        }
      }
      .navigationTitle("Preview: \(template.name)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .preferredColorScheme(.dark)
  }
}

// MARK: - Form Import View

struct FormImportView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedFile: URL?
  @State private var showingFilePicker = false
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            // Header
            TMIGlassCard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down.fill")
                  .font(.system(size: 40))
                  .foregroundColor(.tmiSecondary)
                
                Text("Import Form")
                  .font(.title2.bold())
                  .foregroundColor(.white)
                
                Text("Import existing forms from JSON files or other compatible formats")
                  .font(.body)
                  .foregroundColor(.white.opacity(0.8))
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)
            
            // File selection
            TMIGlassCard(style: .default) {
              VStack(spacing: 20) {
                if let file = selectedFile {
                  HStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                      .font(.system(size: 24))
                      .foregroundColor(.tmiSecondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                      Text(file.lastPathComponent)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                      
                      Text("Ready to import")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                      showingFilePicker = true
                    }
                    .foregroundColor(.tmiSecondary)
                  }
                } else {
                  VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                      .font(.system(size: 40))
                      .foregroundColor(.white.opacity(0.3))
                    
                    Text("No file selected")
                      .font(.system(size: 18, weight: .medium))
                      .foregroundColor(.white.opacity(0.7))
                  }
                }
                
                TMIButton(
                  text: selectedFile == nil ? "Select File" : "Change File",
                  icon: "folder",
                  style: .secondary,
                  action: {
                    showingFilePicker = true
                  }
                )
              }
            }
            
            // Import button
            TMIButton(
              text: "Import Form",
              icon: "square.and.arrow.down",
              style: .primary,
              isDisabled: selectedFile == nil,
              action: {
                // Import the form
                dismiss()
              }
            )
            .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
        }
      }
      .navigationTitle("Import Form")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .preferredColorScheme(.dark)
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [.json, .data],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let files):
          if let file = files.first {
            selectedFile = file
          }
        case .failure(let error):
          print("Error selecting file: \(error)")
        }
      }
  }
}

// MARK: - Loading Indicator (Kept as specialized component)

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
              Color.tmiSecondary,
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

// MARK: - Preview

#Preview {
  FormsAndSurveysView()
}
