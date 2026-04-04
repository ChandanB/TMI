//
//  ConsentManagementView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #8
//  View for managing student consent records across the district
//

import SwiftUI

struct ConsentManagementView: View {
    @Environment(\.authStateModel) private var authState

    @State private var students: [Student] = []
    @State private var consentSummaries: [String: ConsentSummary] = [:] // studentId -> ConsentSummary
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedFilter: ConsentFilter = .all
    @State private var selectedStudent: Student?
    @State private var showingConsentDetail = false

    private let complianceService = ComplianceService.shared

    enum ConsentFilter: String, CaseIterable {
        case all = "All Students"
        case compliant = "Compliant"
        case missingConsents = "Missing Consents"
        case expiredConsents = "Expired Consents"

        var icon: String {
            switch self {
            case .all: return "person.3.fill"
            case .compliant: return "checkmark.seal.fill"
            case .missingConsents: return "exclamationmark.triangle.fill"
            case .expiredConsents: return "clock.badge.exclamationmark.fill"
            }
        }
    }

    var filteredStudents: [Student] {
        var result = students

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { student in
                student.name.localizedCaseInsensitiveContains(searchText) ||
                student.grade.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply consent filter
        switch selectedFilter {
        case .all:
            break
        case .compliant:
            result = result.filter { student in
                guard let summary = consentSummaries[student.id ?? ""] else { return false }
                return summary.allConsentsActive
            }
        case .missingConsents:
            result = result.filter { student in
                guard let summary = consentSummaries[student.id ?? ""] else { return true }
                return !summary.missingConsentTypes.isEmpty
            }
        case .expiredConsents:
            result = result.filter { student in
                guard let summary = consentSummaries[student.id ?? ""] else { return false }
                return summary.expiredConsents > 0
            }
        }

        return result.sorted { $0.name < $1.name }
    }

    var overallStatistics: (total: Int, compliant: Int, missingConsents: Int, expiredConsents: Int) {
        let total = students.count
        var compliant = 0
        var missingConsents = 0
        var expiredConsents = 0

        for student in students {
            guard let studentId = student.id,
                  let summary = consentSummaries[studentId] else { continue }

            if summary.allConsentsActive {
                compliant += 1
            }
            if !summary.missingConsentTypes.isEmpty {
                missingConsents += 1
            }
            if summary.expiredConsents > 0 {
                expiredConsents += 1
            }
        }

        return (total, compliant, missingConsents, expiredConsents)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Filter chips
            filterChips

            // Statistics
            statisticsSection

            // Students list
            if isLoading {
                loadingView
            } else if filteredStudents.isEmpty {
                emptyView
            } else {
                studentsList
            }
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle("Consent Management")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingConsentDetail) {
            if let student = selectedStudent {
                StudentConsentDetailView(student: student)
                    .tmiSheetStyle()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.tmiTextSecondary)

            TextField("Search students...", text: $searchText)
                .foregroundColor(Color.tmiTextPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.tmiTextSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiSurface)
        )
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ConsentFilter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                            Text(filter.rawValue)
                        }
                        .font(.caption.bold())
                        .foregroundColor(selectedFilter == filter ? Color.tmiTextOnPrimary : Color.tmiTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.cyan : Color.tmiInputBackground)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        let stats = overallStatistics

