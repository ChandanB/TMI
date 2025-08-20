//
//  InterestAssociatedData.swift
//  TMI
//
//  Created by Chandan Brown on 8/20/25.
//

import SwiftUI

// MARK: - Associated Data Types

struct InterestAssociatedData {
    let associatedStudents: [Student]
    let connectedTMIPlans: [TMIPlan]
    let engagementMetrics: EngagementMetrics?
}

struct HobbyAssociatedData {
    let associatedStudents: [Student]
    let connectedTMIPlans: [TMIPlan]
    let engagementMetrics: EngagementMetrics?
}

struct EngagementMetrics {
    let averageEngagement: Double
    let totalInteractions: Int
    let lastUpdated: Date
}

// MARK: - Environment Key

struct InterestsStateModelKey: EnvironmentKey {
    static let defaultValue = InterestsAndHobbiesStateModel()
}

extension EnvironmentValues {
    var interestsStateModel: InterestsAndHobbiesStateModel {
        get { self[InterestsStateModelKey.self] }
        set { self[InterestsStateModelKey.self] = newValue }
    }
}

// MARK: - Helper Functions

/// Creates a two-way binding to a property on an observable object
func binding<T, V>(_ object: T, _ keyPath: ReferenceWritableKeyPath<T, V>) -> Binding<V> {
    Binding(
        get: { object[keyPath: keyPath] },
        set: { object[keyPath: keyPath] = $0 }
    )
}

// MARK: - TMI Component Extensions

// These components should ideally be in TMIComponentLibrary, but for now we'll define them here
// as placeholders until the actual component library is updated

extension TMIBackgroundView {
    enum InterestsBackgroundVariant {
        case interests
        case detail
        case sheet
        case `default`
    }
    
    init(variant: InterestsBackgroundVariant) {
        // Use the existing TMIBackgroundView.BackgroundVariant
        switch variant {
        case .interests:
            self.init(variant: TMIBackgroundView.BackgroundVariant.dashboard)
        case .detail:
            self.init(variant: TMIBackgroundView.BackgroundVariant.dashboard)
        case .sheet:
            self.init(variant: TMIBackgroundView.BackgroundVariant.dashboard)
        case .default:
            self.init(variant: TMIBackgroundView.BackgroundVariant.dashboard)
        }
    }
}

// MARK: - Missing TMI Components
// These should be added to the main TMIComponentLibrary

struct TMISearchBar: View {
    @Binding var text: String
    let placeholder: String
    let style: TMIComponentStyle
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TMISegmentedControl<T: CaseIterable & Identifiable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let options: [T]
    let style: TMIComponentStyle
    @Namespace private var selectionAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.id) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(option.rawValue)
                            .font(.system(size: 16, weight: selection == option ? .semibold : .medium))
                            .foregroundColor(selection == option ? .white : .white.opacity(0.6))
                        
                        if selection == option {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.tmiPrimary)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "selection", in: selectionAnimation)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
    }
}

struct TMICard<Content: View>: View {
    let style: TMIComponentStyle
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TMIEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let style: TMIComponentStyle
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil, style: TMIComponentStyle) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: style == .compact ? 40 : 60))
                .foregroundColor(.white.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(style == .compact ? .headline : .title2.bold())
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, style == .compact ? 20 : 40)
            }
            
            if let actionTitle = actionTitle, let action = action {
                TMIButton(text: actionTitle, style: .secondary, action: action)
            }
        }
        .padding()
    }
}

struct TMIBadge: View {
    let text: String
    let color: Color
    let style: TMIComponentStyle
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(style == .solid ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(style == .solid ? color : color.opacity(0.15))
            )
    }
}

struct TMITextEditor: View {
    @Binding var text: String
    let placeholder: String
    let style: TMIComponentStyle
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TMITagSelector<T: CaseIterable & Identifiable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let options: [T]
    let color: Color
    let style: TMIComponentStyle
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options, id: \.id) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 14, weight: selection == option ? .semibold : .regular))
                            .foregroundColor(selection == option ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selection == option ? color.opacity(0.3) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selection == option ? color.opacity(0.5) : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TMIIconSelector: View {
    @Binding var selection: String
    let icons: [String]
    let color: Color
    let style: TMIComponentStyle
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selection = icon
                    } label: {
                        ZStack {
                            Circle()
                                .fill(selection == icon ? color.opacity(0.15) : Color.white.opacity(0.05))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .foregroundColor(selection == icon ? color : .white.opacity(0.7))
                        }
                        .overlay(
                            Circle()
                                .stroke(
                                    selection == icon ? color.opacity(0.5) : Color.white.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct TMIStudentCard: View {
    let student: Student
    let color: Color
    let style: TMIComponentStyle
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(String(student.name.prefix(1)))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.3))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(student.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Grade \(student.grade) • \(Int(student.engagementScore * 100))% engaged")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// TMIPlanCard and TMIStatCard are already defined in their respective files

// MARK: - Component Style Enum

enum TMIComponentStyle {
    case glass
    case solid
    case compact
    case primary
    case secondary
}
