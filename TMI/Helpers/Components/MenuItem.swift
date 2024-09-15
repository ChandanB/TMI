//
//  MenuItem.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct MenuItem {
    let name: String
    let icon: String
    let destination: AnyView
}

struct MenuItemView: View {
    var item: MenuItem
    
    var body: some View {
        HStack {
            Image(systemName: "item.icon")
                .font(.largeTitle)
                .foregroundColor(Color("AccentColor"))
                .frame(width: 60, height: 60)
                .background(Color("AccentBackground"))
                .cornerRadius(15)
            
            Text(item.name)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(Color.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
