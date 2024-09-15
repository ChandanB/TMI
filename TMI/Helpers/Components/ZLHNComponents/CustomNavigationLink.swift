//
//  CustomNavigationLink.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct CustomNavigationLink<Destination: View, Label: View>: View {
    let destination: Destination
    let label: () -> Label
    var action: (() -> Void)?
    
    var body: some View {
        NavigationLink(destination: destination) {
            label()
        }
        .simultaneousGesture(TapGesture().onEnded {
            action?()
        })
    }
}

