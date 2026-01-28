//
//  DistrictAnalyticsService.swift
//  TMI
//
//  Service for district-level analytics and reporting.
//

import Foundation
import FirebaseFirestore

// MARK: - District Analytics Service

final class DistrictAnalyticsService {
    static let shared = DistrictAnalyticsService()
    
    private let db = Firestore.firestore()
    private let studentService = StudentService()
    private let planService = TMIPlanService.shared
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetch analytics for a district
    func fetchAnalytics(districtId: String, dateRange: ClosedRange<Date>?) async throws -> DistrictAnalytics? {
        print("[DistrictAnalyticsService] Fetching analytics for district: \(districtId)")

        var query: Query = db.collection("districts")
            .document(districtId)
            .collection("analytics")
            .order(by: "date", descending: true)
            .limit(to: 1)

        if let dateRange = dateRange {
            query = db.collection("districts")
                .document(districtId)
                .collection("analytics")
                .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: dateRange.lowerBound))
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: dateRange.upperBound))
                .order(by: "date", descending: true)
                .limit(to: 1)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.first?.data(as: DistrictAnalytics.self)
    }
    
    /// Fetch trend data for specific metric
    func fetchTrendData(
        districtId: String,
        metric: AnalyticsMetric,
        dateRange: ClosedRange<Date>
    ) async throws -> [TrendDataPoint] {
        let snapshot = try await db.collection("districts")
            .document(districtId)
            .collection("analytics")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: dateRange.lowerBound))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: dateRange.upperBound))
            .order(by: "date", descending: false)
            .getDocuments()

        let analytics = snapshot.documents.compactMap { try? $0.data(as: DistrictAnalytics.self) }

        return analytics.map { entry in
            let value: Double
            switch metric {
            case .studentCount:
                value = Double(entry.metrics.totalStudents)
            case .planProgress:
                value = entry.metrics.planCompletionRate
            case .engagement:
                value = entry.metrics.avgEngagementRate
            case .compliance:
                value = entry.metrics.formCompletionRate
            case .caseload:
                value = Double(entry.metrics.activePlansCount)
            }
            return TrendDataPoint(date: entry.date, value: value)
        }
    }
    
    /// Export analytics report
    func exportReport(districtId: String, format: ReportFormat) async throws -> URL {
        let metrics = try await computeMetrics(for: districtId, filter: DistrictFilter())
        let schools = try await computeSchoolMetrics(for: districtId)
        let insights = await generateInsights(for: metrics, schoolMetrics: schools)

        switch format {
        case .pdf:
            return try await DistrictExportService.shared.exportPDF(
                metrics: metrics,
                schoolMetrics: schools,
                insights: insights,
                districtName: "District Report"
            )
        case .csv:
            return try await DistrictExportService.shared.exportCSV(
                metrics: metrics,
                schoolMetrics: schools,
                districtName: "District Report"
            )
        case .excel:
            throw DistrictAnalyticsError.exportNotImplemented
        }
    }
    
    // MARK: - Metrics Computation
    
    /// Compute district metrics
    func computeMetrics(for districtId: String, filter: DistrictFilter) async throws -> DistrictMetrics {
        print("[DistrictAnalyticsService] Computing metrics for district: \(districtId)")

        let allStudents = try await studentService.fetchStudentsInDistrict(districtId)
        let filteredStudents = applyStudentFilter(allStudents, filter: filter)
        let studentIds = Set(filteredStudents.compactMap { $0.id })

        let plans = try await planService.fetchPlansInDistrict(districtId)
        let filteredPlans = plans.filter { plan in
            guard !studentIds.isEmpty else { return true }
            return plan.students.contains { student in
                guard let id = student.id else { return false }
                return studentIds.contains(id)
            }
        }

        let completedPlans = filteredPlans.filter { $0.progress >= 1.0 }
        let activePlans = filteredPlans.filter { $0.progress < 1.0 }

        let averageEngagement = averageEngagementRate(for: filteredStudents)
        let flaggedStudents = evaluateStudentAlerts(
            students: filteredStudents,
            plans: filteredPlans
        )

        let formCompletionRate = try await computeFormCompletionRate(
            districtId: districtId,
            schoolId: filter.schoolId
        )

        let schools = try await fetchSchoolsCount(districtId: districtId, students: allStudents)
        let staffCount = try await fetchStaffCount(districtId: districtId)

        let completionRate = filteredPlans.isEmpty
            ? 0.0
            : Double(completedPlans.count) / Double(filteredPlans.count)

        return DistrictMetrics(
            totalStudents: filteredStudents.count,
            activePlansCount: activePlans.count,
            completedPlansCount: completedPlans.count,
            planCompletionRate: completionRate,
            formCompletionRate: formCompletionRate,
            avgEngagementRate: averageEngagement,
            flaggedStudentsCount: flaggedStudents.count,
            totalSchools: schools,
            totalStaff: staffCount
        )
    }
    
    /// Compute school-level metrics
    func computeSchoolMetrics(for districtId: String) async throws -> [SchoolMetrics] {
        print("[DistrictAnalyticsService] Computing school metrics for district: \(districtId)")

        let students = try await studentService.fetchStudentsInDistrict(districtId)
        let plans = try await planService.fetchPlansInDistrict(districtId)
        let schools = try await DistrictService.shared.fetchSchools(for: districtId)
        let schoolNameMap = Dictionary(uniqueKeysWithValues: schools.compactMap { school in
            (school.id ?? school.schoolCode, school.name)
        })

        let studentsBySchool = Dictionary(grouping: students) { $0.schoolId ?? "unknown" }
        let studentSchoolLookup = Dictionary(uniqueKeysWithValues: students.compactMap { student in
            guard let id = student.id else { return nil }
            return (id, student.schoolId ?? "unknown")
        })

        var plansBySchool: [String: [TMIPlan]] = [:]
        for plan in plans {
            let targetSchoolId: String
            if let student = plan.students.first,
               let studentId = student.id,
               let schoolId = studentSchoolLookup[studentId] {
                targetSchoolId = schoolId
            } else {
                targetSchoolId = "unknown"
            }
            plansBySchool[targetSchoolId, default: []].append(plan)
        }

        let assignments = try await fetchFormAssignments(districtId: districtId)
        let assignmentsBySchool = Dictionary(grouping: assignments) { $0.schoolId ?? "unknown" }

        var metrics: [SchoolMetrics] = []

        for (schoolId, schoolStudents) in studentsBySchool {
            let schoolPlans = plansBySchool[schoolId] ?? []
            let completedPlans = schoolPlans.filter { $0.progress >= 1.0 }
            let activePlans = schoolPlans.filter { $0.progress < 1.0 }

            let engagementRate = averageEngagementRate(for: schoolStudents)
            let alerts = evaluateStudentAlerts(students: schoolStudents, plans: schoolPlans)

            let schoolAssignments = assignmentsBySchool[schoolId] ?? []
            let completionRate = computeFormCompletionRate(assignments: schoolAssignments)

            let schoolName = schoolNameMap[schoolId] ?? "School \(schoolId)"

            metrics.append(
                SchoolMetrics(
                    schoolId: schoolId,
                    schoolName: schoolName,
                    studentCount: schoolStudents.count,
                    activePlansCount: activePlans.count,
                    completedPlansCount: completedPlans.count,
                    engagementRate: engagementRate,
                    formCompletionRate: completionRate,
                    flaggedStudentsCount: alerts.count
                )
            )
        }

        return metrics.sorted { $0.schoolName < $1.schoolName }
    }
    
    /// Fetch students needing attention
    func fetchStudentsNeedingAttention(for districtId: String, limit: Int) async throws -> [StudentNeedAlert] {
        print("[DistrictAnalyticsService] Fetching students needing attention for district: \(districtId)")

        let students = try await studentService.fetchStudentsInDistrict(districtId)
        let plans = try await planService.fetchPlansInDistrict(districtId)

        let alerts = evaluateStudentAlerts(students: students, plans: plans)
        return Array(alerts.prefix(limit))
    }
    
    /// Generate insights from metrics
    func generateInsights(for metrics: DistrictMetrics, schoolMetrics: [SchoolMetrics]) async -> [String] {
        print("[DistrictAnalyticsService] Generating insights")

        var insights: [String] = []

        if metrics.planCompletionRate < 0.5, metrics.totalPlansCount > 0 {
            insights.append("Plan completion rate is below 50%. Consider reviewing plan follow-up cadence.")
        }

        if metrics.avgEngagementRate < 0.5, metrics.totalStudents > 0 {
            insights.append("Average engagement is low. Check in on students with declining engagement trends.")
        }

        if metrics.formCompletionRate < 0.6 {
            insights.append("Form completion rate is below 60%. Consider shorter forms or reminders.")
        }

        if let topSchool = schoolMetrics.max(by: { $0.engagementRate < $1.engagementRate }) {
            insights.append("\(topSchool.schoolName) has the highest engagement rate at \(String(format: "%.0f%%", topSchool.engagementRate * 100)).")
        }

        if let lowestSchool = schoolMetrics.min(by: { $0.engagementRate < $1.engagementRate }) {
            if lowestSchool.engagementRate > 0 {
                insights.append("\(lowestSchool.schoolName) has the lowest engagement rate at \(String(format: "%.0f%%", lowestSchool.engagementRate * 100)).")
            }
        }

        return insights
    }
    
    // MARK: - Sample Data
    
    /// Get sample metrics for development/demo
    func getSampleMetrics() -> DistrictMetrics {
        return DistrictMetrics(
            totalStudents: 1250,
            activePlansCount: 342,
            completedPlansCount: 189,
            planCompletionRate: 0.55,
            formCompletionRate: 0.78,
            avgEngagementRate: 0.65,
            flaggedStudentsCount: 23,
            totalSchools: 8,
            totalStaff: 156
        )
    }
    
    /// Get sample school metrics
    func getSampleSchoolMetrics() -> [SchoolMetrics] {
        return [
            SchoolMetrics(
                schoolId: "school-001",
                schoolName: "Jefferson High School",
                studentCount: 450,
                activePlansCount: 120,
                completedPlansCount: 68,
                engagementRate: 0.72,
                formCompletionRate: 0.82,
                flaggedStudentsCount: 8
            ),
            SchoolMetrics(
                schoolId: "school-002",
                schoolName: "Lincoln Elementary",
                studentCount: 320,
                activePlansCount: 95,
                completedPlansCount: 58,
                engagementRate: 0.68,
                formCompletionRate: 0.75,
                flaggedStudentsCount: 5
            ),
            SchoolMetrics(
                schoolId: "school-003",
                schoolName: "Roosevelt Middle School",
                studentCount: 480,
                activePlansCount: 127,
                completedPlansCount: 63,
                engagementRate: 0.55,
                formCompletionRate: 0.70,
                flaggedStudentsCount: 10
            )
        ]
    }
    
    /// Get sample student alerts
    func getSampleAlerts() -> [StudentNeedAlert] {
        return [
            StudentNeedAlert(
                id: "alert-001",
                studentId: "student-001",
                studentName: "Alex Johnson",
                schoolId: "school-001",
                schoolName: "Jefferson High School",
                alertType: .lowEngagement,
                alertMessage: "Engagement dropped below 40%",
                severity: .high,
                timestamp: Date()
            ),
            StudentNeedAlert(
                id: "alert-002",
                studentId: "student-002",
                studentName: "Sam Martinez",
                schoolId: "school-002",
                schoolName: "Lincoln Elementary",
                alertType: .overduePlan,
                alertMessage: "TMI Plan overdue by 2 weeks",
                severity: .critical,
                timestamp: Date().addingTimeInterval(-86400)
            ),
            StudentNeedAlert(
                id: "alert-003",
                studentId: "student-003",
                studentName: "Jordan Williams",
                schoolId: "school-003",
                schoolName: "Roosevelt Middle School",
                alertType: .incompleteForm,
                alertMessage: "Form completion rate below 50%",
                severity: .medium,
                timestamp: Date().addingTimeInterval(-172800)
            )
        ]
    }

    // MARK: - Private Helpers

    private func applyStudentFilter(_ students: [Student], filter: DistrictFilter) -> [Student] {
        return students.filter { student in
            if let schoolId = filter.schoolId, student.schoolId != schoolId {
                return false
            }
            if let grade = filter.grade, student.grade != grade {
                return false
            }
            return true
        }
    }

    private func averageEngagementRate(for students: [Student]) -> Double {
        guard !students.isEmpty else { return 0.0 }
        let total = students.reduce(0.0) { $0 + $1.engagementScore }
        return total / Double(students.count)
    }

    private func evaluateStudentAlerts(students: [Student], plans: [TMIPlan]) -> [StudentNeedAlert] {
        let now = Date()
        let planLookup: [String: TMIPlan] = Dictionary(uniqueKeysWithValues: plans.compactMap { plan in
            guard let studentId = plan.students.first?.id else { return nil }
            return (studentId, plan)
        })

        return students.compactMap { student in
            guard let studentId = student.id else { return nil }

            if let lastInteraction = student.lastInteractionDate {
                let daysSince = Calendar.current.dateComponents([.day], from: lastInteraction, to: now).day ?? 0
                if daysSince >= 30 {
                    return StudentNeedAlert(
                        id: UUID().uuidString,
                        studentId: studentId,
                        studentName: student.name,
                        schoolId: student.schoolId ?? "",
                        schoolName: student.school ?? "",
                        alertType: .noRecentInteraction,
                        alertMessage: "No interaction in \(daysSince) days",
                        severity: daysSince >= 60 ? .high : .medium,
                        timestamp: now
                    )
                }
            }

            if student.engagementScore < 0.4 {
                return StudentNeedAlert(
                    id: UUID().uuidString,
                    studentId: studentId,
                    studentName: student.name,
                    schoolId: student.schoolId ?? "",
                    schoolName: student.school ?? "",
                    alertType: .lowEngagement,
                    alertMessage: "Engagement score below 40%",
                    severity: student.engagementScore < 0.25 ? .high : .medium,
                    timestamp: now
                )
            }

            if let plan = planLookup[studentId],
               let endDate = plan.endDate,
               endDate < now,
               plan.progress < 1.0 {
                return StudentNeedAlert(
                    id: UUID().uuidString,
                    studentId: studentId,
                    studentName: student.name,
                    schoolId: student.schoolId ?? "",
                    schoolName: student.school ?? "",
                    alertType: .overduePlan,
                    alertMessage: "Plan overdue for review",
                    severity: .medium,
                    timestamp: now
                )
            }

            return nil
        }
    }

    private func fetchSchoolsCount(districtId: String, students: [Student]) async throws -> Int {
        do {
            let schools = try await DistrictService.shared.fetchSchools(for: districtId)
            return schools.count
        } catch {
            let uniqueSchoolIds = Set(students.compactMap { $0.schoolId })
            return uniqueSchoolIds.count
        }
    }

    private func fetchStaffCount(districtId: String) async throws -> Int {
        let staffRoles = [
            UserRole.teacher.rawValue,
            UserRole.counselor.rawValue,
            UserRole.administrator.rawValue,
            UserRole.admin.rawValue,
            UserRole.socialWorker.rawValue,
            UserRole.superintendent.rawValue,
            UserRole.districtAdmin.rawValue
        ]

        let snapshot = try await db.collection("users")
            .whereField("districtId", isEqualTo: districtId)
            .whereField("role", in: staffRoles)
            .getDocuments()

        return snapshot.documents.count
    }

    private func fetchFormAssignments(districtId: String) async throws -> [FormAssignment] {
        let snapshot = try await db.collection("formAssignments")
            .whereField("districtId", isEqualTo: districtId)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: FormAssignment.self) }
    }

    private func computeFormCompletionRate(districtId: String, schoolId: String?) async throws -> Double {
        var query: Query = db.collection("formAssignments")
            .whereField("districtId", isEqualTo: districtId)

        if let schoolId {
            query = query.whereField("schoolId", isEqualTo: schoolId)
        }

        let snapshot = try await query.getDocuments()
        let assignments = snapshot.documents.compactMap { try? $0.data(as: FormAssignment.self) }
        return computeFormCompletionRate(assignments: assignments)
    }

    private func computeFormCompletionRate(assignments: [FormAssignment]) -> Double {
        let totalAssigned = assignments.reduce(0) { $0 + $1.totalAssigned }
        let totalSubmitted = assignments.reduce(0) { $0 + $1.totalSubmitted }

        guard totalAssigned > 0 else { return 0.0 }
        return Double(totalSubmitted) / Double(totalAssigned)
    }
}


enum AnalyticsMetric: String, CaseIterable {
    case studentCount = "student_count"
    case planProgress = "plan_progress"
    case engagement = "engagement"
    case compliance = "compliance"
    case caseload = "caseload"
}

enum ReportFormat: String, CaseIterable {
    case pdf = "pdf"
    case csv = "csv"
    case excel = "excel"
}

// MARK: - Errors

enum DistrictAnalyticsError: LocalizedError {
    case fetchFailed(String)
    case exportNotImplemented
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to fetch analytics: \(message)"
        case .exportNotImplemented:
            return "Export functionality is not yet implemented"
        }
    }
}
