//
//  FormPreviewView.swift
//  TMI
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

struct FormPreviewView: View {
  let template: FormTemplate
  @Environment(\.dismiss) private var dismiss
  @State private var currentSectionIndex = 0
  @State private var fieldValues: [String: Any] = [:]
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .base)
          .ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Progress indicator
          if template.sections.count > 1 {
            FormsProgressIndicator(
              current: currentSectionIndex + 1,
              total: template.sections.count
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
          }
          
          // Current section
          ScrollView {
            VStack(spacing: 20) {
              if currentSectionIndex < template.sections.count {
                let currentSection = template.sections[currentSectionIndex]
                
                // Section header
                TMIGlassCard(style: .default) {
                  VStack(spacing: 12) {
                    Text(currentSection.title)
                      .font(.title2.bold())
                      .foregroundColor(.white)
                    
                    if let description = currentSection.description, !description.isEmpty {
                      Text(description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    }
                  }
                }
                .padding(.top, 20)
                
                // Fields
                ForEach(currentSection.fields) { field in
                  DynamicFieldView(field: field) { value in
                    if let fieldId = field.id {
                      fieldValues[fieldId] = value
                    }
                  }
                }
              }
              
              Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
          }
          
          // Navigation buttons
          HStack(spacing: 16) {
            if currentSectionIndex > 0 {
              TMIButton(
                text: "Previous",
                icon: "chevron.left",
                style: .secondary,
                action: {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentSectionIndex -= 1
                  }
                }
              )
            }
            
            Spacer()
            
            if currentSectionIndex < template.sections.count - 1 {
              TMIButton(
                text: "Next",
                icon: "chevron.right",
                style: .primary,
                action: {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    currentSectionIndex += 1
                  }
                }
              )
            } else {
              TMIButton(
                text: "Complete Preview",
                icon: "checkmark",
                style: .primary,
                action: {
                  dismiss()
                }
              )
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
        }
      }
      .navigationTitle("Preview: \(template.name)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
  }
}
