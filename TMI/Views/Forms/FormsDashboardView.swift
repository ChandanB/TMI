//
//  FormDashboardView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/29/24.
//

import SwiftUI

struct FormsDashboardView: View {
    private var menuItems: [MenuItem] {
        [
            MenuItem(name: "My Forms", icon: "doc.on.doc", destination: AnyView(MyFormsView())),
            MenuItem(name: "Form Store", icon: "appstore", destination: AnyView(FormStoreView())),
            MenuItem(name: "Form Builder", icon: "pencil.tip.crop.circle", destination: AnyView(FormTemplateBuilderView())),
        ]
    }

    var body: some View {
        VStack(spacing: 20) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    ForEach(menuItems, id: \.name) { item in
                        CustomNavigationLink(destination: item.destination) {
                            MenuItemView(item: item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Forms Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .background(Color("Background").edgesIgnoringSafeArea(.all))
        }
        .navigationTitle("Forms Dashboard")
    }
}

struct DashboardButton: View {
    var label: String
    var iconName: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.blue)
            Text(label)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

#Preview {
    FormsDashboardView()
}
