//
//  FormComponents.swift
//  TMI
//
//  Shared components for Forms and Surveys
//

import SwiftUI

// MARK: - Section Preview Card

struct SectionPreviewCard: View {
  var section: FormSection

  @State private var isExpanded = false

  var body: some View {
    TMICard(style: .outlined) {
      VStack(alignment: .leading, spacing: 0) {
        // Section Header
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded.toggle()
          }
        } label: {
          HStack {
            Text(section.title)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(Color.tmiTextPrimary)

            Spacer()

            Text("\(section.fields.count) fields")
              .font(.system(size: 14))
              .foregroundColor(Color.tmiTextSecondary)

            Image(systemName: "chevron.right")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(Color.tmiTextSecondary)
              .rotationEffect(Angle(degrees: isExpanded ? 90 : 0))
          }
          .padding(16)
        }
        .buttonStyle(.plain)

        // Fields (when expanded)
        if isExpanded {
          VStack(alignment: .leading, spacing: 12) {
            ForEach(section.fields) { field in
              FieldPreviewRow(field: field)
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
        }
      }
    }
  }
}

// MARK: - Field Preview Row

struct FieldPreviewRow: View {
  var field: FormField

  var body: some View {
    HStack(spacing: 12) {
      // Field type icon
      ZStack {
        Circle()
          .fill(Color.white.opacity(0.05))
          .frame(width: 36, height: 36)

        Image(systemName: field.type.iconName)
          .font(.system(size: 16))
          .foregroundColor(Color.tmiTextSecondary)
      }

      // Field label and type
      VStack(alignment: .leading, spacing: 4) {
        Text(field.label)
          .font(.system(size: 15))
          .foregroundColor(Color.tmiTextPrimary)

        HStack(spacing: 8) {
          Text(field.type.rawValue)
            .font(.system(size: 12))
            .foregroundColor(Color.tmiTextSecondary)

          if field.isRequired {
            Text("Required")
              .font(.system(size: 12, weight: .medium))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                Capsule()
                  .fill(Color.red.opacity(0.2))
              )
              .foregroundColor(.red.opacity(0.8))
          }
        }
      }

      Spacer()
    }
    .padding(.vertical, 8)
  }
}

// MARK: - Dynamic Field View

struct DynamicFieldView: View {
  var field: FormField
  var onValueChange: (Any) -> Void

  @State private var textValue = ""
  @State private var numberValue = ""
  @State private var dateValue = Date()
  @State private var selectedOption = ""
  @State private var selectedOptions: [String] = []
  @State private var ratingValue = 0

