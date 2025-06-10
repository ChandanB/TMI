//
//  TMIComponentLibrary.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import Charts
import Combine
import SpriteKit
import SwiftUI

// MARK: - Component Library Overview
/*
 This file serves as the single source of truth for all reusable UI components
 in the TMI app. It consolidates duplicate components from across the codebase
 into a unified, consistent library.

 Component Categories:
 - Foundation: Background, Glass Card, Particles
 - Buttons: Primary, Secondary, Floating, Filter
 - Cards: Stat, Content, Selection, List
 - Navigation: Tab Bar, Sidebar, Headers
 - Forms: Text Fields, Search, Filters
 */

// MARK: - Foundation Components (Phase 1)

/// Unified animated background component
/// Replaces: DynamicBackgroundView, DashboardBackgroundView, BackgroundAnimationView
struct TMIBackgroundView: View {
  var variant: BackgroundVariant = .default
  var customColors: [Color] = []

  @State private var animateGradient = false
  @State private var animateParticles = false

  enum BackgroundVariant {
    case `default`
    case auth
    case dashboard
    case career
    case plans

    var colors: [Color] {
      switch self {
      case .default, .dashboard:
        return [
          Color(red: 0.08, green: 0.08, blue: 0.15),
          Color(red: 0.14, green: 0.14, blue: 0.25),
        ]
      case .auth:
        return [
          Color(red: 0.05, green: 0.05, blue: 0.15),
          Color(red: 0.1, green: 0.1, blue: 0.3),
        ]
      case .career:
        return [
          Color.tmiBackground,
          Color.tmiPrimary.opacity(0.1),
          Color.tmiBackground,
        ]
      case .plans:
        return [
          Color(red: 0.08, green: 0.08, blue: 0.15),
          Color(red: 0.14, green: 0.14, blue: 0.25),
        ]
      }
    }

    var includeParticles: Bool {
      switch self {
      case .auth, .dashboard: return true
      default: return false
      }
    }
  }

  var body: some View {
    ZStack {
      // Base gradient
      LinearGradient(
        gradient: Gradient(colors: customColors.isEmpty ? variant.colors : customColors),
        startPoint: variant == .career ? .topLeading : .top,
        endPoint: variant == .career ? .bottomTrailing : .bottom
      )
      .ignoresSafeArea()

      // Animated overlays
      animatedOverlays

      // Particle effect (conditional)
      if variant.includeParticles {
        TMIParticleEffect()
          .opacity(0.3)
      }
    }
    .onAppear {
      animateGradient = true
      animateParticles = true
    }
  }

  @ViewBuilder
  private var animatedOverlays: some View {
    // Primary blob
    Circle()
      .fill(Color.tmiPrimary.opacity(0.15))
      .frame(width: 400, height: 400)
      .blur(radius: 80)
      .offset(x: -150, y: animateGradient ? -200 : -250)
      .animation(
        Animation.easeInOut(duration: 10)
          .repeatForever(autoreverses: true),
        value: animateGradient
      )

    // Secondary blob
    Circle()
      .fill(Color.tmiSecondary.opacity(0.15))
      .frame(width: 300, height: 300)
      .blur(radius: 70)
      .offset(x: 170, y: animateGradient ? 200 : 300)
      .animation(
        Animation.easeInOut(duration: 8)
          .repeatForever(autoreverses: true),
        value: animateGradient
      )

    // Additional variant-specific overlays
    if variant == .career {
      additionalCareerOverlays
    }
  }

  @ViewBuilder
  private var additionalCareerOverlays: some View {
    // Additional animated particles for career view
    ForEach(0..<5, id: \.self) { i in
      Circle()
        .fill(Color.tmiSecondary.opacity(0.2))
        .frame(width: CGFloat.random(in: 5...15))
        .offset(
          x: CGFloat.random(in: -80...80),
          y: CGFloat.random(in: -40...20)
        )
        .opacity(animateParticles ? 1 : 0)
        .animation(
          Animation.easeInOut(duration: Double.random(in: 2...4))
            .repeatForever(autoreverses: true)
            .delay(Double.random(in: 0...2)),
          value: animateParticles
        )
    }
  }
}

/// Glass card style options (moved outside generic type for better compatibility)
enum TMIGlassCardStyle {
  case `default`
  case elevated
  case minimal
  case auth
  case dashboard

