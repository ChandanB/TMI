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
            DatePickerView(label: "Date", date: .constant(Date()), displayedComponents: .date)
            
        case .time:
            DatePickerView(label: "Time", date: .constant(Date()), displayedComponents: .hourAndMinute)
            
        case .dateTime:
            DatePickerView(label: field.label, date: .constant(Date()), displayedComponents: [.date, .hourAndMinute])
            
        case .checkbox:
            Toggle(field.label, isOn: .constant(false))
            
        case .multipleChoice:
            MultipleChoiceField(label: field.label, selectedOptions: .constant([""]), options: field.options ?? [])
            
        case .dropdown:
            DropdownField(label: field.label, selection: .constant(""), options: field.options ?? [])
            
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
        }
    }
}

#Preview {
    FormPreviewView(template: DefaultFormTemplates.camperRegistrationFormTemplate)
}