  var body: some View {
    TMICard(style: .outlined) {
      VStack(alignment: .leading, spacing: 12) {
        // Field label
        HStack(spacing: 4) {
          Text(field.label)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.tmiTextPrimary)

          if field.isRequired {
            Text("*")
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(.red)
          }
        }

        // Field input based on type
        fieldContent
          .padding(.top, 4)
      }
    }
  }

  @ViewBuilder
  private var fieldContent: some View {
    switch field.type {
    case .text:
      TMITextField(
        icon: "text.cursor",
        placeholder: field.placeholder ?? "Enter text",
        text: $textValue
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }

    case .longText:
      TextEditor(text: $textValue)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.05))
        )
        .foregroundColor(Color.tmiTextPrimary)
        .frame(height: 120)
        .onChange(of: textValue) { _, newValue in
          onValueChange(newValue)
        }

    case .number:
      TMITextField(
        icon: "number",
        placeholder: field.placeholder ?? "Enter number",
        text: $numberValue,
        keyboardType: .numberPad
      )
      .onChange(of: numberValue) { _, newValue in
        onValueChange(newValue)
      }

    case .date:
      DatePicker("", selection: $dateValue, displayedComponents: .date)
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Color.tmiSecondary)
        .onChange(of: dateValue) { _, newValue in
          onValueChange(newValue)
        }

    case .time:
      DatePicker("", selection: $dateValue, displayedComponents: .hourAndMinute)
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Color.tmiSecondary)
        .onChange(of: dateValue) { _, newValue in
          onValueChange(newValue)
        }

    case .multipleChoice:
      if let options = field.options {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(options, id: \.self) { option in
            Button {
              selectedOption = option
              onValueChange(option)
            } label: {
              HStack {
                Image(systemName: selectedOption == option ? "circle.inset.filled" : "circle")
                  .foregroundColor(
                    selectedOption == option ? Color.tmiSecondary : .white.opacity(0.6))

                Text(option)
                  .foregroundColor(Color.tmiTextPrimary)

                Spacer()
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      } else {
        Text("No options available")
          .foregroundColor(Color.tmiTextTertiary)
      }

    case .checkbox:
      if let options = field.options {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(options, id: \.self) { option in
            Button {
              if selectedOptions.contains(option) {
                selectedOptions.removeAll { $0 == option }
              } else {
                selectedOptions.append(option)
              }
              onValueChange(selectedOptions)
            } label: {
              HStack {
                Image(
                  systemName: selectedOptions.contains(option) ? "checkmark.square.fill" : "square"
                )
                .foregroundColor(
                  selectedOptions.contains(option) ? Color.tmiSecondary : .white.opacity(0.6))

                Text(option)
                  .foregroundColor(Color.tmiTextPrimary)

                Spacer()
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      } else {
        Text("No options available")
          .foregroundColor(Color.tmiTextTertiary)
      }

    case .dropdown:
      if let options = field.options {
        Menu {
          ForEach(options, id: \.self) { option in
            Button(option) {
              selectedOption = option
              onValueChange(option)
            }
          }
        } label: {
          HStack {
            Text(selectedOption.isEmpty ? "Select an option" : selectedOption)
              .foregroundColor(selectedOption.isEmpty ? Color.tmiTextTertiary : Color.tmiTextPrimary)

            Spacer()

            Image(systemName: "chevron.down")
              .foregroundColor(Color.tmiTextSecondary)
          }
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.tmiInputBackground)
          )
        }
      } else {
        Text("No options available")
          .foregroundColor(Color.tmiTextTertiary)
      }

    case .rating:
      HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { rating in
          Button {
            ratingValue = rating
            onValueChange(rating)
          } label: {
            Image(systemName: rating <= ratingValue ? "star.fill" : "star")
              .font(.system(size: 24))
              .foregroundColor(rating <= ratingValue ? .yellow : Color.tmiTextTertiary)
          }
          .buttonStyle(.plain)
        }
      }

    case .file:
      TMIButton(
        text: "Upload File",
        icon: "doc.badge.plus",
        style: .secondary,
        action: {
          // File upload logic would go here
        }
      )

    case .table, .signature:
      Text("This field type is only available in the full version")
        .foregroundColor(Color.tmiTextTertiary)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.05))
        )
    case .dateTime:
      DatePicker("", selection: $dateValue, displayedComponents: [.date, .hourAndMinute])
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Color.tmiSecondary)
        .onChange(of: dateValue) { _, newValue in
          onValueChange(newValue)
        }
    case .email:
      TMITextField(
        icon: "envelope",
        placeholder: field.placeholder ?? "Enter email",
        text: $textValue,
        keyboardType: .emailAddress
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }
    case .phoneNumber:
      TMITextField(
        icon: "phone",
        placeholder: field.placeholder ?? "Enter phone number",
        text: $textValue,
        keyboardType: .phonePad
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }
    case .url:
      TMITextField(
        icon: "link",
        placeholder: field.placeholder ?? "Enter URL",
        text: $textValue,
        keyboardType: .URL
      )
      .onChange(of: textValue) { _, newValue in
        onValueChange(newValue)
      }
    case .allCases:
      EmptyView()
    }
  }
}

// MARK: - Progress Indicator

struct FormsProgressIndicator: View {
  var current: Int
  var total: Int

  private var progress: CGFloat {
    total > 0 ? CGFloat(current) / CGFloat(total) : 0
  }

  var body: some View {
    VStack(spacing: 8) {
      // Progress bar
      ProgressView(value: progress)
        .tmiProgressStyle(color: .tmiSecondary)

      // Text indicator
      HStack {
        Text("Section \(current) of \(total)")
          .font(.system(size: 14))
          .foregroundColor(Color.tmiTextSecondary)

        Spacer()

        Text("\(Int(progress * 100))%")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(Color.tmiTextPrimary)
      }
    }
  }
}

// MARK: - Loading Indicator

struct FormLoadingIndicator: View {
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      // Outer circle
      Circle()
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [
              Color.tmiSecondary.opacity(0),
              Color.tmiSecondary,
            ]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
          ),
          lineWidth: 6
        )
        .frame(width: 80, height: 80)
        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
        .animation(
          Animation.linear(duration: 2)
            .repeatForever(autoreverses: false),
          value: isAnimating
        )

      // Inner pulsing circle
      Circle()
        .fill(Color.tmiSecondary.opacity(0.3))
        .frame(width: 60, height: 60)
        .scaleEffect(isAnimating ? 0.8 : 0.6)
        .opacity(isAnimating ? 0.6 : 0.3)
        .animation(
          Animation.easeInOut(duration: 1)
            .repeatForever(autoreverses: true),
          value: isAnimating
        )

      // Form icon
      Image(systemName: "doc.text.fill")
        .font(.system(size: 24, weight: .medium))
        .foregroundColor(Color.tmiTextPrimary)
    }
    .onAppear {
      isAnimating = true
    }
  }
}
