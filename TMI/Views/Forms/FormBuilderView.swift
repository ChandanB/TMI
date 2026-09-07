//
//  FormBuilderView.swift
//  TMI
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

/// Hosts the drag-and-drop form builder inside a navigation container so it can
/// be presented as a sheet. The builder itself (`FormTemplateBuilderView`)
/// provides its own title and Save action, which dismisses the sheet.
struct FormBuilderView: View {
  var body: some View {
    NavigationStack {
      FormTemplateBuilderView()
    }
  }
}

#Preview {
    FormBuilderView()
}
