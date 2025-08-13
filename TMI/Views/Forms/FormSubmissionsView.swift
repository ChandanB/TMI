//
//  FormSubmissionsView.swift
//  TMI
//
//  Created by Chandan Brown on 8/11/25.
//

import SwiftUI
import Observation

@Observable
class FormSubmissionsViewModel {
    var submissions: [FormSubmission] = []
    var templates: [String: FormTemplate] = [:]
    var isLoading = false
    var errorMessage: String?
    
    func loadSubmissions(for studentId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            submissions = try await FIREBASE_MANAGER.fetchStudentFormSubmissions(studentId: studentId)
            await loadTemplatesForSubmissions()
        } catch {
            errorMessage = "Failed to load form submissions: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadUserSubmissions(for userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            submissions = try await FIREBASE_MANAGER.fetchUserFormSubmissions(userId: userId)
            await loadTemplatesForSubmissions()
        } catch {
            errorMessage = "Failed to load form submissions: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func loadTemplatesForSubmissions() async {
        let templateIds = Set(submissions.map { $0.formId })
        
        for templateId in templateIds {
            do {
                let template: FormTemplate = try await FIREBASE_MANAGER.fetchDocument(
                    inCollection: .formTemplates,
                    withId: templateId
                )
                templates[templateId] = template
            } catch {
                print("Failed to load template \(templateId): \(error)")
            }
        }
    }
}

struct FormSubmissionsView: View {
    let studentId: String?
    let userId: String?
    @State private var viewModel = FormSubmissionsViewModel()
    @State private var selectedSubmission: FormSubmission?
    
    init(studentId: String) {
        self.studentId = studentId
        self.userId = nil
    }
    
    init(userId: String) {
        self.studentId = nil
        self.userId = userId
    }
    
    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading submissions...")
                        .foregroundColor(.white)
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    ErrorView(message: errorMessage) {
                        Task { await loadSubmissions() }
                    }
                    Spacer()
                } else if viewModel.submissions.isEmpty {
                    EmptySubmissionsView()
                } else {
                    submissionsList
                }
            }
        }
        .navigationTitle("Form Submissions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSubmissions()
        }
        .refreshable {
            await loadSubmissions()
        }
        .sheet(item: $selectedSubmission) { submission in
            FormSubmissionDetailView(
                submission: submission,
                template: viewModel.templates[submission.formId]
            )
        }
    }
    
    private var submissionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.submissions, id: \.id) { submission in
                    FormSubmissionCard(
                        submission: submission,
                        template: viewModel.templates[submission.formId]
                    ) {
                        selectedSubmission = submission
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    private func loadSubmissions() async {
        if let studentId = studentId {
            await viewModel.loadSubmissions(for: studentId)
        } else if let userId = userId {
            await viewModel.loadUserSubmissions(for: userId)
        }
    }
}

struct FormSubmissionCard: View {
    let submission: FormSubmission
    let template: FormTemplate?
    let onTap: () -> Void
    
    var body: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template?.name ?? "Unknown Form")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let category = template?.category {
                            Text(category)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.tmiSecondary.opacity(0.3))
                                )
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.tmiSecondary)
                        
                        Text(submissionDate)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Quick Stats
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.square")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(submissionDataCount) responses")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if let submitterRole = submission.data["submitterRole"]?.value as? String {
                        Text(submitterRole.capitalized)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                // Action
                TMIButton(text: "View Details", style: .secondary) {
                    onTap()
                }
            }
            .padding(20)
        }
    }
    
    private var submissionDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: submission.submissionDate)
    }
    
    private var submissionDataCount: Int {
        submission.data.filter { !["submittedBy", "submitterRole"].contains($0.key) }.count
    }
}

struct FormSubmissionDetailView: View {
    let submission: FormSubmission
    let template: FormTemplate?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        TMIGlassCard(style: .elevated) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(template?.name ?? "Form Submission")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Text("Submitted \(submissionDateFormatted)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.tmiSecondary)
                                }
                                
                                if let template = template {
                                    Text(template.templateDescription)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(20)
                        }
                        
                        // Submission Data
                        if let template = template {
                            ForEach(template.sections, id: \.id) { section in
                                FormSubmissionSectionView(
                                    section: section,
                                    submissionData: submission.data
                                )
                            }
                        } else {
                            // Fallback for when template is not available
                            TMIGlassCard(style: .elevated) {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Raw Submission Data")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    ForEach(Array(submission.data.keys.sorted()), id: \.self) { key in
                                        if !["submittedBy", "submitterRole"].contains(key) {
                                            SubmissionDataRow(
                                                key: key,
                                                value: submission.data[key]?.value
                                            )
                                        }
                                    }
                                }
                                .padding(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Submission Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var submissionDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: submission.submissionDate)
    }
}

struct FormSubmissionSectionView: View {
    let section: FormSection
    let submissionData: [String: AnyCodable]
    
    var body: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                Text(section.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                ForEach(section.fields, id: \.id) { field in
                    if let fieldId = field.id, 
                       let value = submissionData[fieldId] {
                        SubmissionFieldView(field: field, value: value)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct SubmissionFieldView: View {
    let field: FormField
    let value: AnyCodable
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Text(formattedValue)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
    
    private var formattedValue: String {
        switch field.type {
        case .date, .dateTime:
            if let date = value.value as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = field.type == .date ? .medium : .short
                formatter.timeStyle = field.type == .dateTime ? .short : .none
                return formatter.string(from: date)
            }
        case .multipleChoice:
            if let options = value.value as? [String] {
                return options.joined(separator: ", ")
            }
        case .checkbox:
            if let bool = value.value as? Bool {
                return bool ? "Yes" : "No"
            }
        case .rating:
            if let rating = value.value as? Int {
                return String(repeating: "⭐", count: rating)
            }
        default:
            break
        }
        
        return String(describing: value.value)
    }
}

struct SubmissionDataRow: View {
    let key: String
    let value: Any?
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Text(String(describing: value ?? ""))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 4)
    }
}

struct EmptySubmissionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Form Submissions")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Form submissions will appear here once they are created.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.8))
            
            Text("Error")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            TMIButton(text: "Retry", style: .secondary) {
                retryAction()
            }
        }
        .padding()
    }
}

#Preview {
    FormSubmissionsView(studentId: "sample-student-id")
}