  var cornerRadius: CGFloat {
    switch self {
    case .default, .dashboard: return 20
    case .elevated: return 24
    case .minimal: return 16
    case .auth: return 20
    }
  }

  var padding: EdgeInsets {
    switch self {
    case .default: return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    case .elevated: return EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
    case .minimal: return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    case .auth: return EdgeInsets(top: 30, leading: 24, bottom: 30, trailing: 24)
    case .dashboard: return EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    }
  }

  var backgroundOpacity: Double {
    switch self {
    case .default: return 0.05
    case .elevated: return 0.08
    case .minimal: return 0.03
    case .auth: return 0.05
    case .dashboard: return 0.03
    }
  }

  var materialOpacity: Double {
    switch self {
    case .default: return 0.7
    case .elevated: return 0.9
    case .minimal: return 0.3
    case .auth: return 0.7
    case .dashboard: return 0.8
    }
  }

  var hasBorder: Bool {
    switch self {
    case .minimal: return false
    default: return true
    }
  }

  var shadowRadius: CGFloat {
    switch self {
    case .elevated: return 20
    case .minimal: return 5
    default: return 15
    }
  }
}

/// Unified glass morphism card component
/// Replaces: GlassCard, DashboardGlassCard, various card backgrounds
struct TMIGlassCard<Content: View>: View {
  let content: Content
  var style: TMIGlassCardStyle = .default
  var customPadding: EdgeInsets?
  var customCornerRadius: CGFloat?

  @State private var isHovered = false

  init(
    style: TMIGlassCardStyle = .default,
    customPadding: EdgeInsets? = nil,
    customCornerRadius: CGFloat? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.content = content()
    self.style = style
    self.customPadding = customPadding
    self.customCornerRadius = customCornerRadius
  }

