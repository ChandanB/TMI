//
//  FormTemplateLibraryView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #3
//

import SwiftUI
import UniformTypeIdentifiers

struct FormTemplateLibraryView: View {
  @State private var viewModel = FormTemplateLibraryViewModel()
  @State private var showingImportPicker = false
  @State private var showingTemplateDetail = false
  @State private var showingTemplateEditor = false
  @Environment(\.authStateModel) private var authStateModel

  var body: some View {
    ZStack {
      TMIBackgroundView(variant: .dashboard)

      if viewModel.isLoading && viewModel.templates.isEmpty {
        ProgressView("Loading templates...")
      } else {
        content
      }
    }
    .navigationTitle("Form Templates")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      toolbarContent
    }
    .searchable(text: $viewModel.searchText, prompt: "Search templates")
    .onChange(of: viewModel.searchText) { _, newValue in
      viewModel.updateSearch(newValue)
    }
    .fileImporter(
      isPresented: $showingImportPicker,
      allowedContentTypes: [UTType.json],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          Task {
            await viewModel.importTemplate(from: url)
          }
        }
      case .failure(let error):
        viewModel.errorMessage = "Import failed: \(error.localizedDescription)"
      }
    }
    .task {
      if !viewModel.hasTemplates {
        await viewModel.loadTemplates(districtId: authStateModel.currentUser?.districtId)
      }
    }
    .refreshable {
      await viewModel.refreshTemplates(districtId: authStateModel.currentUser?.districtId)
    }
    .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") {
        viewModel.errorMessage = nil
      }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
  }

  // MARK: - Content

  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Filter chips
        filterSection

        if viewModel.hasFilteredResults {
          // Templates grid
          templatesGrid
        } else {
          emptyState
        }
      }
      .padding()
    }
  }

  // MARK: - Filter Section

  private var filterSection: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        // Category filter
        Menu {
          Button("All Categories") {
            viewModel.selectCategory(nil)
          }

          Divider()

          ForEach(viewModel.categories, id: \.self) { category in
            Button(category) {
              viewModel.selectCategory(category)
            }
          }
        } label: {
          Label(
            viewModel.selectedCategory ?? "All Categories",
            systemImage: "folder"
          )
          .font(.subheadline)
          .foregroundColor(.primary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(UIColor.secondarySystemBackground))
          .cornerRadius(16)
        }

        // Public filter
        Button {
          viewModel.togglePublicFilter()
        } label: {
          Label("Public", systemImage: viewModel.showPublicOnly ? "checkmark.circle.fill" : "circle")
            .font(.subheadline)
            .foregroundColor(viewModel.showPublicOnly ? .blue : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }

        // Private filter
        Button {
          viewModel.togglePrivateFilter()
        } label: {
          Label("Private", systemImage: viewModel.showPrivateOnly ? "checkmark.circle.fill" : "circle")
            .font(.subheadline)
            .foregroundColor(viewModel.showPrivateOnly ? .blue : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }

        // Clear filters
        if viewModel.searchText.isEmpty == false || viewModel.selectedCategory != nil || viewModel.showPublicOnly || viewModel.showPrivateOnly {
          Button {
            viewModel.clearFilters()
          } label: {
            Label("Clear", systemImage: "xmark.circle.fill")
            .font(.subheadline)
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
          }
        }
      }
      .padding(.horizontal, 4)
    }
  }

  // MARK: - Templates Grid

  private var templatesGrid: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(viewModel.filteredTemplates) { template in
        FormTemplateCard(
          template: template,
          onTap: {
            viewModel.selectedTemplate = template
            showingTemplateDetail = true
          },
          onExport: {
            Task {
              await viewModel.exportTemplate(template)
            }
          },
          onDuplicate: {
            Task {
              await viewModel.duplicateTemplate(template)
            }
          },
          onDelete: {
            Task {
              await viewModel.deleteTemplate(template)
            }
          },
          onTogglePublic: {
            if template.isPublic {
              Task {
                await viewModel.makePrivate(template)
              }
            } else {
              if let districtId = authStateModel.currentUser?.districtId {
                Task {
                  await viewModel.makePublic(template, districtId: districtId)
                }
              }
            }
          }
        )
      }
    }
    .sheet(isPresented: $showingTemplateDetail) {
      if let template = viewModel.selectedTemplate {
        FormTemplateDetailView(template: template)
      }
    }
    .sheet(isPresented: $showingTemplateEditor) {
      NavigationStack {
        FormTemplateEditorView()
      }
      .onDisappear {
        // Refresh templates after creation
        Task {
          await viewModel.refreshTemplates(districtId: authStateModel.currentUser?.districtId)
        }
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text("No Templates Found")
        .font(.headline)

      Text("Try adjusting your filters or import a template")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button {
        showingImportPicker = true
      } label: {
        Label("Import Template", systemImage: "square.and.arrow.down")
          .font(.subheadline)
          .fontWeight(.medium)
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Menu {
        Button {
          showingImportPicker = true
        } label: {
          Label("Import Template", systemImage: "square.and.arrow.down")
        }

        Button {
          showingTemplateEditor = true
        } label: {
          Label("Create New", systemImage: "plus.circle")
        }
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 22))
      }
    }
  }
}

#Preview {
  NavigationStack {
    FormTemplateLibraryView()
  }
}


