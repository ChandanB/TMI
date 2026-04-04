//
//  FormImportView.swift
//  TMI
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

struct FormImportView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedFile: URL?
  @State private var showingFilePicker = false
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .base)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 24) {
            // Header
            TMICard(style: .default) {
              VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down.fill")
                  .font(.system(size: 40))
                  .foregroundColor(.tmiSecondary)
                
                Text("Import Form")
                  .font(.title2.bold())
                  .foregroundColor(Color.tmiTextPrimary)
                
                Text("Import existing forms from JSON files or other compatible formats")
                  .font(.body)
                  .foregroundColor(Color.tmiTextSecondary)
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 20)
            
            // File selection
            TMICard(style: .default) {
              VStack(spacing: 20) {
                if let file = selectedFile {
                  HStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                      .font(.system(size: 24))
                      .foregroundColor(.tmiSecondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                      Text(file.lastPathComponent)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.tmiTextPrimary)
                      
                      Text("Ready to import")
                        .font(.system(size: 14))
                        .foregroundColor(Color.tmiTextSecondary)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                      showingFilePicker = true
                    }
                    .foregroundColor(.tmiSecondary)
                  }
                } else {
                  VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                      .font(.system(size: 40))
                      .foregroundColor(Color.tmiTextTertiary)
                    
                    Text("No file selected")
                      .font(.system(size: 18, weight: .medium))
                      .foregroundColor(Color.tmiTextSecondary)
                  }
                }
                
                TMIButton(
                  text: selectedFile == nil ? "Select File" : "Change File",
                  icon: "folder",
                  style: .secondary,
                  action: {
                    showingFilePicker = true
                  }
                )
              }
            }
            
            // Import button
            TMIButton(
              text: "Import Form",
              icon: "square.and.arrow.down",
              style: .primary,
              isDisabled: selectedFile == nil,
              action: {
                // Import the form
                dismiss()
              }
            )
            .padding(.bottom, 40)
          }
          .padding(.horizontal, 20)
        }
      }
      .navigationTitle("Import Form")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(Color.tmiTextPrimary)
        }
      }
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [.json, .data],
        allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let files):
          if let file = files.first {
            selectedFile = file
          }
        case .failure(let error):
          print("Error selecting file: \(error)")
        }
      }
  }
}

#Preview {
    FormImportView()
}
