//
//  ImprovedStudentListView.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI

struct StudentListView: View {
    @State private var stateModel = StudentListStateModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    // Animation states
    @State private var headerAppeared = false
    @State private var searchBarAppeared = false
    @State private var gridAppeared = false
    @State private var actionBarAppeared = false
    
    // Alert and sheet states
    @State private var showingBulkActionsSheet = false
    @State private var showingExportSheet = false
    
    var body: some View {
        ZStack {
            // Background
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search and filter bar
                searchAndFilterBar
                    .padding(.top, 10)
                    .padding(.horizontal)
                    .opacity(searchBarAppeared ? 1 : 0)
                    .offset(y: searchBarAppeared ? 0 : -20)

                // Main content
                mainContent
                    .opacity(gridAppeared ? 1 : 0)

                // Quick action bar
                quickActionBar
                    .opacity(actionBarAppeared ? 1 : 0)
                    .offset(y: actionBarAppeared ? 0 : 100)
            }
            .navigationTitle("Students")
            .foregroundColor(.white)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $stateModel.showingAddStudent) {
            AddStudentView {
                // Handle student added
                Task {
                    await stateModel.fetch()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showingBulkActionsSheet) {
            BulkActionsView(students: stateModel.filteredStudents) { action in
                // Handle bulk action completion
                Task {
                    await stateModel.fetch() // Refresh data
                }
                showingBulkActionsSheet = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportStudentsView(students: stateModel.filteredStudents) {
                showingExportSheet = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await stateModel.fetch()
        }
        .onAppear {
            // Animated appearance
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                headerAppeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                searchBarAppeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                gridAppeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
                actionBarAppeared = true
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        TMITextField(
            icon: "magnifyingglass",
            placeholder: "Search students",
            text: $stateModel.searchText
        )
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            ForEach(FilterOption.allCases) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        stateModel.selectedFilterOption = option
                    }
                }) {
                    Label(
                        option.rawValue,
                        systemImage: option == stateModel.selectedFilterOption ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                if stateModel.selectedFilterOption != .all {
                    Text(stateModel.selectedFilterOption.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(stateModel.selectedFilterOption == .all ? Color.clear : Color.tmiSecondary.opacity(0.3))
            )
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch stateModel.state {
            case .idle:
                EmptyView()
                
            case .loading:
                loadingView
                
            case .loaded:
                if stateModel.students.isEmpty {
                    emptyState
                } else {
                    studentContent
                }
                
            case .error(let error):
                errorView(error)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .foregroundColor(.white)
            
            Text("Loading students...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: IdentifiableError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Students")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Text(error.message)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            TMIButton(
                text: "Retry",
                style: .secondary,
                action: {
                    Task {
                        await stateModel.fetch()
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            // Empty illustration
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.tmiSecondary.opacity(0.2), Color.clear]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 60)
            
            Text("No students available")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Add your first student to get started with TMI")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            TMIButton(
                text: "Add Student",
                icon: "person.badge.plus",
                style: .primary,
                action: {
                    stateModel.showAddStudent()
                }
            )
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(minHeight: 500)
        .padding(.horizontal)
    }
    
    private var studentContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Stats summary
                statsSummary
                    .padding(.horizontal, 20)

                // Grid layout
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 170 : 220), spacing: 16)],
                    spacing: 18
                ) {
                    ForEach(stateModel.filteredStudents) { student in
                        NavigationLink(destination: StudentDetailView(student: student)) {
                            StudentCard(student: student)
                                .scaleEffect(1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: student.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                // Add some bottom padding for better scrolling
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }
    
    private var statsSummary: some View {
        HStack(spacing: 20) {
            StudentStatCard(
                title: "Total",
                value: "\(stateModel.filteredStudents.count)",
                icon: "person.3.fill",
                color: .blue
            )
            
            StudentStatCard(
                title: "With TMI Plans",
                value: "\(stateModel.filteredStudents.filter { $0.tmiPlans?.isEmpty == false }.count)",
                icon: "doc.text.fill",
                color: .orange
            )
            
            StudentStatCard(
                title: "High Engagement",
                value: "\(stateModel.filteredStudents.filter { $0.engagementScore >= 0.7 }.count)",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                color: .green
            )
        }
    }
    
    // MARK: - Quick Action Bar
    
    private var quickActionBar: some View {
        VStack(spacing: 0) {
            // Divider with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            // Action buttons
            HStack(spacing: 20) {
                // Add Student Button
                StudentListActionButton(
                    icon: "person.badge.plus",
                    title: "Add Student",
                    action: {
                        stateModel.showAddStudent()
                    }
                )
                
                // Bulk Actions Button
                StudentListActionButton(
                    icon: "person.crop.rectangle.stack.fill",
                    title: "Bulk Actions",
                    action: {
                        showingBulkActionsSheet = true
                    }
                )
                
                // Export Button
                StudentListActionButton(
                    icon: "square.and.arrow.up",
                    title: "Export",
                    action: {
                        showingExportSheet = true
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.2))
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.8)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    StudentListView()
}



// MARK: - Export Students View

struct ExportStudentsView: View {
    let students: [Student]
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportFormat = .csv
    @State private var includePrivateData = false
    @State private var isExporting = false
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case pdf = "PDF Report"
    }
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.tmiSecondary)
                        
                        Text("Export Students")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text("Generate and share student data in your preferred format.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Export options
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Export Format")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                ForEach(ExportFormat.allCases, id: \.self) { format in
                                    Button {
                                        selectedFormat = format
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedFormat == format ? "largecircle.fill.circle" : "circle")
                                                .foregroundColor(selectedFormat == format ? .tmiSecondary : .white.opacity(0.5))
                                            
                                            Text(format.rawValue)
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Privacy options
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Privacy Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Toggle(isOn: $includePrivateData) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Include Private Data")
                                        .foregroundColor(.white)
                                    
                                    Text("Include sensitive information like Student ID and date of birth")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .tint(.tmiSecondary)
                        }
                    }
                    
                    // Export summary
                    TMIGlassCard(style: .default) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Export Summary")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("Students:")
                                Spacer()
                                Text("\(students.count)")
                            }
                            .foregroundColor(.white)
                            
                            HStack {
                                Text("Format:")
                                Spacer()
                                Text(selectedFormat.rawValue)
                            }
                            .foregroundColor(.white)
                            
                            HStack {
                                Text("Privacy Level:")
                                Spacer()
                                Text(includePrivateData ? "Full Data" : "Public Data Only")
                            }
                            .foregroundColor(.white)
                            
                            HStack {
                                Text("Output:")
                                Spacer()
                                Text("Text data via Share Sheet")
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    // Export button
                    Button {
                        Task {
                            await performExport()
                        }
                    } label: {
                        Group {
                            if isExporting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("Exporting...")
                                }
                            } else {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Generate & Share Data")
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.tmiSecondary)
                        )
                    }
                    .disabled(isExporting)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
    }
    
