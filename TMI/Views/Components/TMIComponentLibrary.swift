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
  case error
  case form

  var cornerRadius: CGFloat {
    switch self {
    case .default, .dashboard, .error: return 20
    case .elevated: return 24
    case .minimal, .form: return 16
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
    case .error: return EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
    case .form: return EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
    }
  }

  var backgroundOpacity: Double {
    switch self {
    case .default: return 0.05
    case .elevated: return 0.08
    case .minimal: return 0.03
    case .auth: return 0.05
    case .dashboard: return 0.03
    case .error: return 0.13
    case .form: return 0.06
    }
  }

  var materialOpacity: Double {
    switch self {
    case .default: return 0.7
    case .elevated: return 0.9
    case .minimal: return 0.3
    case .auth: return 0.7
    case .dashboard: return 0.8
    case .error: return 0.8
    case .form: return 0.45
    }
  }

  var hasBorder: Bool {
    switch self {
    case .minimal: return false
    case .error, .form: return true
    default: return true
    }
  }

  var shadowRadius: CGFloat {
    switch self {
    case .elevated: return 20
    case .minimal: return 5
    case .error: return 18
    case .form: return 10
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
    let _ = xPercent > 0.5 ? 1.0 : -1.0
    let _ = yPercent > 0.5 ? 1.0 : -1.0

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


// MARK: - Logo View
struct TMILogoView: View {
  @State private var isAnimating = false

  var body: some View {
    VStack(spacing: 5) {
      ZStack {
        // Glowing background
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.7), Color.clear]),
              center: .center,
              startRadius: 1,
              endRadius: 60
            )
          )
          .frame(width: 120, height: 120)
          .scaleEffect(isAnimating ? 1.1 : 0.9)
          .opacity(isAnimating ? 0.7 : 0.5)
          .blur(radius: 10)
          .animation(
            Animation.easeInOut(duration: 2)
              .repeatForever(autoreverses: true),
            value: isAnimating
          )

        // Main logo
        Image(systemName: "brain.head.profile")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 70, height: 70)
          .foregroundColor(.white)
          .shadow(color: Color.tmiSecondary.opacity(0.8), radius: 10, x: 0, y: 0)
          .rotationEffect(Angle(degrees: isAnimating ? 5 : 0))
          .animation(
            Animation.easeInOut(duration: 3)
              .repeatForever(autoreverses: true),
            value: isAnimating
          )
      }
      .padding(.bottom, 10)

      Text("TMI")
        .font(.system(size: 36, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
    }
    .onAppear {
      isAnimating = true
    }
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
      case .filter: return 24
      case .icon: return 12
      default: return 14
      }
    }

    var height: CGFloat {
      switch self {
      case .floating: return 60
      case .filter: return 48
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
      .padding(.horizontal, {
        switch style {
        case .filter: return 20
        case .floating, .icon: return 16
        default: return 24
        }
      }())
      .foregroundColor(style.foregroundColor)
      .frame(
        minWidth: {
          switch style {
          case .floating: return style.height
          case .filter: return 80 // Minimum width for filter buttons
          default: return nil
          }
        }(),
        maxWidth: {
          switch style {
          case .floating, .icon, .filter: return nil
          default: return .infinity
          }
        }()
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
      TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.auth)
        .frame(height: 200)
        .overlay(Text("Auth Background").foregroundColor(.white))

      TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.dashboard)
        .frame(height: 200)
        .overlay(Text("Dashboard Background").foregroundColor(.white))
    }
  }

  #Preview("TMI Glass Cards") {
    ZStack {
      TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.dashboard)

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
      TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.dashboard)

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
