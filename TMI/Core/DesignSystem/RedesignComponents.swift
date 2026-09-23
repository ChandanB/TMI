//
//  RedesignComponents.swift
//  TMI
//
//  Shared Golden Hour building blocks used across screens.
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
        HStack(spacing: TMISpacing.ms) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TMIColors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                }
            }

            Spacer(minLength: TMISpacing.sm)

            trailing
        }
        .padding(.horizontal, TMISpacing.md)
        .padding(.vertical, TMISpacing.ms)
        .frame(minHeight: TMISizing.listRowHeight)
        .background(TMIColors.surface, in: TMIShape.control)
        .contentShape(TMIShape.control)
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
            case .up: "arrow.up.right"
            case .down: "arrow.down.right"
            case .neutral: "minus"
            }
        }

        var tone: TMITone {
            switch self {
            case .up: .success
            case .down: .danger
            case .neutral: .neutral
            }
        }
    }

    init(
        value: String,
        label: String,
        trend: Trend? = nil,
        color: Color = TMIColors.textPrimary
    ) {
        self.value = value
        self.label = label
        self.trend = trend
        self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())

                if let trend {
                    Image(systemName: trend.icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trend.tone.text)
                }
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(TMIColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tmiSurface(.raised, padding: TMISpacing.ms + 2, radius: TMIRadius.control + 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty State

/// Calm, composed empty/error state: a soft amber disc with a symbol, a
/// title, one sentence, and at most one action.
struct TMIEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionLabel: String?

    @ScaledMetric(relativeTo: .largeTitle) private var disc: CGFloat = 84

    var body: some View {
        VStack(spacing: TMISpacing.ml) {
            Image(systemName: icon)
                .font(.system(size: disc * 0.4, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(TMIColors.accent)
                .frame(width: disc, height: disc)
                .background(TMIColors.accentSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: TMISpacing.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TMIColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.body)
                    .foregroundStyle(TMIColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            if let action, let actionLabel {
                Button(actionLabel, action: action)
                    .buttonStyle(.tmiPrimary)
            }
        }
        .padding(TMISpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Bar

/// Inline search field. Prefer `.searchable` on navigation containers; use
/// this only inside sheets or panes that have no search placement.
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
        HStack(spacing: TMISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TMIColors.textTertiary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(TMIColors.textTertiary))
                .font(.body)
                .foregroundStyle(TMIColors.textPrimary)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TMIColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, TMISpacing.ms)
        .frame(minHeight: TMISizing.minTouchTarget - 6)
        .background(TMIColors.fill, in: Capsule())
    }
}

// MARK: - Filter Chip

struct TMIFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(label)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? TMIColors.accent : TMIColors.textPrimary)
            .padding(.horizontal, TMISpacing.ms)
            .padding(.vertical, 7)
            .background(isSelected ? TMIColors.accentSoft : TMIColors.fill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isSelected ? TMIColors.accent.opacity(0.35) : Color.clear, lineWidth: 1)
            }
            .padding(.vertical, 4)
            .contentShape(Capsule())
            .animation(TMIAnimation.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - FAB

/// Floating action on Liquid Glass tinted with the brand amber.
struct TMIFAB: View {
    let icon: String
    var label: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TMISpacing.sm) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))

                if let label {
                    Text(label)
                        .font(.tmiButton)
                }
            }
            .foregroundStyle(TMIColors.onBrand)
            .padding(.horizontal, label != nil ? TMISpacing.ml : 0)
            .frame(minWidth: TMISizing.fabSize, minHeight: TMISizing.fabSize)
            .glassEffect(.regular.tint(TMIColors.brand).interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "Add")
    }
}

// MARK: - Avatar

struct TMIAvatar: View {
    let initials: String
    var photoURL: String?
    /// Explicit tint. When left at the default, a stable per-person color is used.
    var color: Color?
    var size: CGFloat

    init(
        initials: String,
        photoURL: String? = nil,
        color: Color? = nil,
        size: CGFloat = TMISizing.avatarSm
    ) {
        self.initials = initials
        self.photoURL = photoURL
        // The legacy default passed the brand color everywhere; treat it as "auto".
        self.color = color == Color.tmiPrimary ? nil : color
        self.size = size
    }

    private var colors: TMIAvatarColors {
        if let color {
            return TMIAvatarColors(background: color.opacity(0.16), foreground: color)
        }
        return TMIAvatarColors.forKey(initials)
    }

    var body: some View {
        Group {
            if let photoURLString = photoURL, let url = URL(string: photoURLString) {
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .accessibilityHidden(true)
    }

    private var initialsView: some View {
        Text(initials.uppercased())
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(colors.foreground)
            .frame(width: size, height: size)
            .background(colors.background, in: Circle())
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
        color: Color = TMIColors.chartPrimary
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(TMIColors.chartTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(TMIAnimation.smooth, value: progress)

            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: size * 0.25, weight: .semibold).monospacedDigit())
                .foregroundStyle(TMIColors.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

// MARK: - Divider

struct TMIDivider: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(TMIColors.separator)
            .frame(height: 1 / max(displayScale, 1))
    }
}
