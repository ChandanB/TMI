//
//  DashboardEngagementChart.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI
import Charts

struct DashboardEngagementChart: View {
    let data: [EngagementData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Engagement")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)
                    
                    Text("Student interactions over the last 7 days")
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextSecondary)
                }
                
                Spacer()
                
                // Timeframe selector could go here
            }
            
            Chart(data) { item in
                BarMark(
                    x: .value("Week", item.week),
                    y: .value("Engagement", item.engagementLevel)
                )
                .foregroundStyle(Color.tmiPrimary.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .tmiCard(style: .elevated)
    }
}
