//
//  TMIKit.swift
//  TMI
//
//  Golden Hour component kit. Screens compose these instead of hand-styling
//  cards, buttons, badges and metrics. Tokens live in TMIColors,
//  TMIDesignTokens and RedesignBridge.
//

import Charts
import SwiftUI

// MARK: - Tone

/// Semantic tone shared by badges, icon tiles and metric deltas.
nonisolated enum TMITone: Sendable, Hashable {
    case neutral
    case brand
    case success
    case warning
    case danger
    case info

    var text: Color {
        switch self {
        case .neutral: TMIColors.textSecondary
        case .brand: TMIColors.accent
        case .success: TMIColors.successText
        case .warning: TMIColors.warningText
        case .danger: TMIColors.errorText
        case .info: TMIColors.infoText
        }
    }

    var surface: Color {
        switch self {
        case .neutral: TMIColors.fill
        case .brand: TMIColors.accentSoft
        case .success: TMIColors.successSurface
        case .warning: TMIColors.warningSurface
        case .danger: TMIColors.errorSurface
        case .info: TMIColors.infoSurface
        }
    }
}

// MARK: - Surfaces

/// Card treatment: surface fill, a hairline edge, and one soft shadow in light
/// mode only (dark mode relies on the hairline).
struct TMISurfaceModifier: ViewModifier {
    var elevation: TMIElevation
    var padding: CGFloat?
    var fill: Color
    var radius: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let isDark = colorScheme == .dark
        content
            .padding(padding ?? 0)
            .background(fill, in: shape)
            .overlay {
                shape.strokeBorder(TMIColors.separator, lineWidth: 1 / max(displayScale, 1))
            }
            .shadow(
                color: elevation.shadowColor.opacity(isDark ? 0 : elevation.secondaryShadowOpacity),
                radius: elevation.secondaryShadowRadius,
                x: 0,
                y: 1
            )
            .shadow(
                color: elevation.shadowColor.opacity(isDark ? elevation.shadowOpacity * 1.8 : elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowOffset.height
            )
    }
}

extension View {
    /// Places the view on a Golden Hour surface (card).
    func tmiSurface(
        _ elevation: TMIElevation = .raised,
        padding: CGFloat? = TMISpacing.cardPadding,
        fill: Color = TMIColors.surface,
        radius: CGFloat = TMIRadius.card
    ) -> some View {
        modifier(TMISurfaceModifier(elevation: elevation, padding: padding, fill: fill, radius: radius))
    }

    /// Paints the canvas behind a screen, edge to edge.
    func tmiScreenBackground() -> some View {
        background(TMIColors.background.ignoresSafeArea())
    }

    /// Uppercase, tracked small label above a title.
    func tmiEyebrow(_ color: Color = TMIColors.textTertiary) -> some View {
        font(.tmiEyebrow)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
    }

    /// Placeholder shimmer for first loads. Content keeps its layout; nothing jumps.
    func tmiPlaceholder(_ isActive: Bool) -> some View {
        modifier(TMIPlaceholderModifier(isActive: isActive))
    }
}

private struct TMIPlaceholderModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive {
            content
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
                .phaseAnimator(reduceMotion ? [1.0] : [1.0, 0.55]) { view, opacity in
                    view.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
                .accessibilityLabel("Loading")
        } else {
            content
        }
    }
}

// MARK: - Buttons

nonisolated enum TMIButtonProminence: Sendable, Hashable {
    /// Amber fill with ink label. One per view.
    case primary
    /// Quiet filled control.
    case secondary
    /// Text-only accent action.
    case tertiary
    /// Destructive, quiet (confirm with a dialog before acting).
    case destructive
}

/// The standard TMI button look. Use via `.buttonStyle(.tmiPrimary)` etc.
struct TMIActionButtonStyle: ButtonStyle {
    var prominence: TMIButtonProminence = .primary
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        TMIActionButtonBody(configuration: configuration, prominence: prominence, fullWidth: fullWidth)
    }
}

