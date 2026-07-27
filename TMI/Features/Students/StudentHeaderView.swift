import SwiftUI

struct StudentHeaderView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let header: StudentHeaderProjection
    let isOffline: Bool
    let isMutating: Bool
    let onEdit: (() -> Void)?
    let onArchive: (() -> Void)?

    @State private var showingArchiveConfirmation = false

    init(
        header: StudentHeaderProjection,
        isOffline: Bool,
        isMutating: Bool,
        onEdit: (() -> Void)? = nil,
        onArchive: (() -> Void)? = nil
    ) {
        self.header = header
        self.isOffline = isOffline
        self.isMutating = isMutating
        self.onEdit = onEdit
        self.onArchive = onArchive
    }

    var body: some View {
        let identityLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMISpacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: TMISpacing.md))
        let actionLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMISpacing.sm))
            : AnyLayout(HStackLayout(spacing: TMISpacing.sm))

        VStack(alignment: .leading, spacing: TMISpacing.md) {
            identityLayout {
                ZStack {
                    Circle()
                        .fill(TMIColors.aubergineSoft)

                    Text(initials)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(TMIColors.aubergine)
                }
                .frame(width: TMISizing.avatarLg, height: TMISizing.avatarLg)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Text(header.displayName)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(TMIColors.textPrimary)

                    Text("Grade: \(header.grade)")
                        .font(.body)
                        .foregroundStyle(TMIColors.textSecondary)

                    Text("School: \(header.schoolID)")
                        .font(.body)
                        .foregroundStyle(TMIColors.textSecondary)

                    Label(
                        assignedStaffDescription,
                        systemImage: "person.2"
                    )
                    .font(.subheadline)
                    .foregroundStyle(TMIColors.infoText)

                    Group {
                        switch header.activePlanStatus {
                        case .unavailable:
                            Label(
                                "Active plan status unavailable",
                                systemImage: "questionmark.circle"
                            )
                            .foregroundStyle(TMIColors.textSecondary)
                        case .none:
                            Label(
                                "No active plans",
                                systemImage: "minus.circle"
                            )
                            .foregroundStyle(TMIColors.textSecondary)
                        case .active(let count):
                            Label(
                                activePlanDescription(count: count),
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(TMIColors.successText)
                        }
                    }
                    .font(.subheadline)

                    if let lastInteractionAt = header.lastInteractionAt {
                        Label(
                            "Last interaction \(lastInteractionAt.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "clock"
                        )
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                    } else {
                        Label(
                            "No recorded interactions",
                            systemImage: "clock.badge.questionmark"
                        )
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier("studentDetail.header.\(header.studentID)")

            if isOffline {
                Label(
                    "Offline. Student actions are unavailable.",
                    systemImage: "wifi.slash"
                )
                .font(.subheadline)
                .foregroundStyle(TMIColors.warningText)
                .accessibilityIdentifier("studentDetail.header.offline")
            }

            studentModeControl

            actionLayout {
                if let onEdit {
                    Button(
                        "Edit",
                        systemImage: "pencil",
                        action: onEdit
                    )
                    .buttonStyle(.bordered)
                    .tint(TMIColors.aubergine)
                    .disabled(isOffline || isMutating)
                    .accessibilityIdentifier("studentDetail.edit")
                }

                if onArchive != nil {
                    Button(
                        "Archive",
                        systemImage: "archivebox",
                        role: .destructive
                    ) {
                        showingArchiveConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isOffline || isMutating)
                    .accessibilityIdentifier("studentDetail.archive")
                }

                if isMutating {
                    ProgressView("Saving")
                        .controlSize(.small)
                        .accessibilityIdentifier("studentDetail.mutating")
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(TMIColors.surface, in: RoundedRectangle(cornerRadius: TMIRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: TMIRadius.xl)
                .stroke(TMIColors.interactiveBorder, lineWidth: 1)
        }
        .confirmationDialog(
            "Archive \(header.displayName)?",
            isPresented: $showingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            if let onArchive {
                Button(
                    "Archive Student",
                    role: .destructive,
                    action: onArchive
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The student will leave the active roster. The institutional record is retained.")
        }
    }

    private var studentModeControl: some View {
        Button(action: {}) {
            HStack(spacing: TMISpacing.md) {
                Image(systemName: "person.crop.circle.badge.clock")
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: TMISpacing.xxs) {
                    Text("Student Mode")
                        .font(.headline)
                    Text("Available in Release 2")
                        .font(.subheadline)
                }
                Spacer(minLength: 0)
                Text("Unavailable")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(TMIColors.infoText)
            .padding(.horizontal, TMISpacing.md)
            .frame(maxWidth: .infinity, minHeight: TMISizing.minTouchTarget)
            .background(
                TMIColors.infoSurface,
                in: RoundedRectangle(cornerRadius: TMIRadius.lg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TMIRadius.lg)
                    .stroke(TMIColors.interactiveBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(1)
        .accessibilityLabel("Student Mode")
        .accessibilityValue(studentModeAccessibilityValue)
        .accessibilityHint("This control is not available in Release 1.")
        .accessibilityIdentifier("studentDetail.studentMode")
    }

    private var initials: String {
        let value = header.displayName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "?" : value
    }

    private var assignedStaffDescription: String {
        "\(header.assignedStaffCount) assigned \(header.assignedStaffCount == 1 ? "staff member" : "staff members")"
    }

    private func activePlanDescription(count: Int) -> String {
        "\(count) active \(count == 1 ? "plan" : "plans")"
    }

    private var activePlanAccessibilityDescription: String {
        switch header.activePlanStatus {
        case .unavailable:
            "active plan status unavailable"
        case .none:
            "no active plans"
        case .active(let count):
            activePlanDescription(count: count)
        }
    }

    private var lastInteractionAccessibilityDescription: String {
        if let lastInteractionAt = header.lastInteractionAt {
            "last interaction \(lastInteractionAt.formatted(date: .abbreviated, time: .shortened))"
        } else {
            "no recorded interactions"
        }
    }

    private var studentModeAccessibilityValue: String {
        switch header.studentModeAvailability {
        case .availableInRelease2:
            "Available in Release 2"
        }
    }

    private var accessibilitySummary: String {
        [
            header.displayName,
            "grade \(header.grade)",
            "school \(header.schoolID)",
            assignedStaffDescription,
            activePlanAccessibilityDescription,
            lastInteractionAccessibilityDescription,
        ].joined(separator: ", ")
    }
}
