//
//  FormStoreView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/26/24.
//

import SwiftUI
import SDWebImageSwiftUI
import Observation

// FormStoreViewModel is defined in FormStoreViewModel.swift
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
