//
//  FormStoreCardView.swift
//  TMI
//
//  Card view for displaying form templates
//

import SwiftUI

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
              .foregroundColor(Color.tmiTextPrimary)
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
              .foregroundColor(Color.tmiTextSecondary)
              .lineLimit(3)
              .multilineTextAlignment(.leading)
          }

          // Metadata
          VStack(spacing: 8) {
            HStack(spacing: 16) {
              // Sections
              Label("\(template.sections.count) sections", systemImage: "list.bullet")
                .font(.system(size: 13))
                .foregroundColor(Color.tmiTextSecondary)

              // Category
              if let category = template.category {
                Label(category, systemImage: "tag")
                  .font(.system(size: 13))
                  .foregroundColor(Color.tmiTextSecondary)
              }
              
              Spacer()
            }
            
            HStack {
              // Date
              Text((template.updatedAt ?? template.createdAt) ?? Date(), style: .date)
                .font(.system(size: 13))
                .foregroundColor(Color.tmiTextSecondary)
              
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
