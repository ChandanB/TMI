//
//  DataExportView.swift
//  TMI
//
//  Created by Chandan Brown on 8/14/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormats: Set<ExportFormat> = [.json]
    @State private var selectedDataTypes: Set<DataType> = [.students, .tmiPlans, .interests, .hobbies]
    @State private var isExporting = false
    @State private var exportComplete = false
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"
        case pdf = "PDF"
        
        var id: String { rawValue }
        var description: String {
            switch self {
            case .json: return "Machine-readable format, ideal for importing into other TMI systems"
            case .csv: return "Spreadsheet format, ideal for data analysis in Excel or Google Sheets"
            case .pdf: return "Human-readable format, ideal for sharing with colleagues or administrators"
            }
        }
        
        var icon: String {
            switch self {
            case .json: return "doc.text.fill"
            case .csv: return "tablecells.fill"
            case .pdf: return "doc.richtext.fill"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .pdf: return "pdf"
            }
        }
    }
    
    enum DataType: String, CaseIterable, Identifiable {
        case students = "Students"
        case tmiPlans = "TMI Plans"
        case interests = "Interests"
        case hobbies = "Hobbies"
        case resources = "Resources"
        case forms = "Forms & Surveys"
        
        var id: String { rawValue }
        var description: String {
            switch self {
            case .students: return "Student profiles, demographics, and academic information"
            case .tmiPlans: return "All TMI intervention plans and progress tracking"
            case .interests: return "Student interests database and categorizations"
            case .hobbies: return "Student hobbies database and educational activities"
            case .resources: return "Educational resources and materials library"
            case .forms: return "Custom forms, surveys, and submission data"
            }
        }
        
        var icon: String {
            switch self {
            case .students: return "person.3.fill"
            case .tmiPlans: return "brain.head.profile"
            case .interests: return "star.fill"
            case .hobbies: return "gamecontroller.fill"
            case .resources: return "books.vertical.fill"
            case .forms: return "doc.text.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
                TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.default)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                            .padding(.top, 20)
                        
                        // Export Formats Section
                        formatSelectionSection
                        
                        // Data Types Section
                        dataTypeSelectionSection
                        
                        // Export Button
                        exportButtonSection
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
    
    private var headerView: some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.tmiSecondary)
                
                Text("Export Your TMI Data")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Download your data in various formats for backup, analysis, or migration to other systems.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Formats")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 0) {
                    ForEach(ExportFormat.allCases) { format in
                        ExportFormatRow(
                            format: format,
                            isSelected: selectedFormats.contains(format)
                        ) {
                            if selectedFormats.contains(format) {
                                selectedFormats.remove(format)
                            } else {
                                selectedFormats.insert(format)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var dataTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data to Export")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            TMIGlassCard(style: .default) {
                VStack(spacing: 0) {
                    ForEach(DataType.allCases) { dataType in
                        DataTypeRow(
                            dataType: dataType,
                            isSelected: selectedDataTypes.contains(dataType)
                        ) {
                            if selectedDataTypes.contains(dataType) {
                                selectedDataTypes.remove(dataType)
                            } else {
                                selectedDataTypes.insert(dataType)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            if exportComplete {
                TMIGlassCard(style: .default) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export Complete")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Your data has been successfully exported")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                }
            }
            
            TMIButton(
                text: isExporting ? "Exporting..." : "Export Data",
                icon: isExporting ? nil : "square.and.arrow.up",
                style: .primary,
                isLoading: isExporting,
                isDisabled: selectedFormats.isEmpty || selectedDataTypes.isEmpty,
                action: {
                    Task {
                        await performExport()
                    }
                }
            )
            
            if !selectedFormats.isEmpty && !selectedDataTypes.isEmpty {
                Text("This will export \(selectedDataTypes.count) data types in \(selectedFormats.count) format\(selectedFormats.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @MainActor
    private func performExport() async {
        isExporting = true
        
        do {
            guard let user = Auth.auth().currentUser else {
                isExporting = false
                return
            }
            
            let db = Firestore.firestore()
            let userDoc = db.collection("users").document(user.uid)
            
            var exportData: [String: Any] = [:]
            exportData["exportDate"] = Date()
            exportData["userId"] = user.uid
            exportData["userEmail"] = user.email
            
            // Export selected data types
            for dataType in selectedDataTypes {
                switch dataType {
                case .students:
                    let studentsSnapshot = try await userDoc.collection("students").getDocuments()
                    exportData["students"] = studentsSnapshot.documents.map { $0.data() }
                    
                case .tmiPlans:
                    let plansSnapshot = try await userDoc.collection("tmiPlans").getDocuments()
                    exportData["tmiPlans"] = plansSnapshot.documents.map { $0.data() }
                    
                case .interests:
                    let interestsSnapshot = try await userDoc.collection("interests").getDocuments()
                    exportData["interests"] = interestsSnapshot.documents.map { $0.data() }
                    
                case .hobbies:
                    let hobbiesSnapshot = try await userDoc.collection("hobbies").getDocuments()
                    exportData["hobbies"] = hobbiesSnapshot.documents.map { $0.data() }
                    
                case .resources:
                    let resourcesSnapshot = try await userDoc.collection("resources").getDocuments()
                    exportData["resources"] = resourcesSnapshot.documents.map { $0.data() }
                    
                case .forms:
                    let formsSnapshot = try await userDoc.collection("forms").getDocuments()
                    exportData["forms"] = formsSnapshot.documents.map { $0.data() }
                }
            }
            
            // Create files for selected formats
            for format in selectedFormats {
                try await createExportFile(data: exportData, format: format)
            }
            
            isExporting = false
            exportComplete = true
            
            // Auto-dismiss after success
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
            
        } catch {
            print("Export error: \(error)")
            isExporting = false
            // Could show error alert here
        }
    }
    
    private func createExportFile(data: [String: Any], format: ExportFormat) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "TMI_Export_\(timestamp).\(format.fileExtension)"
        
        switch format {
        case .json:
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try await saveToDocuments(data: jsonData, filename: filename)
            
        case .csv:
            let csvContent = convertToCSV(data: data)
            let csvData = csvContent.data(using: .utf8)!
            try await saveToDocuments(data: csvData, filename: filename)
            
        case .pdf:
            // PDF generation would require more complex implementation
            // For now, create a simple text-based PDF
            let textContent = formatForPDF(data: data)
            let pdfData = textContent.data(using: .utf8)!
            try await saveToDocuments(data: pdfData, filename: filename.replacingOccurrences(of: ".pdf", with: ".txt"))
        }
    }
    
    private func saveToDocuments(data: Data, filename: String) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }
    
    private func convertToCSV(data: [String: Any]) -> String {
        var csv = ""
        
        // Simple CSV conversion for demonstration
        for (key, value) in data {
            if let array = value as? [[String: Any]] {
                csv += "\(key.uppercased())\n"
                csv += "ID,Data\n"
                for (index, item) in array.enumerated() {
                    let jsonString = (try? JSONSerialization.data(withJSONObject: item))?.base64EncodedString() ?? ""
                    csv += "\(index),\"\(jsonString)\"\n"
                }
                csv += "\n"
            }
        }
        
        return csv
    }
    
    private func formatForPDF(data: [String: Any]) -> String {
        var content = "TMI Data Export\n"
        content += "Generated: \(Date())\n\n"
        
        for (key, value) in data {
            content += "\(key.uppercased()):\n"
            if let array = value as? [[String: Any]] {
                content += "Total items: \(array.count)\n"
            }
            content += "\n"
        }
        
        return content
    }
}

struct ExportFormatRow: View {
    let format: DataExportView.ExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: format.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.tmiSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(format.description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .tmiSecondary : .white.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DataTypeRow: View {
    let dataType: DataExportView.DataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: dataType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.tmiSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(dataType.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(dataType.description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .tmiSecondary : .white.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DataExportView()
}