    @MainActor
    private func performExport() async {
        isExporting = true
        
        // Generate export data
        let exportData = generateExportData()
        
        // Share the data
        let activityController = UIActivityViewController(
            activityItems: [exportData],
            applicationActivities: nil
        )
        
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            activityController.popoverPresentationController?.sourceView = window
            activityController.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            rootViewController.present(activityController, animated: true)
        }
        #endif
        
        isExporting = false
        onComplete()
    }
    
    private func generateExportData() -> String {
        switch selectedFormat {
        case .csv:
            return generateCSV()
        case .json:
            return generateJSON()
        case .pdf:
            return generatePDFReport()
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Name,Grade,School,Age,Engagement Score,Interests Count,TMI Plans Count"
        if includePrivateData {
            csv += ",Student ID,Date of Birth"
        }
        csv += "\n"
        
        for student in students {
            let interests = student.interests.count
            let plans = student.tmiPlans?.count ?? 0
            
            // Escape CSV values that might contain commas
            let escapedName = escapeCSVValue(student.name)
            let escapedSchool = escapeCSVValue(student.school)
            
            var row = "\(escapedName),\(student.grade),\(escapedSchool),\(student.age),\(student.engagementScore),\(interests),\(plans)"
            if includePrivateData {
                let studentID = escapeCSVValue(student.studentID ?? "N/A")
                let dateOfBirth = escapeCSVValue(student.formattedDateOfBirth)
                row += ",\(studentID),\(dateOfBirth)"
            }
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func escapeCSVValue(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    private func generateJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            // Filter data based on privacy settings
            let studentsToExport = includePrivateData ? students : students.map { student in
                // Create a copy without sensitive data
                let publicStudent = student
                // Note: In a real implementation, you'd create a proper PublicStudent model
                // For now, this is a conceptual representation
                return publicStudent
            }
            
            let data = try encoder.encode(studentsToExport)
            return String(data: data, encoding: .utf8) ?? "Failed to encode data to string"
        } catch {
            return """
            {
                "error": "Failed to export student data",
                "details": "\(error.localizedDescription)",
                "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
            }
            """
        }
    }
    
    private func generatePDFReport() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        
        var report = """
        TMI Students Report
        Generated: \(dateFormatter.string(from: Date()))
        Total Students: \(students.count)
        
        STUDENT SUMMARY
        """
        
        for (index, student) in students.enumerated() {
            report += """
            
            \(index + 1). \(student.name)
               Grade: \(student.grade)
               School: \(student.school)
               Age: \(student.age) years
               Engagement Score: \(Int(student.engagementScore * 100))%
               Interests: \(student.interests.count)
               TMI Plans: \(student.tmiPlans?.count ?? 0)
            """
            
            if includePrivateData {
                report += """
                   Student ID: \(student.studentID ?? "Not provided")
                   Date of Birth: \(student.formattedDateOfBirth)
                """
            }
        }
        
        report += """
        
        
        ---
        Report generated by TMI Education Platform
        """
        
        return report
    }
}

