import SwiftUI

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let accentBorderColor: Color
    let badge: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        accentBorderColor: Color? = nil,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.accentBorderColor = accentBorderColor ?? iconColor
        self.badge = badge
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 44, height: 44)
                        .background(iconColor.opacity(0.14), in: Circle())

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(.tmiCaption.bold())
                            .foregroundColor(.tmiTextOnPrimary)
                            .padding(.horizontal, TMISpacing.sm)
                            .padding(.vertical, 4)
                            .background(iconColor, in: Capsule())
                    }
                }

                Text(title)
                    .font(.tmiBody.bold())
                    .foregroundColor(.tmiTextPrimary)

                Text(subtitle)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(TMISpacing.md)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(Color.tmiSurface)
            .clipShape(RoundedRectangle(cornerRadius: TMIRadius.md))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(accentBorderColor)
                    .frame(width: 3)
            }
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionsGrid: View {
    @Environment(AppRouter.self) private var router

    let data: DashboardData

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Quick Actions")
                .font(.tmiTitle3.bold())
                .foregroundColor(.tmiTextPrimary)

            Divider()

            if let action = data.nextBestAction {
                NextBestActionCard(action: action) {
                    handle(action)
                }
            }

            QuickActionCard(
                title: data.totalStudents == 0 ? "Add First Student" : "Manage Students",
                subtitle: "Open the secure district roster",
                icon: "person.3.fill",
                iconColor: .tmiPrimary,
                badge: data.totalStudents == 0 ? nil : "\(data.totalStudents)",
                action: { try? router.select(.students) }
            )

            QuickActionCard(
                title: "TMI Plans",
                subtitle: "View and manage canonical TMI plans",
                icon: "doc.text.fill",
                iconColor: .tmiSecondary,
                badge: data.activeTMIPlans == 0 ? nil : "\(data.activeTMIPlans)",
                action: { try? router.select(.plans) }
            )
        }
    }

    private func handle(_ action: NextBestAction) {
        switch action.type {
        case .createPlan, .reviewPlan, .pendingApproval:
            try? router.select(.plans)
        case .scheduleMeeting, .completeNotes, .addInterests, .checkProgress:
            try? router.select(.students)
        }
    }
}

/// Release 1 intentionally does not convert a canonical `StudentRecord` into
/// the broader legacy `Student` plan payload. Plan creation resumes when the
/// canonical plan repository ships in Release 3.
struct StudentSelectorForPlanView: View {
    @Environment(\.dismiss) private var dismiss

    private let onStudentSelected: (Student) -> Void
    private let onPlanCreated: (() -> Void)?

    init(
        onStudentSelected: @escaping (Student) -> Void,
        onPlanCreated: (() -> Void)? = nil
    ) {
        self.onStudentSelected = onStudentSelected
        self.onPlanCreated = onPlanCreated
    }

    var body: some View {
        TMIEmptyState(
            icon: "calendar.badge.clock",
            title: "Plan creation coming soon",
            message: "The secure roster is ready. Plan creation will reopen when plans use the same canonical district records.",
            action: { dismiss() },
            actionLabel: "Done"
        )
        .navigationTitle("Create Plan")
        .onAppear {
            _ = onStudentSelected
            _ = onPlanCreated
        }
    }
}

#Preview {
    NavigationStack {
        QuickActionsGrid(
            data: DashboardData(
                totalStudents: 12,
                activeTMIPlans: 4
            )
        )
        .padding()
    }
    .environment(AppRouter())
}
