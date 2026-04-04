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
      TMIBackgroundView(variant: .base)

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
    .navigationTitle("Forms")
    .foregroundColor(Color.tmiTextPrimary)
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
            .foregroundColor(Color.tmiTextPrimary)
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
    .sheet(isPresented: $showingFormCreation) {
      FormCreationView()
        .tmiSheetStyle()
    }
    .sheet(isPresented: $showingFormBuilder) {
      FormBuilderView()
        .tmiSheetStyle()
    }
    .sheet(isPresented: $showingFormImport) {
      FormImportView()
        .tmiSheetStyle()
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
        .foregroundColor(Color.tmiTextPrimary)
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
          .foregroundColor(Color.tmiTextSecondary)
      }
      .padding(.top, 80)

      Text("No Forms Found")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundColor(Color.tmiTextPrimary)

      Text("Create your first form to start collecting data for TMI")
        .font(.system(size: 16))
        .foregroundColor(Color.tmiTextSecondary)
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















// MARK: - Preview

#Preview {
  FormsAndSurveysView()
}
