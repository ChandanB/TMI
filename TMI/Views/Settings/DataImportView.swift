//
//  DataImportView.swift
//  TMI
//
//  Created by Chandan Brown on 8/14/25.
//

import SwiftUI
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore

struct DataImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFile: URL?
    @State private var importProgress: Double = 0.0
    @State private var isImporting = false
    @State private var importComplete = false
    @State private var importError: String?
    @State private var showingFilePicker = false
    @State private var importResults: ImportResults?
    
    struct ImportResults {
        let studentsImported: Int
        let plansImported: Int
        let interestsImported: Int
        let hobbiesImported: Int
        let resourcesImported: Int
        let formsImported: Int
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                            .padding(.top, 20)
                        
                        // File Selection Section
                        fileSelectionSection
                        
                        // Import Instructions
                        instructionsSection
                        
                        // Progress Section (when importing)
                        if isImporting {
                            progressSection
                        }
                        
                        // Results Section (when complete)
                        if let results = importResults {
                            resultsSection(results)
                        }
                        
                        // Error Section
                        if let error = importError {
                            errorSection(error)
                        }
                        
                        // Import Button
                        importButtonSection
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json, .commaSeparatedText, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    if let file = files.first {
                        selectedFile = file
                        importError = nil
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
        }
    }
    
    private var headerView: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.tmiSecondary)
                
                Text("Import TMI Data")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Upload data from other TMI systems, CSV files, or JSON exports to get started quickly.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var fileSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Import File")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 16) {
                    if let file = selectedFile {
                        // Selected file display
                        HStack(spacing: 16) {
                            Image(systemName: fileIcon(for: file))
                                .font(.system(size: 24))
                                .foregroundColor(.tmiSecondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.lastPathComponent)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("File selected and ready for import")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingFilePicker = true
                            }
                            .foregroundColor(.tmiSecondary)
                        }
                    } else {
                        // No file selected
                        VStack(spacing: 16) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("No file selected")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Choose a JSON, CSV, or other compatible file to import your TMI data")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
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
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Formats")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 12) {
                    FormatSupportRow(
                        format: "JSON",
                        description: "TMI export files and structured data",
                        icon: "doc.text.fill",
                        supported: true
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    FormatSupportRow(
                        format: "CSV",
                        description: "Spreadsheet data (students, interests, etc.)",
                        icon: "tablecells.fill",
                        supported: true
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    FormatSupportRow(
                        format: "Excel",
                        description: "Microsoft Excel files (.xlsx)",
                        icon: "doc.richtext.fill",
                        supported: false
                    )
                }
            }
        }
    }
    
    private var progressSection: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 16) {
                Text("Importing Data...")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                ProgressView(value: importProgress, total: 1.0)
                    .tmiProgressStyle()
                
                Text("\(Int(importProgress * 100))% Complete")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private func resultsSection(_ results: ImportResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Results")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import Successful")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Your data has been successfully imported")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    VStack(spacing: 8) {
                        if results.studentsImported > 0 {
                            ImportResultRow(icon: "person.3.fill", label: "Students", count: results.studentsImported)
                        }
                        if results.plansImported > 0 {
                            ImportResultRow(icon: "brain.head.profile", label: "TMI Plans", count: results.plansImported)
                        }
                        if results.interestsImported > 0 {
                            ImportResultRow(icon: "star.fill", label: "Interests", count: results.interestsImported)
                        }
                        if results.hobbiesImported > 0 {
                            ImportResultRow(icon: "gamecontroller.fill", label: "Hobbies", count: results.hobbiesImported)
                        }
                        if results.resourcesImported > 0 {
                            ImportResultRow(icon: "books.vertical.fill", label: "Resources", count: results.resourcesImported)
                        }
                        if results.formsImported > 0 {
                            ImportResultRow(icon: "doc.text.fill", label: "Forms", count: results.formsImported)
                        }
                    }
                }
            }
        }
    }
    
    private func errorSection(_ error: String) -> some View {
        TMIGlassCard(style: .error) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
        }
    }
    
    private var importButtonSection: some View {
        VStack(spacing: 16) {
            TMIButton(
                text: isImporting ? "Importing..." : "Import Data",
                icon: isImporting ? nil : "square.and.arrow.down",
                style: .primary,
                isLoading: isImporting,
                isDisabled: selectedFile == nil || isImporting,
                action: {
                    Task {
                        await performImport()
                    }
                }
            )
            
            if selectedFile == nil {
                Text("Please select a file to import")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private func fileIcon(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "json":
            return "doc.text.fill"
        case "csv":
            return "tablecells.fill"
        case "xlsx", "xls":
            return "doc.richtext.fill"
        default:
            return "doc.fill"
        }
    }
    
    @MainActor
    private func performImport() async {
        guard let file = selectedFile else { return }
        
        isImporting = true
        importError = nil
        importResults = nil
        importProgress = 0.0
        
        do {
            guard let user = Auth.auth().currentUser else {
                importError = "User not authenticated"
                isImporting = false
                return
            }
            
            // Secure file access
            guard file.startAccessingSecurityScopedResource() else {
                importError = "Unable to access selected file"
                isImporting = false
                return
            }
            defer { file.stopAccessingSecurityScopedResource() }
            
            importProgress = 0.1
            
            // Read file data
            let data = try Data(contentsOf: file)
            importProgress = 0.2
            
            // Parse JSON data
            guard let jsonData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                importError = "Invalid file format. Please select a valid TMI export file."
                isImporting = false
                return
            }
            
            importProgress = 0.3
            
            let db = Firestore.firestore()
            let userDoc = db.collection("users").document(user.uid)
            
            var results = ImportResults(
                studentsImported: 0,
                plansImported: 0,
                interestsImported: 0,
                hobbiesImported: 0,
                resourcesImported: 0,
                formsImported: 0
            )
            
            // Import each data type
            let dataTypes = ["students", "tmiPlans", "interests", "hobbies", "resources", "forms"]
            let progressIncrement = 0.7 / Double(dataTypes.count)
            
            for dataType in dataTypes {
                if let items = jsonData[dataType] as? [[String: Any]] {
                    let collection = userDoc.collection(dataType)
                    
                    for item in items {
                        // Remove existing ID to create new document
                        var importItem = item
                        importItem.removeValue(forKey: "id")
                        
                        // Add import metadata
                        importItem["importedAt"] = FieldValue.serverTimestamp()
                        importItem["importedFrom"] = file.lastPathComponent
                        
                        try await collection.addDocument(data: importItem)
                        
                        // Update results
                        switch dataType {
                        case "students": results = ImportResults(studentsImported: results.studentsImported + 1, plansImported: results.plansImported, interestsImported: results.interestsImported, hobbiesImported: results.hobbiesImported, resourcesImported: results.resourcesImported, formsImported: results.formsImported)
                        case "tmiPlans": results = ImportResults(studentsImported: results.studentsImported, plansImported: results.plansImported + 1, interestsImported: results.interestsImported, hobbiesImported: results.hobbiesImported, resourcesImported: results.resourcesImported, formsImported: results.formsImported)
                        case "interests": results = ImportResults(studentsImported: results.studentsImported, plansImported: results.plansImported, interestsImported: results.interestsImported + 1, hobbiesImported: results.hobbiesImported, resourcesImported: results.resourcesImported, formsImported: results.formsImported)
                        case "hobbies": results = ImportResults(studentsImported: results.studentsImported, plansImported: results.plansImported, interestsImported: results.interestsImported, hobbiesImported: results.hobbiesImported + 1, resourcesImported: results.resourcesImported, formsImported: results.formsImported)
                        case "resources": results = ImportResults(studentsImported: results.studentsImported, plansImported: results.plansImported, interestsImported: results.interestsImported, hobbiesImported: results.hobbiesImported, resourcesImported: results.resourcesImported + 1, formsImported: results.formsImported)
                        case "forms": results = ImportResults(studentsImported: results.studentsImported, plansImported: results.plansImported, interestsImported: results.interestsImported, hobbiesImported: results.hobbiesImported, resourcesImported: results.resourcesImported, formsImported: results.formsImported + 1)
                        default: break
                        }
                    }
                }
                
                importProgress += progressIncrement
            }
            
            importProgress = 1.0
            importResults = results
            isImporting = false
            importComplete = true
            
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
            isImporting = false
        }
    }
}

struct FormatSupportRow: View {
    let format: String
    let description: String
    let icon: String
    let supported: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(supported ? .tmiSecondary : .white.opacity(0.3))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(format)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if supported {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            } else {
                Text("Coming Soon")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                    .foregroundColor(.orange)
            }
        }
    }
}

struct ImportResultRow: View {
    let icon: String
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.tmiSecondary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
        }
    }
}

#Preview {
    DataImportView()
}
