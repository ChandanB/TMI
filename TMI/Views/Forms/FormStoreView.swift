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

    func loadTemplates() {
        formTemplates = [DefaultFormTemplates.camperRegistrationFormTemplate, DefaultFormTemplates.jobApplicationFormTemplate]
    }
}

struct FormStoreView: View {
    @State var viewModel = FormStoreViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20) {
                ForEach(viewModel.formTemplates) { template in
                    CustomNavigationLink(destination: FormTemplateDetailView(template: template)) {
                        FormStoreCardView(template: template)
                    }
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

struct FormStoreCardView: View {
    var template: FormTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WebImage(url: URL(string: template.imageName ?? ""))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .cornerRadius(15)
                .clipped()

            Text(template.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(template.templateDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack {
                if let category = template.category {
                    TagView(title: category)
                }

                Spacer()

                if let isFree = template.isFree, !isFree {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    FormStoreView()
}

//struct FormTemplateDetailView: View {
//    var template: FormTemplate
//    @State private var isAddingTemplate = false
//
//    var body: some View {
//        FormPreviewView(template: template)
//            .navigationTitle(template.name)
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        Task {
//                            await saveTemplateToMyCollection()
//                        }
//                    }) {
//                        if isAddingTemplate {
//                            ProgressView()
//                        } else {
//                            Text("Add")
//                        }
//                    }
//                    .disabled(isAddingTemplate)
//                }
//            }
//    }
//    
//    private func saveTemplateToMyCollection() async {
//        isAddingTemplate = true
////        do {
////            guard let userId = try await FIREBASE_MANAGER.fetchCurrentUser().id else { return }
////            try await FIREBASE_MANAGER.addFormTemplateToUserCollection(formTemplateId: template.id ?? "", userId: userId)
////            isAddingTemplate = false
////        } catch {
////            isAddingTemplate = false
////        }
//    }
//}
