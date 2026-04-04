//
//  FormCreationView.swift
//  TMI
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

struct FormCreationView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var formName = ""
  @State private var formDescription = ""
  @State private var selectedCategory = "Survey"
  
  let categories = ["Survey", "Assessment", "Feedback", "Registration", "Other"]

  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .base)
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            TMICard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "square.and.pencil")
                  .font(.system(size: 40))
                  .foregroundColor(.tmiSecondary)
                
                Text("Create New Form")
                  .font(.title2.bold())
                  .foregroundColor(Color.tmiTextPrimary)
                
                Text("Start building your custom form from scratch")
                  .font(.body)
                  .foregroundColor(Color.tmiTextSecondary)
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)
            
            // Form details
            TMICard(style: .default) {
              VStack(spacing: 20) {
                TMITextField(
                  icon: "doc.text",
                  placeholder: "Form Name",
                  text: $formName
                )
                
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Image(systemName: "text.alignleft")
                      .font(.system(size: 16))
                      .foregroundColor(.tmiSecondary)
                    Text("Description")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(Color.tmiTextPrimary)
                  }
                  
                  TextEditor(text: $formDescription)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                      RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                    )
                    .foregroundColor(Color.tmiTextPrimary)
                    .frame(height: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Image(systemName: "tag")
                      .font(.system(size: 16))
                      .foregroundColor(.tmiSecondary)
                    Text("Category")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(Color.tmiTextPrimary)
                  }
                  
                  Menu {
                    ForEach(categories, id: \.self) { category in
                      Button(category) {
                        selectedCategory = category
                      }
                    }
                  } label: {
                    HStack {
                      Text(selectedCategory)
                        .foregroundColor(Color.tmiTextPrimary)
                      Spacer()
                      Image(systemName: "chevron.down")
                        .foregroundColor(Color.tmiTextSecondary)
                    }
                    .padding(12)
                    .background(
                      RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                    )
                  }
                }
              }
            }
            
            // Action buttons
            VStack(spacing: 12) {
              TMIButton(
                text: "Continue to Builder",
                icon: "arrow.right",
                style: .primary,
                isDisabled: formName.isEmpty,
                action: {
                  // Navigate to form builder with these details
                  dismiss()
                }
              )
              
              TMIButton(
                text: "Start from Template",
                icon: "doc.on.doc",
                style: .secondary,
                action: {
                  // Show template selection
                  dismiss()
                }
              )
            }
            .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
        }
      }
      .navigationTitle("Create Form")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(Color.tmiTextPrimary)
        }
      }
  }
}

#Preview {
    FormCreationView()
}
