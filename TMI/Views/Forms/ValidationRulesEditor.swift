//
//  ValidationRulesEditor.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/25/24.
//

import SwiftUI

struct ValidationRulesEditor: View {
    @Binding var validationRules: [ValidationRule]
    var fieldType: FieldType
    
    var body: some View {
        VStack {
            Text("Validation Rules")
                .font(.headline)
                .padding()
            
            ForEach($validationRules.indices, id: \.self) { index in
                if validationRules[index].rule.isApplicable(to: fieldType) {
                    ValidationRuleEditor(validationRule: $validationRules[index], fieldType: fieldType)
                }
            }
            .onDelete(perform: removeValidationRule)
            
            AddValidationRuleButton {
                addValidationRule()
            }
            .padding(.top, 10)
        }
        .padding()
        .cornerRadius(10)
        
        Spacer()
    }
    
    private func removeValidationRule(at offsets: IndexSet) {
        validationRules.remove(atOffsets: offsets)
    }
    
    private func addValidationRule() {
        let defaultRule = ValidationType.defaultRule(for: fieldType)
        validationRules.append(ValidationRule(id: UUID().uuidString, rule: defaultRule, message: "Validation Error"))
    }
}

struct ValidationRuleEditor: View {
    @Binding var validationRule: ValidationRule
    @State private var showAlert = false
    var fieldType: FieldType
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Validation Type", selection: $validationRule.rule) {
                    ForEach(ValidationType.allCases.filter { $0.isApplicable(to: fieldType) }, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                ValidationInfoButton(showAlert: $showAlert, rule: validationRule.rule)
            }
            
            if validationRule.rule.requiresValue {
                let placeholder = validationRule.rule.placeholderText
                TextField(placeholder, text: binding(forValue: validationRule.value))
                    .padding(.horizontal)
                Divider()
            }
            
            ZLHNMultilineTextField(placeholder: "Error Message", text: $validationRule.message, limit: 60)
                .padding(.horizontal)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
    }
    
    private func binding(forValue value: AnyCodable?) -> Binding<String> {
        Binding<String>(
            get: { value?.value as? String ?? "" },
            set: { validationRule.value = AnyCodable($0) }
        )
    }
}

struct ValidationInfoButton: View {
    @Binding var showAlert: Bool
    var rule: ValidationType
    
    var body: some View {
        Button(action: {
            showAlert = true
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityLabel("Info")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Validation Rule Info"),
                message: Text(rule.description),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct AddValidationRuleButton: View {
    var addAction: () -> Void
    
    var body: some View {
        Button(action: addAction) {
            HStack {
                Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                Text("Add Validation Rule").font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
        }
    }
}

#Preview {
    FormTemplateBuilderView(viewModel: FormTemplateBuilderViewModel())
}
