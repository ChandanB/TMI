//
//  AuthComponents.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import FirebaseAuth
import SwiftUI

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

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      completion()
    }
  }
}

