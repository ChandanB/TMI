//
//  ButtonFactory.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/31/24.
//

import SwiftUI

struct BaseButtonStyle: ButtonStyle {
  var foregroundColor: Color
  var backgroundColor: Color
  var pressedScale: CGFloat = 0.96

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.vertical)
      .frame(minWidth: 120)
      .frame(maxWidth: .infinity, maxHeight: 44)
      .background(backgroundColor)
      .foregroundColor(foregroundColor)
      .cornerRadius(10)
      .padding(.horizontal, 4)
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.easeOut, value: configuration.isPressed)
  }
}

struct CustomButton: View {
  let title: String
  let action: () -> Void
  var foregroundColor: Color
  var backgroundColor: Color

  var body: some View {
    Button(action: action) {
      Text(title)
        .fontWeight(.medium)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
    }
    .buttonStyle(
      BaseButtonStyle(foregroundColor: foregroundColor, backgroundColor: backgroundColor))
  }
}