  var body: some View {
    content
      .padding(customPadding ?? style.padding)
      .background(
        GeometryReader { geometry in
          RoundedRectangle(cornerRadius: customCornerRadius ?? style.cornerRadius)
            .fill(Color.white.opacity(style.backgroundOpacity))
            .background(
              RoundedRectangle(cornerRadius: customCornerRadius ?? style.cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(style.materialOpacity)
            )
            .shadow(
              color: Color.black.opacity(0.15),
              radius: style.shadowRadius,
              x: shadowOffset(for: geometry).x,
              y: shadowOffset(for: geometry).y
            )
            .overlay(
              style.hasBorder
                ? RoundedRectangle(cornerRadius: customCornerRadius ?? style.cornerRadius)
                  .stroke(
                    positionBasedGradient(for: geometry),
                    lineWidth: 1
                  ) : nil
            )
        }
      )
      .scaleEffect(isHovered ? 1.01 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .onHover { hovering in
        isHovered = hovering
      }
  }

  // MARK: - Position-Based Lighting Calculations

  private func positionBasedGradient(for geometry: GeometryProxy) -> LinearGradient {
    // Get the center point of this view in global coordinates
    let globalFrame = geometry.frame(in: .global)
    let viewCenter = CGPoint(
      x: globalFrame.midX,
      y: globalFrame.midY
    )

    // Get screen dimensions
    let screenSize = UIScreen.main.bounds.size
    let screenCenter = CGPoint(
      x: screenSize.width / 2,
      y: screenSize.height / 2
    )

    // Calculate position as normalized percentages (0.0 to 1.0)
    let xPercent = viewCenter.x / screenSize.width
    let yPercent = viewCenter.y / screenSize.height

    // Create dramatic directional variations based on screen quadrants
    let quadrantX = xPercent > 0.5 ? 1.0 : -1.0
    let quadrantY = yPercent > 0.5 ? 1.0 : -1.0

    // More dramatic light source positioning based on quadrants
    let lightSourceMultiplier: CGFloat = 0.6  // Increased from 0.2-0.3
    let lightSourceOffset = CGPoint(
      x: -screenSize.width * lightSourceMultiplier * quadrantX,
      y: -screenSize.height * lightSourceMultiplier * quadrantY
    )

    let lightSource = CGPoint(
      x: screenCenter.x + lightSourceOffset.x,
      y: screenCenter.y + lightSourceOffset.y
    )

    // Calculate vector from light source to view center
    let lightVector = CGPoint(
      x: viewCenter.x - lightSource.x,
      y: viewCenter.y - lightSource.y
    )

    // Normalize the vector and calculate gradient direction
    let distance = sqrt(lightVector.x * lightVector.x + lightVector.y * lightVector.y)
    let normalizedX = lightVector.x / distance
    let normalizedY = lightVector.y / distance

    // Dramatically increase gradient range based on position
    let gradientIntensity: CGFloat = 0.8  // Increased from 0.5
    let positionVariation = abs(xPercent - 0.5) + abs(yPercent - 0.5)  // 0.0 to 1.0
    let finalIntensity = gradientIntensity * (0.5 + positionVariation)

    let startPoint = UnitPoint(
      x: 0.5 - normalizedX * finalIntensity,
      y: 0.5 - normalizedY * finalIntensity
    )
    let endPoint = UnitPoint(
      x: 0.5 + normalizedX * finalIntensity,
      y: 0.5 + normalizedY * finalIntensity
    )

    // Calculate dramatic opacity variations
    let distanceFromCenter = sqrt(
      pow(viewCenter.x - screenCenter.x, 2) + pow(viewCenter.y - screenCenter.y, 2)
    )
    let maxDistance = sqrt(pow(screenSize.width / 2, 2) + pow(screenSize.height / 2, 2))
    let centerProximity = 1.0 - min(distanceFromCenter / maxDistance, 1.0)

    // Create more dramatic opacity ranges
    let minOpacity: Double = 0.1
    let maxOpacity: Double = 0.9
    let baseOpacity = minOpacity + (centerProximity * (maxOpacity - minOpacity))

    // Add position-based intensity variations
    let positionMultiplier = 0.5 + (positionVariation * 1.0)  // 0.5 to 1.5
    let adjustedOpacity = baseOpacity * positionMultiplier

    let highlightOpacity = isHovered ? min(adjustedOpacity * 1.4, 1.0) : adjustedOpacity
    let midOpacity = highlightOpacity * 0.4
    let shadowOpacity = highlightOpacity * 0.1

    // Add subtle color tinting based on position for more distinction
    let redTint = 1.0 + (xPercent - 0.5) * 0.1  // Subtle red variation
    let blueTint = 1.0 + (yPercent - 0.5) * 0.1  // Subtle blue variation
    let greenTint = 1.0 + ((1.0 - centerProximity) * 0.1)  // Green for edge cards

    return LinearGradient(
      colors: [
        Color(
          red: min(redTint * highlightOpacity, 1.0),
          green: min(greenTint * highlightOpacity, 1.0),
          blue: min(blueTint * highlightOpacity, 1.0)
        ),
        Color.white.opacity(midOpacity),
        Color.white.opacity(shadowOpacity),
        Color.white.opacity(shadowOpacity * 0.3),
      ],
      startPoint: startPoint,
      endPoint: endPoint
    )
  }

  private func shadowOffset(for geometry: GeometryProxy) -> CGPoint {
    // Calculate dynamic shadow offset based on position
    let globalFrame = geometry.frame(in: .global)
    let screenSize = UIScreen.main.bounds.size

    // Calculate position as percentage of screen
    let xPercent = globalFrame.midX / screenSize.width
    let yPercent = globalFrame.midY / screenSize.height

    // Create dramatic shadow offset variations
    let baseOffset = style == .elevated ? 12.0 : 10.0

    // More dramatic position-based offsets
    let xOffset = (xPercent - 0.5) * 2.0  // Range: -1 to 1
    let yOffset = (yPercent - 0.5) * 2.0  // Range: -1 to 1

    // Quadrant-based shadow intensity
    let quadrantX = xPercent > 0.5 ? 1.0 : -1.0
    let quadrantY = yPercent > 0.5 ? 1.0 : -1.0

    // Distance from center affects shadow strength
    let centerX = abs(xPercent - 0.5) * 2.0  // 0 to 1
    let centerY = abs(yPercent - 0.5) * 2.0  // 0 to 1
    let edgeProximity = (centerX + centerY) / 2.0  // How close to edge

    // More dramatic shadow positioning
    let dramaticXOffset = xOffset * (8.0 + edgeProximity * 6.0)  // 8-14 pixel range
    let dramaticYOffset = baseOffset + (yOffset * (4.0 + edgeProximity * 8.0))  // More vertical variation

    return CGPoint(
      x: dramaticXOffset,
      y: dramaticYOffset
    )
  }
}

/// Reusable particle effect component
/// Replaces: ParticleEffect implementations across files
struct TMIParticleEffect: View {
  var particleCount: Int = 40
  var particleSize: ClosedRange<CGFloat> = 1...3
  var particleOpacity: ClosedRange<Double> = 0.1...0.3
  var particleSpeed: ClosedRange<Double> = 0.2...0.6

  @State private var particles: [Particle] = []

  struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: Double
  }

  var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        // Update particle positions
        for index in particles.indices {
          particles[index].position.y -= particles[index].speed
          particles[index].opacity -= 0.003

          if particles[index].position.y < 0 || particles[index].opacity <= 0 {
            particles[index] = createParticle(size: size)
          }
        }

        // Draw particles
        for particle in particles {
          let rect = CGRect(
            x: particle.position.x,
            y: particle.position.y,
            width: particle.size,
            height: particle.size
          )

          context.opacity = particle.opacity
          context.fill(Path(ellipseIn: rect), with: .color(.white))
        }
      }
    }
    .onAppear {
      initializeParticles()
    }
  }

  private func initializeParticles() {
    particles = []
    for _ in 0..<particleCount {
      particles.append(
        createParticle(
          size: CGSize(
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
          )
        )
      )
    }
  }

  private func createParticle(size: CGSize) -> Particle {
    Particle(
      position: CGPoint(
        x: CGFloat.random(in: 0...size.width),
        y: CGFloat.random(in: 0...size.height)
      ),
      size: CGFloat.random(in: particleSize),
      opacity: Double.random(in: particleOpacity),
      speed: Double.random(in: particleSpeed)
    )
  }
}

