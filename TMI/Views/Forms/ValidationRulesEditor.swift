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
                // Removed filtering by isApplicable(to:)
                ValidationRuleEditor(validationRule: $validationRules[index], fieldType: fieldType)
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
        // Updated to create proper ValidationRule instances depending on fieldType
        let newRule: ValidationRule
        
        switch fieldType {
        case .text, .longText:
            // Use textLength with default min/max and fieldName
            newRule = ValidationRule.textLength(min: 0, max: 100, fieldName: "Field", message: "Validation Error")
        case .number:
            // Use numericRange with default min/max and fieldName (0 to 100 as default)
            newRule = ValidationRule.numericRange(min: 0, max: 100, fieldName: "Field", message: "Validation Error")
        default:
            // Default fallback to required
            newRule = ValidationRule.required(message: "Validation Error")
        }
        
        validationRules.append(newRule)
    }
}

struct ValidationRuleEditor: View {
    @Binding var validationRule: ValidationRule
    @State private var showAlert = false
    var fieldType: FieldType
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Validation Type", selection: $validationRule.ruleType) {
                    ForEach(ValidationRuleType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                ValidationInfoButton(showAlert: $showAlert, ruleType: validationRule.ruleType)
            }
            
            // UI for editing parameters for textLength and numericRange using validationRule.parameters
            
            switch validationRule.ruleType {
            case .textLength:
                Text("Min Length")
                TextField(
                    "Min",
                    text: Binding(
                        get: {
                            if case let .textLength(min, _, _) = validationRule.parameters {
                                return String(min)
                            }
                            return ""
                        },
                        set: { newValue in
                            let minVal = Int(newValue) ?? 0
                            if case let .textLength(_, max, fieldName) = validationRule.parameters {
                                validationRule.parameters = .textLength(min: minVal, max: max, fieldName: fieldName)
                            } else {
                                validationRule.parameters = .textLength(min: minVal, max: 100, fieldName: "Field")
                            }
                        }
                    )
                )
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Max Length")
                TextField(
                    "Max",
                    text: Binding(
                        get: {
                            if case let .textLength(_, max, _) = validationRule.parameters {
                                return String(max)
                            }
                            return ""
                        },
                        set: { newValue in
                            let maxVal = Int(newValue) ?? 100
                            if case let .textLength(min, _, fieldName) = validationRule.parameters {
                                validationRule.parameters = .textLength(min: min, max: maxVal, fieldName: fieldName)
                            } else {
                                validationRule.parameters = .textLength(min: 0, max: maxVal, fieldName: "Field")
                            }
                        }
                    )
                )
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
            case .numericRange:
                Text("Min Value")
                TextField(
                    "Min",
                    text: Binding(
                        get: {
                            if case let .numericRange(min, _, _) = validationRule.parameters {
                                return String(min)
                            }
                            return ""
                        },
                        set: { newValue in
                            let minVal = Double(newValue) ?? 0
                            if case let .numericRange(_, max, fieldName) = validationRule.parameters {
                                validationRule.parameters = .numericRange(min: Int(minVal), max: max, fieldName: fieldName)
                            } else {
                                validationRule.parameters = .numericRange(min: Int(minVal), max: 100, fieldName: "Field")
                            }
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Max Value")
                TextField(
                    "Max",
                    text: Binding(
                        get: {
                            if case let .numericRange(_, max, _) = validationRule.parameters {
                                return String(max)
                            }
                            return ""
                        },
                        set: { newValue in
                            let maxVal = Double(newValue) ?? 100
                            if case let .numericRange(min, _, fieldName) = validationRule.parameters {
                                validationRule.parameters = .numericRange(min: min, max: Int(maxVal), fieldName: fieldName)
                            } else {
                                validationRule.parameters = .numericRange(min: 0, max: Int(maxVal), fieldName: "Field")
                            }
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
            default:
                EmptyView()
            }
            
            ZLHNMultilineTextField(placeholder: "Error Message", text: $validationRule.message, limit: 60)
                .padding(.horizontal)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.tmiSurface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.tmiTextTertiary.opacity(0.3), lineWidth: 1))
    }
}

struct ValidationInfoButton: View {
    @Binding var showAlert: Bool
    var ruleType: ValidationRuleType
    
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
                message: Text(ruleType.displayName),
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
