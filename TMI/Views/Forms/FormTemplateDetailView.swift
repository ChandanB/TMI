//
//  FormTemplateDetailView.swift
//  TMI
//
//  Detail view for form templates
//

import SwiftUI

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