// MARK: - Button Components (Phase 2)

/// Unified button component with multiple styles
/// Replaces: TMIButton, CustomButton, FloatingActionButton, various button implementations
struct TMIButton: View {
  let text: String
  let icon: String?
  let style: TMIButtonStyle
  let isLoading: Bool
  let isDisabled: Bool
  let action: () -> Void

  @State private var isPressed = false
  @State private var isHovered = false

  enum TMIButtonStyle: Equatable {
    case primary
    case secondary
    case tertiary
    case destructive
    case floating
    case filter(isSelected: Bool = false)
    case icon

    static func == (lhs: TMIButtonStyle, rhs: TMIButtonStyle) -> Bool {
      switch (lhs, rhs) {
      case (.primary, .primary),
        (.secondary, .secondary),
        (.tertiary, .tertiary),
        (.destructive, .destructive),
        (.floating, .floating),
        (.icon, .icon):
        return true
      case (.filter(let lhsSelected), .filter(let rhsSelected)):
        return lhsSelected == rhsSelected
      default:
        return false
      }
    }

    var foregroundColor: Color {
      switch self {
      case .primary, .floating: return .white
      case .secondary, .tertiary: return .tmiSecondary
      case .destructive: return .white
      case .filter(let isSelected): return isSelected ? .white : .white.opacity(0.8)
      case .icon: return .white.opacity(0.7)
      }
    }

    var backgroundColor: Color {
      switch self {
      case .primary: return .tmiSecondary
      case .secondary: return .clear
      case .tertiary: return .white.opacity(0.1)
      case .destructive: return .red
      case .floating: return .tmiSecondary
      case .filter(let isSelected): return isSelected ? .tmiSecondary : .white.opacity(0.05)
      case .icon: return .white.opacity(0.1)
      }
    }

    var borderColor: Color? {
      switch self {
      case .secondary: return .tmiSecondary
      case .filter(let isSelected): return isSelected ? .clear : .white.opacity(0.3)
      default: return nil
      }
    }

    var cornerRadius: CGFloat {
      switch self {
      case .floating: return 30
      case .filter: return 14
      case .icon: return 12
      default: return 14
      }
    }

    var height: CGFloat {
      switch self {
      case .floating: return 60
      case .filter: return 40
      case .icon: return 44
      default: return 56
      }
    }

    var shadowColor: Color {
      switch self {
      case .primary, .floating: return backgroundColor.opacity(0.3)
      case .destructive: return .red.opacity(0.3)
      default: return .clear
      }
    }
  }

  init(
    text: String,
    icon: String? = nil,
    style: TMIButtonStyle = .primary,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    action: @escaping () -> Void
  ) {
    self.text = text
    self.icon = icon
    self.style = style
    self.isLoading = isLoading
    self.isDisabled = isDisabled
    self.action = action
  }

