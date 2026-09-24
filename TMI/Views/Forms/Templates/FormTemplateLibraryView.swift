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
  @State private var pendingDelete: FormTemplate?
  @Environment(\.authStateModel) private var authStateModel

  var body: some View {
    ZStack {
      TMIColors.background.ignoresSafeArea()

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
        await viewModel.loadTemplates(districtId: authStateModel.currentMembership?.districtID)
      }
    }
    .refreshable {
      await viewModel.refreshTemplates(districtId: authStateModel.currentMembership?.districtID)
    }
    .alert("Something went wrong", isPresented: Binding(
      get: { viewModel.errorMessage != nil },
      set: { if !$0 { viewModel.errorMessage = nil } }
    )) {
      Button("OK", role: .cancel) {
        viewModel.errorMessage = nil
      }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
    // Sheets live on the root so "Create New" works even when the library is
    // empty or filtered to nothing (they used to hang off the grid).
    .sheet(isPresented: $showingTemplateDetail) {
      if let template = viewModel.selectedTemplate {
        NavigationStack {
          FormTemplateDetailView(template: template)
        }
        .tmiSheetStyle()
      }
    }
    .sheet(isPresented: $showingTemplateEditor) {
      // The editor owns its NavigationStack.
      FormTemplateEditorView()
        .tmiSheetStyle()
        .onDisappear {
          Task {
            await viewModel.refreshTemplates(districtId: authStateModel.currentMembership?.districtID)
          }
        }
    }
    .confirmationDialog(
      "Delete “\(pendingDelete?.name ?? "template")”?",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible,
      presenting: pendingDelete
    ) { template in
      Button("Delete Template", role: .destructive) {
        Task { await viewModel.deleteTemplate(template) }
      }
      Button("Cancel", role: .cancel) { }
    } message: { _ in
      Text("Existing assignments keep their frozen copy. This can’t be undone.")
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
          .font(.subheadline.weight(.medium))
          .foregroundStyle(TMIColors.textPrimary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(TMIColors.fill, in: Capsule())
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
            .background(TMIColors.fill)
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
            .background(TMIColors.fill)
            .cornerRadius(16)
        }

        // Clear filters
        if viewModel.searchText.isEmpty == false || viewModel.selectedCategory != nil || viewModel.showPublicOnly || viewModel.showPrivateOnly {
          Button {
            viewModel.clearFilters()
          } label: {
            Label("Clear", systemImage: "xmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(TMIColors.errorText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TMIColors.fill)
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
            pendingDelete = template
          },
          onTogglePublic: {
            if template.isPublic {
              Task {
                await viewModel.makePrivate(template)
              }
            } else {
              if let districtId = authStateModel.currentMembership?.districtID {
                Task {
                  await viewModel.makePublic(template, districtId: districtId)
                }
              }
            }
          }
        )
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.largeTitle)
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
          .font(.title2)
      }
    }
  }
}

#Preview {
  NavigationStack {
    FormTemplateLibraryView()
  }
}

