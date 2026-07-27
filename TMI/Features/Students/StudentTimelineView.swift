import SwiftUI

struct StudentTimelineView: View {
    let privateNotes:
        StudentDetailRelatedRecords<StudentPrivateNoteProjection>
    let studentReflections:
        StudentDetailRelatedRecords<StudentReflectionProjection>

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Label("Timeline", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.title3)
                .bold()
                .foregroundStyle(TMIColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if let nextAvailableRelease {
                VStack(spacing: TMISpacing.sm) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.title)
                        .foregroundStyle(TMIColors.teal)
                        .accessibilityHidden(true)

                    Text(
                        "Timeline available in Release \(nextAvailableRelease)"
                    )
                    .font(.headline)
                    .foregroundStyle(TMIColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(
                        "studentDetail.timeline.unavailable"
                    )

                    Text(
                        "Private staff notes and student reflections are not loaded in this release."
                    )
                    .font(.body)
                    .foregroundStyle(TMIColors.textSecondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(TMISpacing.lg)
            }

            if entries.isEmpty, nextAvailableRelease == nil {
                ContentUnavailableView(
                    "No timeline activity",
                    systemImage: "clock",
                    description: Text(
                        "Private staff notes and student reflections will appear here when they are recorded."
                    )
                )
                .accessibilityIdentifier("studentDetail.timeline.empty")
            } else {
                LazyVStack(alignment: .leading, spacing: TMISpacing.sm) {
                    ForEach(entries) { entry in
                        HStack(alignment: .top, spacing: TMISpacing.md) {
                            Image(systemName: entry.systemImage)
                                .font(.headline)
                                .foregroundStyle(entry.foregroundStyle)
                                .frame(
                                    minWidth: TMISizing.minTouchTarget,
                                    minHeight: TMISizing.minTouchTarget
                                )
                                .background(
                                    entry.backgroundStyle,
                                    in: Circle()
                                )
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: TMISpacing.xs) {
                                Text(entry.typeLabel)
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(entry.foregroundStyle)

                                Text(entry.summary)
                                    .font(.body)
                                    .foregroundStyle(TMIColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(
                                    entry.occurredAt,
                                    format: .dateTime
                                        .month(.abbreviated)
                                        .day()
                                        .year()
                                        .hour()
                                        .minute()
                                )
                                .font(.footnote)
                                .foregroundStyle(TMIColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(TMISpacing.md)
                        .background(
                            TMIColors.surface,
                            in: RoundedRectangle(cornerRadius: TMIRadius.lg)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: TMIRadius.lg)
                                .stroke(TMIColors.border, lineWidth: 1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(entry.accessibilitySummary)
                        .accessibilityIdentifier(entry.accessibilityIdentifier)
                    }
                }
            }
        }
        .accessibilityIdentifier("studentDetail.timeline")
    }

    private var entries: [TimelineEntry] {
        let notes = privateNotes.records.map(TimelineEntry.privateNote)
        let reflections = studentReflections.records.map(
            TimelineEntry.studentReflection
        )
        return (notes + reflections).sorted {
            if $0.occurredAt == $1.occurredAt {
                $0.id < $1.id
            } else {
                $0.occurredAt > $1.occurredAt
            }
        }
    }

    private var nextAvailableRelease: Int? {
        [
            unavailableRelease(in: privateNotes),
            unavailableRelease(in: studentReflections),
        ]
        .compactMap(\.self)
        .min()
    }

    private func unavailableRelease<Record>(
        in records: StudentDetailRelatedRecords<Record>
    ) -> Int? {
        switch records {
        case .unavailable(let nextAvailableRelease):
            nextAvailableRelease
        case .available:
            nil
        }
    }

    private enum TimelineEntry: Identifiable {
        case privateNote(StudentPrivateNoteProjection)
        case studentReflection(StudentReflectionProjection)

        var id: String {
            switch self {
            case .privateNote(let note):
                "private-note-\(note.id)"
            case .studentReflection(let reflection):
                "student-reflection-\(reflection.id)"
            }
        }

        var summary: String {
            switch self {
            case .privateNote(let note):
                note.summary
            case .studentReflection(let reflection):
                reflection.summary
            }
        }

        var occurredAt: Date {
            switch self {
            case .privateNote(let note):
                note.occurredAt
            case .studentReflection(let reflection):
                reflection.occurredAt
            }
        }

        var typeLabel: String {
            switch self {
            case .privateNote:
                "Private staff note"
            case .studentReflection:
                "Student reflection"
            }
        }

        var systemImage: String {
            switch self {
            case .privateNote:
                "lock.doc"
            case .studentReflection:
                "quote.bubble"
            }
        }

        var foregroundStyle: Color {
            switch self {
            case .privateNote:
                TMIColors.aubergine
            case .studentReflection:
                TMIColors.teal
            }
        }

        var backgroundStyle: Color {
            switch self {
            case .privateNote:
                TMIColors.aubergineSoft
            case .studentReflection:
                TMIColors.infoSurface
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .privateNote(let note):
                "studentDetail.timeline.privateNote.\(note.id)"
            case .studentReflection(let reflection):
                "studentDetail.timeline.studentReflection.\(reflection.id)"
            }
        }

        var accessibilitySummary: String {
            [
                typeLabel,
                summary,
                occurredAt.formatted(date: .abbreviated, time: .shortened),
            ].joined(separator: ", ")
        }
    }
}
