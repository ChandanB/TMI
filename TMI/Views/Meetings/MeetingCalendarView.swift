//
//  MeetingCalendarView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #7
//  Calendar view for visualizing meetings
//

import SwiftUI

struct MeetingCalendarView: View {
    let meetings: [Meeting]

    @Environment(\.dismiss) private var dismiss
    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var selectedMeeting: Meeting?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Month selector
            monthSelector

            // Day headers
            dayHeaders

            // Calendar grid
            calendarGrid

            // Selected date meetings
            if let selectedDate = selectedDate {
                selectedDateMeetings(for: selectedDate)
            }
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Today") {
                    currentMonth = Date()
                    selectedDate = Date()
                }
                .foregroundColor(.cyan)
            }
        }
        .sheet(item: $selectedMeeting) { meeting in
            NavigationStack {
                MeetingDetailView(meeting: meeting, onUpdate: {})
            }
            .tmiSheetStyle()
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color.tmiTextPrimary)
                    .padding(8)
                    .background(Circle().fill(Color.tmiSurface))
            }

            Spacer()

            Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
                .foregroundColor(Color.tmiTextPrimary)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.tmiTextPrimary)
                    .padding(8)
                    .background(Circle().fill(Color.tmiSurface))
            }
        }
        .padding()
    }

    // MARK: - Day Headers

    private var dayHeaders: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundColor(Color.tmiTextSecondary)
                    .frame(height: 30)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(daysInMonth(), id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 60)
                }
            }
        }
        .padding()
    }

    private func dayCell(for date: Date) -> some View {
        let meetingsForDate = meetings(on: date)
        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
        let isToday = calendar.isDateInToday(date)

        return Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.bold())
                    .foregroundColor(isToday ? .cyan : Color.tmiTextPrimary)

                if !meetingsForDate.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(meetingsForDate.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.cyan.opacity(0.3) : (isToday ? Color.cyan.opacity(0.1) : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.cyan : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Date Meetings

    private func selectedDateMeetings(for date: Date) -> some View {
        let dayMeetings = meetings(on: date)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                    .foregroundColor(Color.tmiTextPrimary)

                Spacer()

                Text("\(dayMeetings.count) \(dayMeetings.count == 1 ? "meeting" : "meetings")")
                    .font(.caption)
                    .foregroundColor(Color.tmiTextSecondary)
            }
            .padding(.horizontal)

            if dayMeetings.isEmpty {
                Text("No meetings scheduled")
                    .font(.caption)
                    .foregroundColor(Color.tmiTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(dayMeetings) { meeting in
                            Button(action: { selectedMeeting = meeting }) {
                                CalendarMeetingCard(meeting: meeting)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxHeight: 250)
        .background(Color.tmiSurface)
    }

    // MARK: - Helpers

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) != nil else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0

        var days: [Date?] = []

        // Add leading empty cells
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        for _ in 0..<(firstWeekday - 1) {
            days.append(nil)
        }

        // Add month days
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }

        return days
    }

    private func meetings(on date: Date) -> [Meeting] {
        meetings.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

// MARK: - Supporting Views

private struct CalendarMeetingCard: View {
    let meeting: Meeting

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption.bold())
                    .foregroundColor(.cyan)

                Text(meeting.title)
                    .font(.subheadline)
                    .foregroundColor(Color.tmiTextPrimary)
                    .lineLimit(1)

                if let location = meeting.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(location)
                    }
                    .font(.caption2)
                    .foregroundColor(Color.tmiTextSecondary)
                }
            }

            Spacer()

            Image(systemName: meeting.meetingType.icon)
                .foregroundStyle(Color(hex: meeting.meetingType.color).gradient)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiSurface)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MeetingCalendarView(meetings: [.sampleMeeting])
    }
}
