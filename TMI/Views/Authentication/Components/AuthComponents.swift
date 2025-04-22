//
//  DynamicBackgroundView.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//


// MARK: - Reusable Components
import SwiftUI
import FirebaseAuth

// MARK: - Dynamic Background
struct DynamicBackgroundView: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated overlays
            Circle()
                .fill(Color.tmiPrimary.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: animateGradient ? -150 : -200)
                .animation(
                    Animation.easeInOut(duration: 7)
                        .repeatForever(autoreverses: true)
                        .delay(0.5),
                    value: animateGradient
                )
            
            Circle()
                .fill(Color.tmiSecondary.opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 120, y: animateGradient ? 150 : 200)
                .animation(
                    Animation.easeInOut(duration: 6)
                        .repeatForever(autoreverses: true),
                    value: animateGradient
                )
            
            // Particle effect
            ParticleEffect()
                .opacity(0.4)
        }
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - Particle Effect
struct ParticleEffect: View {
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
                        // Replace particle
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
            // Initialize particles
            for _ in 0..<40 {
                particles.append(createParticle(size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)))
            }
        }
    }
    
    private func createParticle(size: CGSize) -> Particle {
        Particle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ),
            size: CGFloat.random(in: 1...3),
            opacity: Double.random(in: 0.1...0.3),
            speed: Double.random(in: 0.2...0.6)
        )
    }
}

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.vertical, 30)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.7)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Custom Text Field
struct TMITextField: View {
    var icon: String
    var placeholder: String
    var text: Binding<String>
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var onSubmit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @State private var isEditing: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with animation
            Image(systemName: icon)
                .foregroundColor(isFocused ? Color.tmiSecondary : .white.opacity(0.6))
                .frame(width: 20)
                // Move animation to the end of this view's modifiers
                .animation(.easeOut(duration: 0.2), value: isFocused)
            
            // Text field - extract to separate view to reduce complexity
            textFieldView
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            backgroundView
        )
        .overlay(
            borderView
        )
    }

    // Extract text field to a separate computed property
    private var textFieldView: some View {
        Group {
            if isSecure {
                SecureField("", text: text)
                    .placeholder(when: text.wrappedValue.isEmpty, content: {
                        Text(placeholder).foregroundColor(.white.opacity(0.6))
                    })
                    .focused($isFocused)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(keyboardType)
                    .submitLabel(.done)
                    .onSubmit {
                        onSubmit?()
                    }
            } else {
                TextField("", text: text)
                    .placeholder(when: text.wrappedValue.isEmpty, content: {
                        Text(placeholder).foregroundColor(.white.opacity(0.6))
                    })
                    .focused($isFocused)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(keyboardType)
                    .submitLabel(.next)
                    .onSubmit {
                        onSubmit?()
                    }
            }
        }
    }

    // Extract background to a separate computed property
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.3))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // Extract border to a separate computed property
    private var borderView: some View {
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
            // Move animation to the end of this view's modifiers
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Custom Button
struct TMIButton: View {
    var text: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isPrimary: Bool = true
    var action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Slight delay to show press effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isPrimary ? .white : Color.tmiSecondary))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    Text(text)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(isPrimary ? .white : Color.tmiSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isPrimary 
                            ? LinearGradient(
                                colors: [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(14)
            .shadow(color: isPrimary ? Color.tmiSecondary.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
        }
        .disabled(isLoading)
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

// MARK: - Alert View
struct CustomAlertView: View {
    var title: String
    var message: String
    var primaryButton: (title: String, action: () -> Void)
    var secondaryButton: (title: String, action: () -> Void)? = nil
    
    @State private var offset: CGFloat = 1000
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    if secondaryButton != nil {
                        dismissAlert {
                            secondaryButton?.action()
                        }
                    }
                }
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    if let secondaryButton = secondaryButton {
                        Button(action: {
                            dismissAlert {
                                secondaryButton.action()
                            }
                        }) {
                            Text(secondaryButton.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        dismissAlert {
                            primaryButton.action()
                        }
                    }) {
                        Text(primaryButton.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.tmiSecondary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.7)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 40)
            .offset(y: offset)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                offset = 0
                opacity = 1
                scale = 1
            }
        }
    }
    
    private func dismissAlert(completion: @escaping () -> Void) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            offset = 1000
            opacity = 0
            scale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion()
        }
    }
}
