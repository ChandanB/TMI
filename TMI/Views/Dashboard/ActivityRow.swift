//
//  ActivityRow.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct ActivityRow: View {
    let activity: RecentActivity
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: activity.icon)
                .font(.title2)
                .foregroundColor(.tmiPrimary)
                .frame(width: 40, height: 40)
                .background(Color.tmiPrimary.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.headline)
                    .foregroundColor(.tmiText)
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(activity.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    ActivityRow(activity: RecentActivity.sampleRecentActivity)
}
