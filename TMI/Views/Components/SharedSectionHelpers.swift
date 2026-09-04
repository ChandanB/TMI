// SharedSectionHelpers.swift
// TMI
//
// Reusable helper views shared between Student and Plan accordion sections.
// These were extracted from their original Student section files so that both
// the Students and TMIPlans feature areas can reference a single canonical copy.

import SwiftUI

// MARK: - FlowLayout

/// A custom Layout that wraps its children into rows like a flow/flexbox layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > containerWidth, currentX > 0 {
                currentY += rowHeight + spacing
                totalHeight = currentY
                currentX = 0
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        var rowViews: [(subview: LayoutSubview, size: CGSize, x: CGFloat)] = []

        func placeRow() {
            for item in rowViews {
                item.subview.place(at: CGPoint(x: item.x, y: currentY), proposal: ProposedViewSize(item.size))
            }
            rowViews.removeAll()
        }

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                placeRow()
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            rowViews.append((subview: subview, size: size, x: currentX))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        placeRow()
    }
}

// MARK: - InterestChip

/// A capsule chip representing a single interest.
/// `isSelected` controls whether the chip shows a remove (×) action or an add (+) action.
struct InterestChip: View {
    let interest: Interest
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let primary = interest.primaryCategory {
                    Image(systemName: primary.iconName)
                        .font(.caption2)
                }
                Text(interest.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: isSelected ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.pink.opacity(0.15)
                    : Color(.systemGray5)
            )
            .foregroundStyle(isSelected ? Color.pink : Color.primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.pink.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - ResourceRow

struct ResourceRow: View {
    let resource: Resource
    let actionLabel: String
    let actionSystemImage: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: resource.category.icon)
                .font(.title3)
                .foregroundStyle(resource.category.color)
                .frame(width: 32, height: 32)
                .background(resource.category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Title + category
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(resource.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action button
            Button(action: action) {
                Label(actionLabel, systemImage: actionSystemImage)
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                actionLabel == "Remove" ? Color.red : Color.accentColor
            )
            .accessibilityLabel(Text("\(actionLabel) \(resource.title)"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.tmiSurface, in: RoundedRectangle(cornerRadius: 10))
    }
}
