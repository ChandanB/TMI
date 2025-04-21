// StudentListFilterView.swift

import SwiftUI

struct StudentListFilterView: View {
    @Binding var selectedOption: FilterOption
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    HStack {
                        Text(option.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                        if option == selectedOption {
                            Image(systemName: "checkmark")
                                .foregroundColor(.tmiPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedOption = option
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filter Students")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    StudentListFilterView(selectedOption: .constant(.all))
}