private struct TMIActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominence: TMIButtonProminence
    let fullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.displayScale) private var displayScale
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.tmiButton)
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: TMISizing.buttonHeight)
            .foregroundStyle(foreground)
            .background(background, in: TMIShape.control)
            .overlay {
                switch prominence {
                case .primary:
                    // A faint top highlight gives the amber fill some depth.
                    TMIShape.control.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                case .secondary:
                    TMIShape.control.strokeBorder(TMIColors.separator, lineWidth: 1 / max(displayScale, 1))
                case .tertiary, .destructive:
                    EmptyView()
                }
            }
            .contentShape(TMIShape.control)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(TMIAnimation.snappy, value: configuration.isPressed)
            .animation(TMIAnimation.snappy, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var horizontalPadding: CGFloat {
#if os(macOS)
        prominence == .tertiary ? 6 : 14
#else
        prominence == .tertiary ? 8 : 20
#endif
    }

    private var foreground: Color {
        switch prominence {
        case .primary: TMIColors.onBrand
        case .secondary: TMIColors.textPrimary
        case .tertiary: TMIColors.accent
        case .destructive: TMIColors.errorText
        }
    }

    private var background: AnyShapeStyle {
        let pressed = configuration.isPressed
        switch prominence {
        case .primary:
            return AnyShapeStyle(TMIColors.brand.opacity(pressed ? 0.82 : (isHovered ? 0.92 : 1)))
        case .secondary:
            return AnyShapeStyle(pressed || isHovered ? TMIColors.fillStrong : TMIColors.fill)
        case .tertiary:
            return AnyShapeStyle(pressed || isHovered ? TMIColors.accentSoft : Color.clear)
        case .destructive:
            return AnyShapeStyle(TMIColors.errorSurface.opacity(pressed ? 0.7 : 1))
        }
    }
}

extension ButtonStyle where Self == TMIActionButtonStyle {
    static var tmiPrimary: TMIActionButtonStyle { TMIActionButtonStyle(prominence: .primary) }
    static var tmiSecondary: TMIActionButtonStyle { TMIActionButtonStyle(prominence: .secondary) }
    static var tmiTertiary: TMIActionButtonStyle { TMIActionButtonStyle(prominence: .tertiary) }
    static var tmiDestructive: TMIActionButtonStyle { TMIActionButtonStyle(prominence: .destructive) }

    static func tmi(_ prominence: TMIButtonProminence, fullWidth: Bool = false) -> TMIActionButtonStyle {
        TMIActionButtonStyle(prominence: prominence, fullWidth: fullWidth)
    }
}

/// Press (and on Mac, hover) feedback for tappable cards and rows.
struct TMIPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TMIPressableBody(configuration: configuration)
    }
}

private struct TMIPressableBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .brightness(isHovered && !configuration.isPressed ? -0.015 : 0)
            .animation(TMIAnimation.snappy, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

extension ButtonStyle where Self == TMIPressableStyle {
    static var tmiPressable: TMIPressableStyle { TMIPressableStyle() }
}

// MARK: - Status badge

/// A compact status pill: dot (or symbol) plus label, tinted by tone.
struct TMIStatusBadge: View {
    let title: String
    var tone: TMITone = .neutral
    var systemImage: String?

    init(_ title: String, tone: TMITone = .neutral, systemImage: String? = nil) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .fontWeight(.bold)
            } else {
                Circle()
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tone.surface, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Icon tile

/// A rounded, tinted square holding an SF Symbol. Leading element for rows.
struct TMIIconTile: View {
    let systemImage: String
    var tone: TMITone = .brand
    @ScaledMetric private var side: CGFloat

    init(_ systemImage: String, tone: TMITone = .brand, size: CGFloat = 32) {
        self.systemImage = systemImage
        self.tone = tone
        _side = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: side * 0.46, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tone.text)
            .frame(width: side, height: side)
            .background(tone.surface, in: RoundedRectangle(cornerRadius: side * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Section header

/// A screen section title with optional subtitle and trailing accessory.
struct TMISectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TMISpacing.ms) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tmiHeading2)
                    .foregroundStyle(TMIColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                }
            }
            Spacer(minLength: TMISpacing.ms)
            trailing
        }
    }
}

extension TMISectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

extension TMISectionHeader where Trailing == Button<Text> {
    /// A header with a trailing text action such as "See All".
    init(_ title: String, subtitle: String? = nil, actionTitle: String, action: @escaping () -> Void) {
        self.init(title, subtitle: subtitle) {
            Button(actionTitle, action: action)
        }
    }
}

// MARK: - Metrics

/// A KPI tile: label, tabular value, optional delta, sparkline and caption.
struct TMIMetricTile: View {
    let title: String
    let value: String
    var delta: String?
    var deltaTone: TMITone = .success
    var caption: String?
    var trend: [Double] = []
    var systemImage: String?

