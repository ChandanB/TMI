//
//  TMIPlanCard.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import SwiftUI

struct TMIPlanCard: View {
    let plan: TMIPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Plan Model and Progress
            HStack {
                Text(plan.model.rawValue)
                    .font(.headline)
                    .foregroundColor(Color.tmiPrimary)
                Spacer()
                Text("\(Int(plan.progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(Color.tmiSecondary)
            }

            // Progress Bar
            ProgressBar(progress: plan.progress)
                .frame(height: 8)

            // Plan Description
            Text(plan.model.description)
                .font(.body)
                .foregroundColor(Color.tmiText)
                .lineLimit(2)

            // Associated Students
            HStack(spacing: -10) {
                ForEach(plan.students.prefix(3)) { student in
                    AvatarView(student: student)
                }
                if plan.students.count > 3 {
                    Text("+\(plan.students.count - 3)")
                        .font(.caption)
                        .foregroundColor(Color.tmiSecondary)
                        .padding(.leading, 5)
                }
                Spacer()
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
