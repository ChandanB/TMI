//
//  FormComponents.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/25/24.
//

import SwiftUI

struct CustomForm<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding(36)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }
}

struct MultipleChoiceField: View {
    var label: String
    @Binding var selectedOptions: [String]
    var options: [String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Button(action: {
                self.isExpanded.toggle()
            }) {
                HStack {
                    Text(selectedOptions.isEmpty ? "Select" : selectedOptions.joined(separator: ", "))
                        .foregroundColor(selectedOptions.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(label)
                    .font(.headline)
                ForEach(options, id: \.self) { option in
                    MultipleChoiceOption(option: option, isSelected: selectedOptions.contains(option)) {
                        if selectedOptions.contains(option) {
                            selectedOptions.removeAll { $0 == option }
                        } else {
                            selectedOptions.append(option)
                        }
                    }
                }
            }
        }
    }
}

struct MultipleChoiceOption: View {
    var option: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .cornerRadius(5)
        }
    }
}

struct DropdownField: View {
    var label: String
    @Binding var selection: String
    var options: [String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Button(action: {
                self.isExpanded.toggle()
            }) {
                HStack {
                    Text(selection.isEmpty ? "Select" : selection)
                        .foregroundColor(selection.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            self.selection = option
                            self.isExpanded = false
                        }) {
                            Text(option)
                                .foregroundColor(.primary)
                                .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
        }
    }
}

struct DatePickerView: View {
    var label: String
    @Binding var date: Date
    var displayedComponents: DatePickerComponents
    
    var body: some View {
        DatePicker(label, selection: $date, displayedComponents: displayedComponents)
            .datePickerStyle(CompactDatePickerStyle())
    }
}

struct FileUploadButton: View {
    @Binding var fileURL: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "paperclip")
                Text(fileURL.isEmpty ? "Upload File" : fileURL)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

struct LabelTextField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.headline)
            TextField("", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

struct RequiredToggle: View {
    @Binding var isRequired: Bool
    
    var body: some View {
        Toggle(isOn: $isRequired) {
            Text("Is This Field Required?")
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
    }
}

struct OptionItem: Identifiable, Hashable {
    let id: UUID = UUID()
    var value: String
}

struct OptionItemView: View {
    @Binding var option: OptionItem
    
    var body: some View {
        TextField("Option", text: $option.value)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

struct OptionsEditor: View {
    @Binding var options: [String]
    @Bindable var viewModel: FormTemplateBuilderViewModel
    var sectionIndex: Int
    var fieldIndex: Int

    var body: some View {
        VStack {
            ForEach(options.indices, id: \.self) { index in
                ZLHNTextField(placeholder: "Option \(index + 1)", text: Binding(
                    get: { self.options[index] },
                    set: { self.options[index] = $0 }
                ))
                .padding(.top)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button(action: addOption) {
                Label("Add Option", systemImage: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .padding(.top)
            }
            
            if !options.isEmpty {
                Button("Remove Last Option", action: removeLastOption)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
    }

    private func addOption() {
        viewModel.addOptionToField(inSection: sectionIndex, fieldIndex: fieldIndex, option: "")
    }

    private func removeLastOption() {
        viewModel.removeOptionFromField(inSection: sectionIndex, fieldIndex: fieldIndex, optionIndex: options.count - 1)
    }
}