    init(
        _ title: String,
        value: String,
        delta: String? = nil,
        deltaTone: TMITone = .success,
        caption: String? = nil,
        trend: [Double] = [],
        systemImage: String? = nil
    ) {
        self.title = title
        self.value = value
        self.delta = delta
        self.deltaTone = deltaTone
        self.caption = caption
        self.trend = trend
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TMIColors.accent)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TMIColors.textSecondary)
                    .lineLimit(2)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.tmiMetric)
                    .foregroundStyle(TMIColors.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let delta {
                    Text(delta)
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(deltaTone.text)
                }
            }
            if trend.count > 1 {
                TMISparkline(values: trend)
                    .frame(height: 28)
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(TMIColors.textTertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tmiSurface(.raised, padding: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value, delta, caption].compactMap { $0 }.joined(separator: ", "))
    }
}

/// A minimal trend line with a soft area fill and an emphasized endpoint.
struct TMISparkline: View {
    let values: [Double]
    var color: Color = TMIColors.chartPrimary

    var body: some View {
        let points = Array(values.enumerated())
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max((high - low) * 0.15, 0.001)
        Chart(points, id: \.offset) { point in
            AreaMark(
                x: .value("Index", point.offset),
                yStart: .value("Base", low - pad),
                yEnd: .value("Value", point.element)
            )
            .foregroundStyle(
                LinearGradient(colors: [color.opacity(0.22), color.opacity(0)], startPoint: .top, endPoint: .bottom)
            )
            .interpolationMethod(.catmullRom)
            LineMark(x: .value("Index", point.offset), y: .value("Value", point.element))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            if point.offset == points.count - 1 {
                PointMark(x: .value("Index", point.offset), y: .value("Value", point.element))
                    .foregroundStyle(color)
                    .symbolSize(22)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: (low - pad)...(high + pad))
        .accessibilityHidden(true)
    }
}

/// Linear progress on a capsule track.
struct TMIProgressBar: View {
    let value: Double
    var color: Color = TMIColors.chartPrimary
    var height: CGFloat = 6

    var body: some View {
        let clamped = min(max(value, 0), 1)
        Capsule()
            .fill(TMIColors.chartTrack)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: max(proxy.size.width * clamped, clamped > 0 ? height : 0))
                }
            }
            .clipShape(Capsule())
            .animation(TMIAnimation.smooth, value: clamped)
            .accessibilityElement()
            .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - Key/value

/// A label/value pair for detail panes and inspectors.
struct TMIKeyValueRow: View {
    let label: String
    let value: String
    var systemImage: String?

    init(_ label: String, value: String, systemImage: String? = nil) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(TMIColors.textPrimary)
                .multilineTextAlignment(.trailing)
        } label: {
            if let systemImage {
                Label(label, systemImage: systemImage)
                    .foregroundStyle(TMIColors.textSecondary)
            } else {
                Text(label)
                    .foregroundStyle(TMIColors.textSecondary)
            }
        }
        .font(.subheadline)
    }
}

// MARK: - Golden Hour (brand moments only)

/// The Golden Hour mesh gradient. Reserved for sign-in, the next best step,
/// Student Mode's welcome and completion moments. Never behind dense content.
struct TMIGoldenHourBackground: View {
    var animated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if animated && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                mesh(phase: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            mesh(phase: 0)
        }
    }

    private func mesh(phase: Double) -> some View {
        let drift = Float(sin(phase / 5.0)) * 0.05
        let lift = Float(cos(phase / 7.0)) * 0.04
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5 + drift, 0], [1, 0],
                [0, 0.5 - lift], [0.52 + drift, 0.48 + lift], [1, 0.5 + lift],
                [0, 1], [0.5 - drift, 1], [1, 1],
            ],
            colors: TMIColors.goldenHourStops,
            smoothsColors: true
        )
    }
}

/// A container that sets content on the Golden Hour gradient.
struct TMIGoldenHourCard<Content: View>: View {
    var animated: Bool = false
    let content: Content

    @Environment(\.displayScale) private var displayScale

    init(animated: Bool = false, @ViewBuilder content: () -> Content) {
        self.animated = animated
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TMIRadius.card + 4, style: .continuous)
        content
            .foregroundStyle(TMIColors.goldenHourText)
            .padding(TMISpacing.ml)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { TMIGoldenHourBackground(animated: animated) }
            .clipShape(shape)
            .overlay { shape.strokeBorder(TMIColors.separator, lineWidth: 1 / max(displayScale, 1)) }
    }
}

// MARK: - Brand mark

