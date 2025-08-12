//
//  FormStoreView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/26/24.
//

import SwiftUI
import SDWebImageSwiftUI
import Observation

@Observable
class FormStoreViewModel {
    var formTemplates: [FormTemplate] = []
    var isLoading: Bool = false
    var errorMessage: String?

    func loadTemplates() {
        formTemplates = [
            DefaultFormTemplates.camperRegistrationFormTemplate,
            DefaultFormTemplates.jobApplicationFormTemplate,
            FormTemplate(
            name: "Student Interest Survey",
            templateDescription: "Comprehensive survey to identify student interests, hobbies, and career aspirations to help develop personalized TMI plans.",
            sections: [
                FormSection(title: "Personal Interests", fields: [
                    FormField(label: "What are your favorite subjects?", type: .multipleChoice, isRequired: true, options: ["Math", "Science", "English", "History", "Art", "Music", "Physical Education", "Other"]),
                    FormField(label: "Describe your ideal learning environment", type: .longText, isRequired: false)
                ]),
                FormSection(title: "Career Aspirations", fields: [
                    FormField(label: "What careers are you interested in exploring?", type: .multipleChoice, isRequired: true, options: ["Healthcare", "Technology", "Education", "Business", "Arts", "Trades", "Science", "Other"]),
                    FormField(label: "Do you have any specific career goals?", type: .longText, isRequired: false)
                ])
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            category: "Survey"
        ),
        FormTemplate(
            name: "Academic Progress Tracker",
            templateDescription: "Track student academic progress across subjects and identify areas that align with their interests and strengths.",
            sections: [
                FormSection(title: "Current Academic Performance", fields: [
                    FormField(label: "Subject Grades", type: .table, isRequired: true),
                    FormField(label: "Strengths and Challenges", type: .longText, isRequired: true)
                ]),
                FormSection(title: "Interest Alignment", fields: [
                    FormField(label: "How do current academic subjects align with interests?", type: .rating, isRequired: true),
                    FormField(label: "Additional notes", type: .longText, isRequired: false)
                ])
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            category: "Assessment"
        ),
        FormTemplate(
            name: "TMI Plan Feedback",
            templateDescription: "Collect feedback from students on their TMI plans to measure effectiveness and make adjustments as needed.",
            sections: [
                FormSection(title: "Plan Evaluation", fields: [
                    FormField(label: "How helpful has your TMI plan been?", type: .rating, isRequired: true),
                    FormField(label: "What aspects of your TMI plan have been most beneficial?", type: .longText, isRequired: true),
                    FormField(label: "What improvements would you suggest?", type: .longText, isRequired: true)
                ]),
                FormSection(title: "Future Goals", fields: [
                    FormField(label: "What additional interests would you like to explore?", type: .longText, isRequired: false),
                    FormField(label: "How can we better support your academic journey?", type: .longText, isRequired: false)
                ])
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true,
            category: "Feedback"
        ),
        FormTemplate(
            name: "Behavior Tracking Form",
            templateDescription: "Document student behavior patterns to identify triggers and develop appropriate intervention strategies.",
            sections: [
                FormSection(title: "Behavior Observation", fields: [
                    FormField(label: "Date and Time", type: .date, isRequired: true),
                    FormField(label: "Setting/Location", type: .text, isRequired: true),
                    FormField(label: "Observed Behavior", type: .longText, isRequired: true),
                    FormField(label: "Apparent Triggers", type: .multipleChoice, isRequired: true, options: ["Academic Frustration", "Peer Interaction", "Environmental Factors", "Unknown", "Other"])
                ]),
                FormSection(title: "Intervention", fields: [
                    FormField(label: "Strategies Applied", type: .multipleChoice, isRequired: true, options: ["Redirection", "Break Time", "Discussion", "Reflection Activity", "Other"]),
                    FormField(label: "Outcome", type: .longText, isRequired: true)
                ])
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: false,
            category: "Assessment"
        )]
    }
    
    func addTemplate(_ template: FormTemplate) {
        formTemplates.append(template)
    }
}

struct FormStoreView: View {
    @State var viewModel = FormStoreViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20) {
                ForEach(viewModel.formTemplates) { template in
                    NavigationLink(destination: FormTemplateDetailView(template: template)) {
                        FormStoreCardView(template: template)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
        .navigationTitle("Form Store")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6).edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.loadTemplates()
        }
    }
}

struct FormStoreCell: View {
    var template: FormTemplate

    var body: some View {
        HStack {
//            WebImage(urlString: template.imageName)
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//                .frame(width: 80, height: 80)
//                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text(template.templateDescription)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(template.category ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            if !(template.isFree ?? true) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// MARK: - Helper Views
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.tmiSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct SectionPreviewRow: View {
    let section: FormSection
    let index: Int
    
    var body: some View {
        HStack {
            Text("\(index).")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.tmiSecondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("\(section.fields.count) fields")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    FormStoreView()
}
