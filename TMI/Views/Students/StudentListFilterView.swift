// StudentListFilterView.swift

import SwiftUI

enum FilterOption: String, CaseIterable, Identifiable {
  var id: String { self.rawValue }

  case all = "All"
  case active = "Active TMI"
  case inactive = "Inactive TMI"
  case highEngagement = "High Engagement"
  case lowEngagement = "Low Engagement"
}

struct LegacyStudentListFilterView: View {
    @Binding var selectedOption: FilterOption
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    HStack {
                        Text(option.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                        if option == selectedOption {
                            Image(systemName: "checkmark")
                                .foregroundColor(.tmiPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedOption = option
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filter Students")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// Modern StudentListFilterView using TMI design system
struct StudentListFilterView: View {
    @Binding var selectedOption: FilterOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(FilterOption.allCases) { option in
                            StudentListFilterOptionCard(
                                option: option,
                                isSelected: selectedOption == option,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedOption = option
                                        dismiss()
                                    }
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filter Students")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct StudentListFilterOptionCard: View {
    var option: FilterOption
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                // Icon
                filterIcon
                    .padding(12)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.05))
                    )

                // Label
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(filterDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.tmiSecondary)
                        .font(.system(size: 22))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [Color.tmiSecondary.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? Color.tmiSecondary.opacity(0.2) : Color.clear, 
                radius: 10, x: 0, y: 5
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var filterIcon: some View {
        let iconName: String
        let iconColor: Color

        switch option {
        case .all:
            iconName = "person.3.fill"
            iconColor = .blue
        case .active:
            iconName = "checkmark.circle.fill"
            iconColor = .green
        case .inactive:
            iconName = "xmark.circle.fill"
            iconColor = .orange
        case .highEngagement:
            iconName = "chart.line.uptrend.xyaxis.circle.fill"
            iconColor = .green
        case .lowEngagement:
            iconName = "chart.line.downtrend.xyaxis.circle.fill"
            iconColor = .red
        }

        return Image(systemName: iconName)
            .font(.system(size: 20))
            .foregroundColor(iconColor)
    }

    private var filterDescription: String {
        switch option {
        case .all:
            return "View all enrolled students"
        case .active:
            return "Students with active TMI plans"
        case .inactive:
            return "Students without active TMI plans"
        case .highEngagement:
            return "Students with engagement score above 70%"
        case .lowEngagement:
            return "Students with engagement score below 30%"
        }
    }
}

#Preview {
    StudentListFilterView(selectedOption: .constant(.all))
}