  var body: some View {
    Button(action: handleTap) {
      HStack(spacing: 12) {
        if isLoading {
          ProgressView()
            .progressViewStyle(
              CircularProgressViewStyle(
                tint: style.foregroundColor
              )
            )
        } else {
          if let icon = icon {
            Image(systemName: icon)
              .font(.system(size: 18, weight: .medium))
          }

          if style != .icon {
            Text(text)
              .font(.system(size: 17, weight: .semibold))
          }
        }
      }
      .foregroundColor(style.foregroundColor)
      .frame(
        minWidth: style == .floating ? style.height : nil,
        maxWidth: style == .floating || style == .icon ? nil : .infinity
      )
      .frame(height: style.height)
      .background(
        RoundedRectangle(cornerRadius: style.cornerRadius)
          .fill(style.backgroundColor)
          .overlay(
            style.borderColor != nil
              ? RoundedRectangle(cornerRadius: style.cornerRadius)
                .stroke(style.borderColor!, lineWidth: 1.5) : nil
          )
      )
      .shadow(
        color: style.shadowColor,
        radius: isHovered ? 12 : 8,
        x: 0,
        y: isHovered ? 8 : 5
      )
      .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
      .animation(.easeInOut(duration: 0.2), value: isPressed)
    }
    .buttonStyle(.plain)
    .disabled(isLoading || isDisabled)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  private func handleTap() {
    withAnimation(.easeInOut(duration: 0.1)) {
      isPressed = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation(.easeInOut(duration: 0.1)) {
        isPressed = false
      }
      action()
    }
  }
}

// MARK: - Text Input Components

/// Unified text field component
/// Replaces: TMITextField implementations
struct TMITextField: View {
  let icon: String
  let placeholder: String
  @Binding var text: String
  var isSecure: Bool = false
  var keyboardType: UIKeyboardType = .default
  var onSubmit: (() -> Void)? = nil

  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(isFocused ? Color.tmiSecondary : .white.opacity(0.6))
        .frame(width: 20)
        .animation(.easeOut(duration: 0.2), value: isFocused)

      Group {
        if isSecure {
          SecureField(
            "", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
        } else {
          TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
        }
      }
      .focused($isFocused)
      .foregroundColor(.white)
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)
      .keyboardType(keyboardType)
      .submitLabel(isSecure ? .done : .next)
      .onSubmit {
        onSubmit?()
      }
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.3))
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .opacity(0.2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          isFocused
            ? LinearGradient(
              colors: [Color.tmiSecondary.opacity(0.8)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
            : LinearGradient(
              colors: [.white.opacity(0.3), .clear],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
          lineWidth: 1
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    )
  }
}

// MARK: - Progress Components

/// Unified progress view style
/// Replaces: GlowingProgressViewStyle, various progress implementations
struct TMIProgressViewStyle: ProgressViewStyle {
  var color: Color = .tmiSecondary
  var height: CGFloat = 4
  var cornerRadius: CGFloat = 10

  func makeBody(configuration: Configuration) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(0.1))
          .frame(height: height)

        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(
            LinearGradient(
              colors: [color, color.opacity(0.8)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(
            width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
            height: height
          )
          .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
      }
    }
    .frame(height: height)
  }
}

// MARK: - Animation and Transition Helpers

/// Standard button scale effect
struct ScaleButtonStyle: ButtonStyle {
  var scaleAmount: CGFloat = 0.95

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
      .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
  }
}

// MARK: - Extensions for View Modifiers

extension View {
  /// Apply TMI glass card styling
  func tmiGlassCard(style: TMIGlassCardStyle = .default) -> some View {
    TMIGlassCard(style: style) {
      self
    }
  }

  /// Apply TMI progress view styling
  func tmiProgressStyle(color: Color = .tmiSecondary, height: CGFloat = 4) -> some View {
    self.progressViewStyle(TMIProgressViewStyle(color: color, height: height))
  }

  /// Apply scale button effect
  func tmiScaleButton(scaleAmount: CGFloat = 0.95) -> some View {
    self.buttonStyle(ScaleButtonStyle(scaleAmount: scaleAmount))
  }
}

// MARK: - Preview Helpers

