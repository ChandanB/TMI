//
//  RedesignComponents.swift
//  TMI
//
//  Lightweight components for redesigned views
//  These wrap or extend existing components for the new design
//

import SwiftUI
import SDWebImageSwiftUI

// MARK: - List Row

struct TMIListRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: TMISpacing.medium) {
            leading

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                }
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, TMISpacing.medium)
        .padding(.vertical, TMISpacing.sm)
        .frame(minHeight: TMISizing.listRowHeight)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.md)
    }
}

// MARK: - Stat Chip

struct TMIStatChip: View {
    let value: String
    let label: String
    var trend: Trend?
    var color: Color

    enum Trend {
        case up, down, neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return .tmiSuccess
            case .down: return .tmiError
            case .neutral: return .tmiTextSecondary
            }
        }
    }

    init(
        value: String,
        label: String,
        trend: Trend? = nil,
        color: Color = .tmiPrimary
    ) {
        self.value = value
        self.label = label
        self.trend = trend
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.tmiTitle3)
                    .foregroundColor(color)

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(trend.color)
                }
            }

            Text(label)
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
        }
        .padding(TMISpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.small)
    }
}

// MARK: - Empty State (Wrapper around existing)

struct TMIEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        VStack(spacing: TMISpacing.large) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.tmiTextTertiary)

            VStack(spacing: TMISpacing.small) {
                Text(title)
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Text(message)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let actionLabel = actionLabel {
                TMIButton(
                    text: actionLabel,
                    style: .primary,
                    action: action
                )
            }
        }
        .padding(TMISpacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Bar (Simplified wrapper)

struct TMISearchBar: View {
    @Binding var text: String
    var placeholder: String

    init(
        text: Binding<String>,
        placeholder: String = "Search"
    ) {
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack(spacing: TMISpacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.tmiTextSecondary)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.tmiTextTertiary))
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.tmiTextTertiary)
                }
            }
        }
        .padding(.horizontal, TMISpacing.medium)
        .frame(height: TMISizing.minTouchTarget)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.small)
    }
}

// MARK: - Filter Chip

struct TMIFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.tmiCaption)
                .foregroundColor(isSelected ? .white : .tmiTextPrimary)
                .padding(.horizontal, TMISpacing.medium)
                .padding(.vertical, TMISpacing.small)
                .background(isSelected ? Color.tmiSecondary : Color.tmiSurface)
                .cornerRadius(TMIRadius.pill)
                .overlay(
                    !isSelected ?
                    RoundedRectangle(cornerRadius: TMIRadius.pill)
                        .stroke(Color.tmiBorder, lineWidth: 1) : nil
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FAB

struct TMIFAB: View {
    let icon: String
    var label: String?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: TMISpacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))

                if let label = label {
                    Text(label)
                        .font(.tmiButton)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, label != nil ? TMISpacing.large : 0)
            .frame(width: label != nil ? nil : TMISizing.fabSize, height: TMISizing.fabSize)
            .background(Color.tmiPrimary)
            .cornerRadius(TMIRadius.pill)
            .shadow(
                color: .black.opacity(TMIElevation.floating.shadowOpacity),
                radius: TMIElevation.floating.shadowRadius,
                x: 0,
                y: TMIElevation.floating.shadowOffset.height
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(TMIAnimation.springInteractive, value: isPressed)
    }
}

// MARK: - Avatar

struct TMIAvatar: View {
    let initials: String
    var photoURL: String?
    var color: Color
    var size: CGFloat

    init(
        initials: String,
        photoURL: String? = nil,
        color: Color = .tmiPrimary,
        size: CGFloat = TMISizing.avatarSm
    ) {
        self.initials = initials
        self.photoURL = photoURL
        self.color = color
        self.size = size
    }

    var body: some View {
        Group {
            if let photoURLString = photoURL, let url = URL(string: photoURLString) {
                // Use async image loading with SDWebImage
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                        ProgressView()
                            .tint(color)
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Show initials fallback
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))

                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(color)
                }
                .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Progress Circle

struct TMIProgressCircle: View {
    let progress: Double
    var size: CGFloat
    var lineWidth: CGFloat
    var color: Color

    init(
        progress: Double,
        size: CGFloat = 40,
        lineWidth: CGFloat = 4,
        color: Color = .tmiPrimary
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.tmiBorder, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.25, weight: .semibold))
                .foregroundColor(.tmiTextPrimary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Divider

struct TMIDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.tmiDivider)
            .frame(height: 1)
    }
}
