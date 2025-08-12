//
//  FormPreviewView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/26/24.
//

import SwiftUI

struct FormPreviewView: View {
    var template: FormTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(template.sections, id: \.id) { section in
                    Text(section.title)
                        .font(.title2)
                        .bold()

                    ForEach(section.fields, id: \.id) { field in
                        DynamicFormFieldPreview(field: field)
                    }
                    
                    Divider()
                        .padding(.vertical)
                }
            }
            .padding()
        }
    }
}


struct DynamicFormFieldPreview: View {
    @Environment(\.dynamicFormStateModel) var stateModel
    let field: FormField
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(field.label.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top)
            
            generateFieldView(for: field)
        }
    }
    
    @ViewBuilder
    func generateFieldView(for field: FormField) -> some View {
        switch field.type {
        case .allCases:
            EmptyView()
        case .text, .email, .phoneNumber:
            ZLHNTextField(placeholder: "Enter \(field.label)", text: .constant(""))
            
        case .longText:
            ZLHNMultilineTextField(placeholder: "Enter \(field.label)", text: .constant(""), limit: 1000)
            
        case .number:
            ZLHNTextField(placeholder: "Enter \(field.label)", text: .constant(""))
                .keyboardType(.numberPad)
            
        case .date:
            DatePicker("Date", selection: .constant(Date()), displayedComponents: .date)
                .labelsHidden()
                .disabled(true)
            
        case .time:
            DatePicker("Time", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(true)
            
        case .dateTime:
            DatePicker(field.label, selection: .constant(Date()), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(true)
            
        case .checkbox:
            Toggle(field.label, isOn: .constant(false))
            
        case .multipleChoice:
            // Use a local @State binding to resolve ambiguous MultipleChoiceField initializer.
            if let options = field.options {
                PreviewMultipleChoiceField(label: field.label, options: options)
            } else {
                EmptyView()
            }
            
        case .dropdown:
            PreviewDropdownField(label: field.label, options: field.options ?? [])
            
        case .url:
            ZLHNTextField(placeholder: "Enter \(field.label)", text: .constant(""))
                .keyboardType(.URL)
                .autocapitalization(.none)
            
        case .file:
            Button(action: {
            }) {
                HStack {
                    Image(systemName: "paperclip")
                    Text("Upload File")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        case .rating:
            // tappable star‐rating from 1…5
            if let key = field.id {
                let binding = Binding<Int>(
                  get: { stateModel.formData[key]?.value as? Int ?? 0 },
                  set: { stateModel.formData[key] = AnyCodable($0) }
                )
                HStack(spacing: 4) {
                  ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= binding.wrappedValue ? "star.fill" : "star")
                      .foregroundColor(.yellow)
                      .onTapGesture { binding.wrappedValue = star }
                  }
                }
            }
        case .table:
            // placeholder until you wire up a proper grid editor
            Text("Table input not supported yet")
              .foregroundColor(.white.opacity(0.7))

        case .signature:
            // placeholder "canvas" — swap in your PencilKit or signature‐capture view
            if let sigKey = field.id {
                let sigBinding = Binding<Data>(
                  get: { stateModel.formData[sigKey]?.value as? Data ?? Data() },
                  set: { stateModel.formData[sigKey] = AnyCodable($0) }
                )
    //            SignaturePadView(drawingData: sigBinding)
    //              .frame(height: 200)
    //              .border(Color.white.opacity(0.5))
            }
        }
    }
}

struct PreviewMultipleChoiceField: View {
    let label: String
    let options: [String]
    @State private var selectedOptions: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            ForEach(options, id: \.self) { option in
                Button(action: {
                    if selectedOptions.contains(option) {
                        selectedOptions.removeAll { $0 == option }
                    } else {
                        selectedOptions.append(option)
                    }
                }) {
                    HStack {
                        Image(systemName: selectedOptions.contains(option) ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedOptions.contains(option) ? .blue : .gray)
                        Text(option)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct PreviewDropdownField: View {
    let label: String
    let options: [String]
    @State private var selection: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack {
                    Text(selection.isEmpty ? "Select" : selection)
                        .foregroundColor(selection.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(5)
            }
            .buttonStyle(PlainButtonStyle())
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selection = option
                            isExpanded = false
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(Color(.systemGray5))
                .cornerRadius(5)
                .shadow(radius: 2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FormPreviewView(template: DefaultFormTemplates.camperRegistrationFormTemplate)
}
