import SwiftUI

struct StudentHeaderView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.programContext) private var programContext

    let header: StudentHeaderProjection

    private var programProfile: ProgramProfile {
        programContext.profile(forSchoolID: header.schoolID)
    }

    private var terminology: Terminology { programProfile.terminology }
    let isOffline: Bool
    let isMutating: Bool
    let onEdit: (() -> Void)?
    let onArchive: (() -> Void)?
    let onLaunchStudentMode: (() -> Void)?

    @State private var showingArchiveConfirmation = false

    init(
        header: StudentHeaderProjection,
        isOffline: Bool,
        isMutating: Bool,
        onEdit: (() -> Void)? = nil,
        onArchive: (() -> Void)? = nil,
        onLaunchStudentMode: (() -> Void)? = nil
    ) {
        self.header = header
        self.isOffline = isOffline
        self.isMutating = isMutating
        self.onEdit = onEdit
        self.onArchive = onArchive
        self.onLaunchStudentMode = onLaunchStudentMode
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
                TMIAvatar(initials: initials, size: dynamicTypeSize.isAccessibilitySize ? 56 : 68)

                VStack(alignment: .leading, spacing: 6) {
                    Text(header.displayName)
                        .font(.tmiEditorial(.title))
                        .foregroundStyle(TMIColors.textPrimary)

                    Text("\(terminology.gradeDescription(header.grade)) · \(programContext.siteName(header.schoolID))")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)

                    FlowLayout(spacing: TMISpacing.sm) {
                        TMIStatusBadge(assignedStaffDescription, tone: .info, systemImage: "person.2.fill")
                        switch header.activePlanStatus {
                        case .unavailable:
                            TMIStatusBadge("Plan status unavailable", tone: .neutral, systemImage: "questionmark.circle")
                        case .none:
                            TMIStatusBadge("No active plans", tone: .neutral, systemImage: "minus.circle")
                        case .active(let count):
                            TMIStatusBadge(activePlanDescription(count: count), tone: .success, systemImage: "checkmark.circle.fill")
                        }
                    }
                    .padding(.top, 2)

                    if let lastInteractionAt = header.lastInteractionAt {
                        Text("Last interaction \(lastInteractionAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(TMIColors.textTertiary)
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
                    .buttonStyle(.tmiSecondary)
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
                    .buttonStyle(.tmiDestructive)
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
        .tmiSurface(padding: TMISpacing.ml)
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
        Button {
            onLaunchStudentMode?()
        } label: {
            HStack(spacing: TMISpacing.ms) {
                TMIIconTile("person.crop.circle.badge.clock", tone: .brand, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(terminology.learnerMode)
                        .font(.headline)
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(studentModeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                }
                Spacer(minLength: 0)
                Text("Launch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TMIColors.accent)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TMIColors.textTertiary)
            }
            .padding(.horizontal, TMISpacing.ms)
            .padding(.vertical, TMISpacing.sm)
            .frame(maxWidth: .infinity, minHeight: TMISizing.minTouchTarget)
            .background(TMIColors.surfaceSecondary, in: TMIShape.control)
            .overlay {
                TMIShape.control.strokeBorder(TMIColors.separator, lineWidth: 1)
            }
            .contentShape(TMIShape.control)
        }
        .buttonStyle(.tmiPressable)
        .disabled(isOffline || isMutating || onLaunchStudentMode == nil || !isOldEnoughForLearnerMode)
        .accessibilityLabel("Student Mode")
        .accessibilityValue(studentModeAccessibilityValue)
        .accessibilityHint("Opens the secure Student Mode activity picker.")
        .accessibilityIdentifier("studentDetail.studentMode")
    }

    /// Infants, toddlers, and twos are observed by caregivers, never asked.
    private var isOldEnoughForLearnerMode: Bool {
        guard !programProfile.learnerSelfReports else { return true }
        return AgeGroup(rawValue: header.grade)?.supportsPictureChoice ?? true
    }

    private var studentModeSubtitle: String {
        if programProfile.learnerSelfReports {
            return "One student and one assigned activity"
        }
        return isOldEnoughForLearnerMode
            ? "A caregiver-held picture activity for one child"
            : "Starts at age 3 — record interest observations instead"
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
            onLaunchStudentMode == nil || !isOldEnoughForLearnerMode ? "Unavailable" : "Available"
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
