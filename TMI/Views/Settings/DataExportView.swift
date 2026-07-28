//
//  DataExportView.swift
//  TMI
//
//  Created by Chandan Brown on 8/14/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormats: Set<ExportFormat> = [.json]
    @State private var selectedDataTypes: Set<DataType> = [.tmiPlans, .interests, .hobbies]
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportDocument: TMIExportDocument?
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "TMI_Export"
    @State private var isPresentingExporter = false
    @State private var exportErrorMessage: String?
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"
        
        var id: String { rawValue }
        var description: String {
            switch self {
            case .json: return "Machine-readable format, ideal for importing into other TMI systems"
            case .csv: return "Spreadsheet format, ideal for data analysis in Excel or Google Sheets"
            }
        }
        
        var icon: String {
            switch self {
            case .json: return "doc.text.fill"
            case .csv: return "tablecells.fill"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            }
        }

        var contentType: UTType {
            switch self {
            case .json: .json
            case .csv: .commaSeparatedText
            }
        }
    }
    
    enum DataType: String, CaseIterable, Identifiable {
        case tmiPlans = "TMI Plans"
        case interests = "Interests"
        case hobbies = "Hobbies"
        case resources = "Resources"
        case forms = "Forms"
        
        var id: String { rawValue }
        var description: String {
            switch self {
            case .tmiPlans: return "All TMI intervention plans and progress tracking"
            case .interests: return "Student interests database and categorizations"
            case .hobbies: return "Student hobbies database and educational activities"
            case .resources: return "Educational resources and materials library"
            case .forms: return "Custom forms, surveys, and submission data"
            }
        }
        
        var icon: String {
            switch self {
            case .tmiPlans: return "brain.head.profile"
            case .interests: return "star.fill"
            case .hobbies: return "gamecontroller.fill"
            case .resources: return "books.vertical.fill"
            case .forms: return "doc.text.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.base)
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
                    .foregroundColor(Color.tmiTextPrimary)
                }
            }
            .fileExporter(
                isPresented: $isPresentingExporter,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFilename
            ) { result in
                isExporting = false
                switch result {
                case .success:
                    exportComplete = true
                case .failure(let error):
                    exportErrorMessage = error.localizedDescription
                }
            }
            .alert(
                "Export Failed",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "Please try again.")
            }
        }
    }
    
    private var headerView: some View {
        TMICard(style: .default) {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.tmiSecondary)
                
                Text("Export Your TMI Data")
                    .font(.title2.bold())
                    .foregroundColor(Color.tmiTextPrimary)
                
                Text("Download your data in various formats for backup, analysis, or migration to other systems.")
                    .font(.body)
                    .foregroundColor(Color.tmiTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Formats")
                .font(.headline.bold())
                .foregroundColor(Color.tmiTextPrimary)
            
            TMICard(style: .default) {
                VStack(spacing: 0) {
                    ForEach(ExportFormat.allCases) { format in
                        ExportFormatRow(
                            format: format,
                            isSelected: selectedFormats.contains(format)
                        ) {
                            selectedFormats = [format]
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
                .foregroundColor(Color.tmiTextPrimary)
            
            TMICard(style: .default) {
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
                TMICard(style: .default) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export Complete")
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)
                            
                            Text("Your data has been successfully exported")
                                .font(.body)
                                .foregroundColor(Color.tmiTextSecondary)
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
                Text("This will export \(selectedDataTypes.count) data types as \(selectedFormats.first?.rawValue ?? "a file")")
                    .font(.caption)
                    .foregroundColor(Color.tmiTextSecondary)
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
            
            guard let format = selectedFormats.first else {
                isExporting = false
                return
            }
            let normalizedExportData = try jsonSafeDictionary(exportData)
            guard JSONSerialization.isValidJSONObject(normalizedExportData) else {
                throw ExportSerializationError.invalidJSONObject
            }
            let prepared = try makeExportFile(
                data: normalizedExportData,
                format: format
            )
            exportDocument = TMIExportDocument(data: prepared.data)
            exportContentType = format.contentType
            exportFilename = prepared.filename
            exportComplete = false
            isPresentingExporter = true
            
        } catch {
            isExporting = false
            exportErrorMessage = error.localizedDescription
        }
    }
    
    private func makeExportFile(
        data: [String: Any],
        format: ExportFormat
    ) throws -> (data: Data, filename: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "TMI_Export_\(timestamp).\(format.fileExtension)"
        
        switch format {
        case .json:
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            return (jsonData, filename)
            
        case .csv:
            let csvContent = convertToCSV(data: data)
            guard let csvData = csvContent.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            return (csvData, filename)
        }
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

    private func jsonSafeDictionary(
        _ dictionary: [String: Any]
    ) throws -> [String: Any] {
        try dictionary.mapValues(jsonSafeValue)
    }

    private func jsonSafeValue(_ value: Any) throws -> Any {
        switch value {
        case let value as Date:
            return ISO8601DateFormatter().string(from: value)
        case let value as Timestamp:
            return ISO8601DateFormatter().string(from: value.dateValue())
        case let value as GeoPoint:
            return [
                "latitude": value.latitude,
                "longitude": value.longitude,
            ]
        case let value as DocumentReference:
            return ["path": value.path]
        case let value as Data:
            return ["base64": value.base64EncodedString()]
        case let value as URL:
            return value.absoluteString
        case let value as [String: Any]:
            return try jsonSafeDictionary(value)
        case let value as [Any]:
            return try value.map(jsonSafeValue)
        case is NSNull, is String, is NSNumber:
            return value
        default:
            throw ExportSerializationError.unsupportedValue(
                String(reflecting: type(of: value))
            )
        }
    }
    
}

enum ExportSerializationError: LocalizedError {
    case invalidJSONObject
    case unsupportedValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSONObject:
            return "The selected records could not be converted to a safe export."
        case .unsupportedValue(let type):
            return "The export contains an unsupported value type: \(type)."
        }
    }
}

struct TMIExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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
                        .foregroundColor(Color.tmiTextPrimary)
                    
                    Text(format.description)
                        .font(.system(size: 14))
                        .foregroundColor(Color.tmiTextSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .tmiSecondary : Color.tmiTextTertiary)
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
                        .foregroundColor(Color.tmiTextPrimary)
                    
                    Text(dataType.description)
                        .font(.system(size: 14))
                        .foregroundColor(Color.tmiTextSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .tmiSecondary : Color.tmiTextTertiary)
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
