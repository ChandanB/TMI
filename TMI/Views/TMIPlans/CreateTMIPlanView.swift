//
//  CreateTMIPlanView.swift
//  TMI
//
//  Created by Chandan Brown on 8/12/25.
//

import SwiftUI

struct CreateTMIPlanView: View {
    let student: Student
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text("Create TMI Plan for \(student.name)")
    }
}
