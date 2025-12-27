//
//  FormTemplateCard.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #3
//

import SwiftUI

struct FormTemplateCard: View {
  let template: FormTemplate
  let onTap: () -> Void
  let onExport: () -> Void
  let onDuplicate: () -> Void
  let onDelete: () -> Void
  let onTogglePublic: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header with menu
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(template.name)
            .font(.headline)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

          if let category = template.category {
            Text(category)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        Menu {
          Button {
            onTap()
          } label: {
            Label("View Details", systemImage: "eye")
          }

          Divider()

          Button {
            onExport()
          } label: {
            Label("Export JSON", systemImage: "square.and.arrow.up")
          }

          Button {
            onDuplicate()
          } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
          }

          Divider()

          Button {
            onTogglePublic()
          } label: {
            if template.isPublic {
              Label("Make Private", systemImage: "lock")
            } else {
              Label("Make Public", systemImage: "globe")
            }
          }

          Divider()

          Button(role: .destructive) {
            onDelete()
          } label: {
            Label("Delete", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .foregroundColor(.secondary)
        }
      }

      Divider()

      // Description
      Text(template.templateDescription)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(3)

      Spacer()

      // Footer
      HStack {
        // Public indicator
        if template.isPublic {
          Label("Public", systemImage: "globe")
            .font(.caption2)
            .foregroundColor(.blue)
        }

        Spacer()

        // Section count
        Text("\(template.sections.count) sections")
          .font(.caption2)
          .foregroundColor(.secondary)

        // Version
        Text("v\(template.version)")
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      // Tags
      if !template.tags.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(template.tags.prefix(3), id: \.self) { tag in
              Text(tag)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
          }
        }
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    .onTapGesture {
      onTap()
    }
  }
}

#Preview {
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    FormTemplateCard(
      template: FormTemplate(
        name: "Student Intake Form",
        templateDescription: "Comprehensive intake form for new students including demographic information, academic history, and support needs.",
        sections: [FormSection(title: "Demographics", fields: [])],
        isActive: true,
        category: "Student Services",
        tags: ["intake", "student", "demographics"],
        isPublic: true,
        version: 2
      ),
      onTap: {},
      onExport: {},
      onDuplicate: {},
      onDelete: {},
      onTogglePublic: {}
    )

    FormTemplateCard(
      template: FormTemplate.parentalIncarcerationSupportTemplate,
      onTap: {},
      onExport: {},
      onDuplicate: {},
      onDelete: {},
      onTogglePublic: {}
    )
  }
  .padding()
  .background(Color(UIColor.secondarySystemBackground))
}
