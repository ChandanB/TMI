//
//  FormBuilderView.swift
//  TMI
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

struct FormBuilderView: View {
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .base)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            // Header
            TMIGlassCard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                  .font(.system(size: 40))
                  .foregroundColor(.tmiSecondary)
                
                Text("Form Builder")
                  .font(.title2.bold())
                  .foregroundColor(Color.tmiTextPrimary)
                
                Text("Drag and drop fields to create your custom form")
                  .font(.body)
                  .foregroundColor(Color.tmiTextSecondary)
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)
            
            // Coming soon message
            TMIGlassCard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "wrench.and.screwdriver.fill")
                  .font(.system(size: 60))
                  .foregroundColor(.orange)
                
                Text("Coming Soon")
                  .font(.title.bold())
                  .foregroundColor(Color.tmiTextPrimary)
                
                Text("The drag-and-drop form builder is currently under development. For now, you can use our pre-built templates from the Forms library.")
                  .font(.body)
                  .foregroundColor(Color.tmiTextSecondary)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal)
              }
            }
            
            TMIButton(
              text: "View Templates",
              icon: "doc.on.doc.fill",
              style: .primary,
              action: {
                dismiss()
              }
            )
            .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
        }
      }
      .navigationTitle("Form Builder")
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
    FormBuilderView()
}
