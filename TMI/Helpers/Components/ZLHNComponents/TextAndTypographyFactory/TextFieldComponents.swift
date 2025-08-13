//
//  TextFieldComponents.swift
//  CAMP APP
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

struct DefaultTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding(12)
      .background(Color.tmiBackground)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.gray, lineWidth: 1)
      )
  }
}

struct ZLHNTextField: View {
  var label: String?
  var placeholder: String
  @Binding var text: String
  var isSecure: Bool = false
  var keyboardType: UIKeyboardType = .default

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let label = label {
        Text(label)
          .headline()
          .foregroundColor(.primary)
      }

      if isSecure {
        SecureField(placeholder, text: $text)
          .textFieldStyle(DefaultTextFieldStyle())
      } else {
        TextField(placeholder, text: $text)
          .keyboardType(keyboardType)
          .textFieldStyle(DefaultTextFieldStyle())
      }
    }
    .padding(.horizontal)
  }
}

struct ZLHNMultilineTextField: View {
  var placeholder: String
  @Binding var text: String
  var limit: Int

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      TextEditor(text: $text)
        .frame(minHeight: 100, maxHeight: .infinity)
        .padding(10)
        .background(Color.tmiBackground)
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray, lineWidth: 1)
        )
        .onChange(of: text) { oldValue, newValue in
          if newValue.count > limit {
            text = String(newValue.prefix(limit))
          }
        }
        .onTapGesture {
          if text.isEmpty {
            text = ""
          }
        }

      if text.isEmpty {
        Text(placeholder)
          .foregroundColor(Color(UIColor.placeholderText))
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .frame(minHeight: 100, maxHeight: .infinity, alignment: .topLeading)
      }

      Text("\(text.count)/\(limit)")
        .foregroundColor(.gray)
        .padding(4)
    }
    .padding(.horizontal)
  }
}

struct ZLHNAnimatedSecureField: View {
  var label: String
  @Binding var text: String
  @State private var isSecure: Bool = true
  @State private var isValid: Bool = true

  var body: some View {
    VStack(alignment: .leading) {
      if !label.isEmpty {
        Text(label)
          .font(.headline)
          .foregroundColor(.primary)
      }

      HStack {
        Group {
          if isSecure {
            SecureField("", text: $text)
          } else {
            TextField("", text: $text)
          }
        }
        .padding(.leading)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

        Button(action: {
          isSecure.toggle()
        }) {
          Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
            .foregroundColor(.gray)
        }
        .padding(.trailing)
      }
      .padding(.vertical)
      .background(Color.tmiBackground)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isValid ? Color.gray : Color.red, lineWidth: 1)
      )
    }
    .padding(.horizontal)
    .onAppear {
      validatePassword()
    }
    .onChange(of: text) { _, _ in
      validatePassword()
    }
  }

  private func validatePassword() {
    isValid = text.count >= 8
  }
}