        return TMIGlassCard(style: .elevated) {
            VStack(spacing: 12) {
                HStack {
                    Text("Consent Overview")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    Spacer()

                    Text("\(stats.total) students")
                        .font(.caption)
                        .foregroundColor(Color.tmiTextSecondary)
                }

                HStack(spacing: 20) {
                    StatBox(
                        title: "Compliant",
                        value: "\(stats.compliant)",
                        color: .green
                    )

                    Divider().frame(height: 40)

                    StatBox(
                        title: "Missing",
                        value: "\(stats.missingConsents)",
                        color: .orange
                    )

                    Divider().frame(height: 40)

                    StatBox(
                        title: "Expired",
                        value: "\(stats.expiredConsents)",
                        color: .red
                    )
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Students List

    private var studentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredStudents) { student in
                    StudentConsentCard(
                        student: student,
                        consentSummary: consentSummaries[student.id ?? ""],
                        onTap: {
                            selectedStudent = student
                            showingConsentDetail = true
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(Color.tmiTextTertiary)

            Text(searchText.isEmpty ? "No students found" : "No results")
                .font(.title2.bold())
                .foregroundColor(Color.tmiTextPrimary)

            Text(searchText.isEmpty ? "Students will appear here" : "Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(Color.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading consent records...")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Actions

    @MainActor
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Load students
        guard let userId = authState.currentUser?.userID else {
            print("[ConsentManagementView] ⚠️ No user ID")
            return
        }

        do {
            // Fetch students from Firestore
            students = try await StudentService.shared.fetchStudents()

            // Fetch consent summaries for each student
            for student in students {
                guard let studentId = student.id else { continue }

                do {
                    let summary = try await complianceService.getConsentSummary(studentId: studentId)
                    consentSummaries[studentId] = summary
                } catch {
                    print("[ConsentManagementView] ⚠️ Failed to load consent for \(student.name): \(error)")
                }
            }

            print("[ConsentManagementView] ✅ Loaded \(students.count) students with consent data")
        } catch {
            print("[ConsentManagementView] ❌ Failed to load data: \(error)")
        }
    }
}

// MARK: - Supporting Views

private struct StudentConsentCard: View {
    let student: Student
    let consentSummary: ConsentSummary?
    let onTap: () -> Void

    var statusColor: Color {
        guard let summary = consentSummary else { return .gray }

        if summary.allConsentsActive {
            return .green
        } else if !summary.missingConsentTypes.isEmpty {
            return .orange
        } else if summary.expiredConsents > 0 {
            return .red
        } else {
            return .yellow
        }
    }

    var statusText: String {
        guard let summary = consentSummary else { return "Unknown" }

        if summary.allConsentsActive {
            return "Compliant"
        } else if !summary.missingConsentTypes.isEmpty {
            return "Missing \(summary.missingConsentTypes.count) consent\(summary.missingConsentTypes.count == 1 ? "" : "s")"
        } else if summary.expiredConsents > 0 {
            return "\(summary.expiredConsents) expired"
        } else {
            return "Partial"
        }
    }

    var body: some View {
        Button(action: onTap) {
            TMIGlassCard(style: .default) {
                HStack(alignment: .top, spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Text(student.initials)
                            .font(.headline)
                            .foregroundColor(statusColor)
                    }

                    // Student info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(student.name)
                            .font(.subheadline.bold())
                            .foregroundColor(Color.tmiTextPrimary)

                        HStack(spacing: 4) {
                            Image(systemName: "graduationcap")
                            Text("Grade \(student.grade)")
                            Text("•")
                            Text("\(student.age) years old")
                        }
                        .font(.caption2)
                        .foregroundColor(Color.tmiTextSecondary)

                        if let summary = consentSummary {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("\(summary.activeConsents) of \(StudentConsent.ConsentType.allCases.count) active")
                            }
                            .font(.caption2)
                            .foregroundColor(Color.tmiTextSecondary)
                        }
                    }

                    Spacer()

                    // Status badge
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(statusText)
                            .font(.caption2.bold())
                            .foregroundColor(Color.tmiTextPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor)
                            .cornerRadius(8)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.tmiTextTertiary)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(Color.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Student Consent Detail View

struct StudentConsentDetailView: View {
    let student: Student

    @Environment(\.dismiss) private var dismiss
    @State private var consentSummary: ConsentSummary?
    @State private var isLoading = false
    @State private var showingGrantConsent = false
    @State private var selectedConsentType: StudentConsent.ConsentType?

    private let complianceService = ComplianceService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .base)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Student header
                            studentHeader

                            // Consent types
                            if let summary = consentSummary {
                                ForEach(StudentConsent.ConsentType.allCases, id: \.self) { consentType in
                                    ConsentTypeCard(
                                        consentType: consentType,
                                        consent: summary.consents.first { $0.consentType == consentType },
                                        onGrant: {
                                            selectedConsentType = consentType
                                            showingGrantConsent = true
                                        },
                                        onRevoke: {
                                            Task { await revokeConsent(consentType) }
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Student Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadConsents()
            }
            .sheet(isPresented: $showingGrantConsent) {
                if let consentType = selectedConsentType {
                    GrantConsentView(
                        student: student,
                        consentType: consentType,
                        onGranted: {
                            showingGrantConsent = false
                            Task { await loadConsents() }
                        }
                    )
                    .tmiSheetStyle()
                }
            }
        }
    }

    private var studentHeader: some View {
        TMIGlassCard(style: .elevated) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Text(student.initials)
                        .font(.title2.bold())
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    Text("Grade \(student.grade) • \(student.age) years old")
                        .font(.caption)
                        .foregroundColor(Color.tmiTextSecondary)

                    if let summary = consentSummary {
                        Text("\(summary.activeConsents) of \(StudentConsent.ConsentType.allCases.count) consents active")
                            .font(.caption2)
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    @MainActor
    private func loadConsents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            consentSummary = try await complianceService.getConsentSummary(studentId: student.id ?? "")
        } catch {
            print("[StudentConsentDetailView] ❌ Error: \(error)")
        }
    }

    @MainActor
    private func revokeConsent(_ consentType: StudentConsent.ConsentType) async {
        do {
            try await complianceService.revokeConsent(studentId: student.id ?? "", consentType: consentType)
            await loadConsents()
        } catch {
            print("[StudentConsentDetailView] ❌ Revoke error: \(error)")
        }
    }
}

// MARK: - Consent Type Card

private struct ConsentTypeCard: View {
    let consentType: StudentConsent.ConsentType
    let consent: StudentConsent?
    let onGrant: () -> Void
    let onRevoke: () -> Void

    var statusColor: Color {
        guard let consent = consent else { return .gray }
        if consent.isActive {
            return .green
        } else if consent.isExpired {
            return .orange
        } else {
            return .red
        }
    }

    var statusText: String {
        guard let consent = consent else { return "Not Granted" }
        if consent.isActive {
            if let expiresAt = consent.expiresAt {
                return "Active until \(expiresAt.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Active"
        } else if consent.isExpired {
            return "Expired"
        } else {
            return "Revoked"
        }
    }

    var body: some View {
        TMIGlassCard(style: .default) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(consentType.displayName)
                            .font(.subheadline.bold())
                            .foregroundColor(Color.tmiTextPrimary)

                        Text(consentType.description)
                            .font(.caption2)
                            .foregroundColor(Color.tmiTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(Color.tmiTextSecondary)

                if let consent = consent {
                    HStack(spacing: 12) {
                        if let grantedByName = consent.grantedByName {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                Text(grantedByName)
                            }
                            .font(.caption2)
                            .foregroundColor(Color.tmiTextSecondary)
                        }

                        if let grantedAt = consent.grantedAt {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(grantedAt.formatted(date: .abbreviated, time: .omitted))
                            }
                            .font(.caption2)
                            .foregroundColor(Color.tmiTextSecondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    if consent?.isActive == true {
                        Button(action: onRevoke) {
                            Text("Revoke")
                                .font(.caption.bold())
                                .foregroundColor(Color.tmiTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: onGrant) {
                            Text("Grant Consent")
                                .font(.caption.bold())
                                .foregroundColor(Color.tmiTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Grant Consent View

private struct GrantConsentView: View {
    let student: Student
    let consentType: StudentConsent.ConsentType
    let onGranted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.authStateModel) private var authState

    @State private var grantedByName = ""
    @State private var expirationEnabled = true
    @State private var expirationDays = 365
    @State private var isGranting = false
    @State private var errorMessage: String?

    private let complianceService = ComplianceService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .base)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        TMIGlassCard(style: .elevated) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(consentType.displayName)
                                    .font(.headline)
                                    .foregroundColor(Color.tmiTextPrimary)

                                Text(consentType.description)
                                    .font(.caption)
                                    .foregroundColor(Color.tmiTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                        }

                        TMIGlassCard(style: .default) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Granted By")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color.tmiTextPrimary)

                                TextField("Parent/Guardian Name", text: $grantedByName)
                                    .textFieldStyle(.plain)
                                    .foregroundColor(Color.tmiTextPrimary)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)

                                Toggle(isOn: $expirationEnabled) {
                                    Text("Set Expiration Date")
                                        .foregroundColor(Color.tmiTextPrimary)
                                }
                                .tint(.cyan)

                                if expirationEnabled {
                                    Stepper(value: $expirationDays, in: 30...1825, step: 30) {
                                        Text("\(expirationDays) days (\(expirationDays / 365) year\(expirationDays / 365 == 1 ? "" : "s"))")
                                            .foregroundColor(Color.tmiTextSecondary)
                                    }
                                }
                            }
                            .padding()
                        }

                        if let errorMessage = errorMessage {
                            TMIGlassCard(style: .default) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(Color.tmiTextPrimary)
                                }
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Grant Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Grant") {
                        Task { await grantConsent() }
                    }
                    .disabled(grantedByName.isEmpty || isGranting)
                }
            }
        }
    }

    @MainActor
    private func grantConsent() async {
        guard let userId = authState.currentUser?.userID else { return }

        isGranting = true
        errorMessage = nil
        defer { isGranting = false }

        do {
            try await complianceService.grantConsent(
                studentId: student.id ?? "",
                consentType: consentType,
                grantedBy: userId,
                grantedByName: grantedByName,
                expirationDays: expirationEnabled ? expirationDays : nil
            )

            onGranted()
            dismiss()
        } catch {
            errorMessage = "Failed to grant consent: \(error.localizedDescription)"
        }
    }
}

// MARK: - Student Service Extension

extension StudentService {
    static let shared = StudentService()
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConsentManagementView()
    }
}