#if DEBUG
  #Preview("TMI Background Variants") {
    VStack {
      TMIBackgroundView(variant: .auth)
        .frame(height: 200)
        .overlay(Text("Auth Background").foregroundColor(.white))

      TMIBackgroundView(variant: .dashboard)
        .frame(height: 200)
        .overlay(Text("Dashboard Background").foregroundColor(.white))
    }
  }

  #Preview("TMI Glass Cards") {
    ZStack {
      TMIBackgroundView(variant: .dashboard)

      VStack(spacing: 20) {
        TMIGlassCard(style: .default) {
          Text("Default Glass Card")
            .foregroundColor(.white)
            .padding()
        }

        TMIGlassCard(style: .elevated) {
          Text("Elevated Glass Card")
            .foregroundColor(.white)
            .padding()
        }

        TMIGlassCard(style: .minimal) {
          Text("Minimal Glass Card")
            .foregroundColor(.white)
            .padding()
        }
      }
      .padding()
    }
  }

  #Preview("TMI Buttons") {
    ZStack {
      TMIBackgroundView(variant: .dashboard)

      VStack(spacing: 16) {
        TMIButton(text: "Primary Button", style: .primary) {}
        TMIButton(text: "Secondary Button", style: .secondary) {}
        TMIButton(text: "Filter Button", style: .filter()) {}
        TMIButton(text: "Loading", style: .primary, isLoading: true) {}
      }
      .padding()
    }
  }
#endif

// MARK: - Physics-Based Glass Card (SpriteKit Integration)

/// Physics properties for glass cards (moved outside generic type)
struct TMIGlassPhysicsProperties {
  var mass: CGFloat = 1.0
  var friction: CGFloat = 0.3
  var restitution: CGFloat = 0.4  // Bounciness
  var density: CGFloat = 1.0
  var gravityScale: CGFloat = 0.1  // Reduced gravity for glass feel
  var enableCollisions: Bool = true
  var enableGravity: Bool = false  // Start with gravity off
  var glassThickness: CGFloat = 8.0

  static let `default` = TMIGlassPhysicsProperties()

  static let heavy = TMIGlassPhysicsProperties(
    mass: 2.0,
    friction: 0.5,
    restitution: 0.2,
    gravityScale: 0.3
  )

  static let light = TMIGlassPhysicsProperties(
    mass: 0.5,
    friction: 0.1,
    restitution: 0.8,
    gravityScale: 0.05
  )

  static let bouncy = TMIGlassPhysicsProperties(
    mass: 0.8,
    friction: 0.2,
    restitution: 0.9,
    gravityScale: 0.1
  )
}

/// Physics-based glass card using SpriteKit for realistic behavior
struct TMIPhysicsGlassCard<Content: View>: View {
  let content: Content
  var style: TMIGlassCardStyle = .default
  var enablePhysics: Bool = true
  var physicsProperties: TMIGlassPhysicsProperties = .default

  @State private var scene: GlassPhysicsScene?
  @State private var isSetup = false

  init(
    style: TMIGlassCardStyle = .default,
    enablePhysics: Bool = true,
    physicsProperties: TMIGlassPhysicsProperties = .default,
    @ViewBuilder content: () -> Content
  ) {
    self.content = content()
    self.style = style
    self.enablePhysics = enablePhysics
    self.physicsProperties = physicsProperties
  }

  var body: some View {
    ZStack {
      if enablePhysics {
        // SpriteKit physics scene
        SpriteView(scene: scene ?? createScene())
          .allowsHitTesting(true)
          .onAppear {
            if !isSetup {
              setupPhysicsScene()
              isSetup = true
            }
          }
      }

      // Overlay the SwiftUI content
      content
        .allowsHitTesting(!enablePhysics)
        .opacity(enablePhysics ? 0.9 : 1.0)  // Slight transparency when physics enabled
    }
    .gesture(
      enablePhysics
        ? DragGesture()
          .onChanged { value in
            scene?.applyForce(at: value.location, force: value.translation)
          }
          .onEnded { value in
            scene?.applyImpulse(at: value.location, impulse: value.predictedEndTranslation)
          } : nil
    )
    .onTapGesture(count: 2) {
      if enablePhysics {
        scene?.addShakeEffect()
      }
    }
  }

  private func createScene() -> GlassPhysicsScene {
    let newScene = GlassPhysicsScene()
    newScene.physicsProperties = physicsProperties
    newScene.glassStyle = style
    return newScene
  }

  private func setupPhysicsScene() {
    scene = createScene()
  }
}

// MARK: - SpriteKit Physics Scene

class GlassPhysicsScene: SKScene {
  var physicsProperties: TMIGlassPhysicsProperties = .default
  var glassStyle: TMIGlassCardStyle = .default
  var glassNode: SKShapeNode?
  var lightingNodes: [SKLightNode] = []