/// The schoolhouse from the app icon, drawn as a vector so it stays crisp and
/// tintable at every size. Windows and door are cut out (even-odd fill).
nonisolated struct TMISchoolhouseShape: Shape {
    var includesFlag: Bool = true

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        let origin = CGPoint(
            x: rect.midX - 50 * scale,
            y: rect.midY - 50 * scale
        )
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: origin.x + x * scale, y: origin.y + y * scale, width: w * scale, height: h * scale)
        }

        var path = Path()
        // Roof
        path.move(to: p(10, 50))
        path.addLine(to: p(50, 38.5))
        path.addLine(to: p(90, 50))
        path.addLine(to: p(90, 52))
        path.addLine(to: p(10, 52))
        path.closeSubpath()
        // Body
        path.addRect(r(17, 53.5, 66, 24.5))
        // Windows (cut out)
        for index in 0..<5 {
            path.addRect(r(21 + CGFloat(index) * 12.25, 57.5, 8, 3.6))
        }
        // Door (cut out)
        path.addRect(r(45, 65, 10, 13))
        // Plinth
        path.addRoundedRect(in: r(10, 79, 80, 3.2), cornerSize: CGSize(width: 0.8 * scale, height: 0.8 * scale))

        if includesFlag {
            // Pole
            path.addRect(r(48.9, 14, 1.9, 25))
            // Pennant with a slight wave
            path.move(to: p(50.8, 15))
            path.addCurve(to: p(70, 15.5), control1: p(57, 13), control2: p(63, 18))
            path.addLine(to: p(69, 25.5))
            path.addCurve(to: p(50.8, 26.5), control1: p(62, 28.5), control2: p(56, 24))
            path.closeSubpath()
        }
        return path
    }
}

/// The schoolhouse mark in brand amber, optionally on the icon's charcoal tile.
struct TMISchoolhouseMark: View {
    var size: CGFloat = 64
    var onTile: Bool = false

    var body: some View {
        if onTile {
            TMISchoolhouseShape()
                .fill(Color(light: 0xF6AB24, dark: 0xF6AB24), style: FillStyle(eoFill: true))
                .padding(size * 0.12)
                .frame(width: size, height: size)
                .background(
                    Color(light: 0x2F2D2C, dark: 0x2F2D2C),
                    in: RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                )
                .accessibilityHidden(true)
        } else {
            TMISchoolhouseShape()
                .fill(TMIColors.brand, style: FillStyle(eoFill: true))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Avatar palette

nonisolated struct TMIAvatarColors: Sendable {
    let background: Color
    let foreground: Color

    static let palette: [TMIAvatarColors] = [
        TMIAvatarColors(background: Color(light: 0xFCEBCB, dark: 0x4A3512), foreground: Color(light: 0x7A4B00, dark: 0xF7C774)),
        TMIAvatarColors(background: Color(light: 0xFDE2D6, dark: 0x4A2A1E), foreground: Color(light: 0x8A3A17, dark: 0xF9B79A)),
        TMIAvatarColors(background: Color(light: 0xFBE0E8, dark: 0x4A2230), foreground: Color(light: 0x8E2447, dark: 0xF4A5C0)),
        TMIAvatarColors(background: Color(light: 0xF1E2F3, dark: 0x3E2442), foreground: Color(light: 0x6B2C73, dark: 0xDDB0E6)),
        TMIAvatarColors(background: Color(light: 0xE6E6FB, dark: 0x2C2B4D), foreground: Color(light: 0x3E3A9E, dark: 0xB9B6F5)),
        TMIAvatarColors(background: Color(light: 0xDFF0FA, dark: 0x1D3442), foreground: Color(light: 0x155E86, dark: 0x9DD3F2)),
        TMIAvatarColors(background: Color(light: 0xDDF3EE, dark: 0x183A36), foreground: Color(light: 0x0F665E, dark: 0x8BE0D2)),
        TMIAvatarColors(background: Color(light: 0xE7F1DB, dark: 0x2A3620), foreground: Color(light: 0x3F6212, dark: 0xBFDB98)),
    ]

    /// A stable color pair for a name or identifier (same input, same color, every launch).
    static func forKey(_ key: String) -> TMIAvatarColors {
        var hash: UInt32 = 2_166_136_261
        for byte in key.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return palette[Int(hash % UInt32(palette.count))]
    }
}

// MARK: - Sheet sizing

extension View {
    /// Sizes a sheet on the Mac only. On iPhone a minimum width wider than
    /// the screen clips the sheet, so iOS keeps the system sizing.
    @ViewBuilder
    func tmiMacSheetFrame(
        minWidth: CGFloat,
        idealWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil
    ) -> some View {
#if os(macOS)
        frame(minWidth: minWidth, idealWidth: idealWidth, minHeight: minHeight, idealHeight: idealHeight)
#else
        self
#endif
    }
}
