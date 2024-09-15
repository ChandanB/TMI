//
//  FormElementFactory.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Foundation
import SwiftUI

class FormElementFactory {
    static func view(for field: FormField) -> some View {
        switch field.type {
        case .text:
            return AnyView(TextField(field.label, text: .constant("")))
            // Bind text to a dynamic property in your view model
        case .dateTime, .date:
            return AnyView(DatePicker(field.label, selection: .constant(Date())))
            // Similarly, bind the selection
        // Add other cases as needed
        default:
            return AnyView(Text("Unsupported field type"))
        }
    }
}