  override func didMove(to view: SKView) {
    setupPhysicsWorld()
    createGlassCard()
    setupLighting()
    setupMotionEffects()
  }

  private func setupPhysicsWorld() {
    physicsWorld.gravity = CGVector(dx: 0, dy: -9.8 * physicsProperties.gravityScale)
    physicsWorld.speed = 1.0

    // Create invisible boundaries
    let borderBody = SKPhysicsBody(edgeLoopFrom: self.frame)
    borderBody.friction = physicsProperties.friction
    borderBody.restitution = physicsProperties.restitution
    physicsBody = borderBody
  }

  private func createGlassCard() {
    // Create the main glass shape
    let cardSize = CGSize(width: 300, height: 200)  // Default size
    let cornerRadius = glassStyle.cornerRadius

    // Create rounded rectangle path
    let path = UIBezierPath(
      roundedRect: CGRect(
        origin: CGPoint(x: -cardSize.width / 2, y: -cardSize.height / 2),
        size: cardSize),
      cornerRadius: cornerRadius)

    glassNode = SKShapeNode(path: path.cgPath)

    guard let glass = glassNode else { return }

    // Glass visual properties
    glass.fillColor = SKColor.white.withAlphaComponent(0.1)
    glass.strokeColor = SKColor.white.withAlphaComponent(0.3)
    glass.lineWidth = 2.0
    glass.glowWidth = 4.0

    // Add subtle blur effect to simulate glass
    let blurEffect = SKEffectNode()
    blurEffect.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 2.0])
    blurEffect.addChild(glass)

    // Physics body
    glass.physicsBody = SKPhysicsBody(polygonFrom: path.cgPath)
    glass.physicsBody?.mass = physicsProperties.mass
    glass.physicsBody?.friction = physicsProperties.friction
    glass.physicsBody?.restitution = physicsProperties.restitution
    glass.physicsBody?.density = physicsProperties.density
    glass.physicsBody?.allowsRotation = true
    glass.physicsBody?.isDynamic = true

    // Position at center initially
    glass.position = CGPoint(x: size.width / 2, y: size.height / 2)

    addChild(blurEffect)

    // Add subtle floating animation
    addFloatingEffect(to: glass)
  }

  private func setupLighting() {
    // Primary light source (top-left)
    let primaryLight = SKLightNode()
    primaryLight.categoryBitMask = 1
    primaryLight.lightColor = SKColor.white
    primaryLight.ambientColor = SKColor.white.withAlphaComponent(0.2)
    primaryLight.position = CGPoint(x: size.width * 0.2, y: size.height * 0.8)
    addChild(primaryLight)
    lightingNodes.append(primaryLight)

    // Secondary light source (bottom-right)
    let secondaryLight = SKLightNode()
    secondaryLight.categoryBitMask = 1
    secondaryLight.lightColor = SKColor.blue.withAlphaComponent(0.6)
    secondaryLight.ambientColor = SKColor.blue.withAlphaComponent(0.1)
    secondaryLight.position = CGPoint(x: size.width * 0.8, y: size.height * 0.2)
    addChild(secondaryLight)
    lightingNodes.append(secondaryLight)

    // Note: In a real implementation, you would configure lighting
    // For now, we'll rely on the visual appearance and blur effects
  }

  private func addFloatingEffect(to node: SKNode) {
    let float1 = SKAction.moveBy(x: 0, y: 10, duration: 3.0)
    let float2 = SKAction.moveBy(x: 0, y: -10, duration: 3.0)
    let floatSequence = SKAction.sequence([float1, float2])
    let floatForever = SKAction.repeatForever(floatSequence)

    node.run(floatForever, withKey: "floating")
  }

  // MARK: - Physics Interactions

  func applyForce(at location: CGPoint, force: CGSize) {
    guard let glass = glassNode else { return }

    let forceVector = CGVector(dx: force.width * 0.1, dy: -force.height * 0.1)
    glass.physicsBody?.applyForce(forceVector, at: location)

    // Add visual feedback
    addRippleEffect(at: location)
  }

  func applyImpulse(at location: CGPoint, impulse: CGSize) {
    guard let glass = glassNode else { return }

    let impulseVector = CGVector(dx: impulse.width * 0.05, dy: -impulse.height * 0.05)
    glass.physicsBody?.applyImpulse(impulseVector, at: location)
  }

  func addShakeEffect() {
    guard let glass = glassNode else { return }

    // Stop floating animation temporarily
    glass.removeAction(forKey: "floating")

    // Add shake effect
    let shake = SKAction.sequence([
      SKAction.moveBy(x: -10, y: 0, duration: 0.05),
      SKAction.moveBy(x: 20, y: 0, duration: 0.05),
      SKAction.moveBy(x: -20, y: 0, duration: 0.05),
      SKAction.moveBy(x: 10, y: 0, duration: 0.05),
    ])

    glass.run(shake) { [weak self] in
      // Resume floating
      self?.addFloatingEffect(to: glass)
    }

    // Add glass crack effect temporarily
    addGlassCrackEffect()
  }

  private func addRippleEffect(at location: CGPoint) {
    let ripple = SKShapeNode(circleOfRadius: 5)
    ripple.strokeColor = SKColor.white.withAlphaComponent(0.8)
    ripple.fillColor = SKColor.clear
    ripple.lineWidth = 2.0
    ripple.position = location
    addChild(ripple)

    let expand = SKAction.scale(to: 3.0, duration: 0.5)
    let fadeOut = SKAction.fadeOut(withDuration: 0.5)
    let group = SKAction.group([expand, fadeOut])

    ripple.run(group) {
      ripple.removeFromParent()
    }
  }

  private func addGlassCrackEffect() {
    guard let glass = glassNode else { return }

    // Create temporary crack lines
    for _ in 0..<3 {
      let crack = SKShapeNode()
      let path = CGMutablePath()

      let startPoint = CGPoint(
        x: CGFloat.random(in: -150...150),
        y: CGFloat.random(in: -100...100))
      let endPoint = CGPoint(
        x: startPoint.x + CGFloat.random(in: -50...50),
        y: startPoint.y + CGFloat.random(in: -50...50))

      path.move(to: startPoint)
      path.addLine(to: endPoint)

      crack.path = path
      crack.strokeColor = SKColor.white.withAlphaComponent(0.6)
      crack.lineWidth = 1.0
      glass.addChild(crack)

      // Fade out crack
      let fadeOut = SKAction.fadeOut(withDuration: 1.0)
      crack.run(fadeOut) {
        crack.removeFromParent()
      }
    }
  }

  // MARK: - Motion Effects

  private func setupMotionEffects() {
    // This would integrate with device motion in a real implementation
    // For now, we'll simulate environmental effects

    let environmentalWind = SKAction.sequence([
      SKAction.wait(forDuration: 5.0),
      SKAction.run { [weak self] in
        self?.addWindEffect()
      },
    ])

    run(SKAction.repeatForever(environmentalWind))
  }

  private func addWindEffect() {
    guard let glass = glassNode else { return }

    let windForce = CGVector(
      dx: CGFloat.random(in: -50...50),
      dy: CGFloat.random(in: -20...20))
    glass.physicsBody?.applyForce(windForce)

    // Animate lighting to simulate wind affecting light
    lightingNodes.forEach { light in
      let lightWave = SKAction.sequence([
        SKAction.fadeAlpha(to: 0.5, duration: 1.0),
        SKAction.fadeAlpha(to: 1.0, duration: 1.0),
      ])
      light.run(lightWave)
    }
  }
}

// MARK: - Convenience Initializers

extension TMIPhysicsGlassCard {
  /// Create a heavy glass card that settles with weight
  static func heavy<T: View>(
    style: TMIGlassCardStyle = .default,
    @ViewBuilder content: () -> T
  ) -> TMIPhysicsGlassCard<T> {
    TMIPhysicsGlassCard<T>(
      style: style,
      enablePhysics: true,
      physicsProperties: .heavy,
      content: content
    )
  }

  /// Create a light, floating glass card
  static func floating<T: View>(
    style: TMIGlassCardStyle = .default,
    @ViewBuilder content: () -> T
  ) -> TMIPhysicsGlassCard<T> {
    TMIPhysicsGlassCard<T>(
      style: style,
      enablePhysics: true,
      physicsProperties: .light,
      content: content
    )
  }

  /// Create a bouncy, interactive glass card
  static func bouncy<T: View>(
    style: TMIGlassCardStyle = .default,
    @ViewBuilder content: () -> T
  ) -> TMIPhysicsGlassCard<T> {
    TMIPhysicsGlassCard<T>(
      style: style,
      enablePhysics: true,
      physicsProperties: .bouncy,
      content: content
    )
  }
}
