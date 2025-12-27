//
//  DistrictAnalyticsService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for computing and fetching district-level analytics
@Observable
class DistrictAnalyticsService {
  private let db = Firestore.firestore()

  // MARK: - Analytics Operations

  /// Compute real-time metrics for a district
  func computeMetrics(for districtId: String, filter: DistrictFilter? = nil) async throws -> DistrictMetrics {
    print("[DistrictAnalyticsService] Computing metrics for district: \(districtId)")

    // Fetch all users in the district
    let usersSnapshot = try await db.collection("users")
      .whereField("districtId", isEqualTo: districtId)
      .getDocuments()

    var totalStudents = 0
    var activePlans = 0
    var completedPlans = 0
    var totalEngagement: Double = 0.0
    var studentCount = 0
    var flaggedStudents = 0
    var totalFormAssignments = 0
    var completedFormSubmissions = 0

    // Process each user's data
    for userDoc in usersSnapshot.documents {
      let uid = userDoc.documentID

      // Fetch students
      let studentsSnapshot = try await db.collection("users").document(uid).collection("students").getDocuments()

      for studentDoc in studentsSnapshot.documents {
        // Apply filters
        if let filter = filter {
          if let filterSchoolId = filter.schoolId,
             let studentSchoolId = studentDoc.data()["schoolId"] as? String,
             filterSchoolId != studentSchoolId {
            continue
          }

          if let filterGrade = filter.grade,
             let studentGrade = studentDoc.data()["grade"] as? String,
             filterGrade != studentGrade {
            continue
          }
        }

        totalStudents += 1

        // Engagement calculation
        if let engagementHistory = studentDoc.data()["engagementHistory"] as? [[String: Any]],
           !engagementHistory.isEmpty {
          let scores = engagementHistory.compactMap { $0["score"] as? Double }
          let avgScore = scores.reduce(0.0, +) / Double(max(scores.count, 1))
          totalEngagement += avgScore
          studentCount += 1

          // Flag low engagement
          if avgScore < 0.5 {
            flaggedStudents += 1
          }
        }
      }

      // Fetch TMI Plans
      let plansSnapshot = try await db.collection("users").document(uid).collection("tmiPlans").getDocuments()

      for planDoc in plansSnapshot.documents {
        let progress = planDoc.data()["progress"] as? Double ?? 0.0
        if progress < 1.0 {
          activePlans += 1
        } else {
          completedPlans += 1
        }
      }

      // Fetch Form Assignments and Submissions
      let assignmentsSnapshot = try await db.collection("users").document(uid).collection("formAssignments").getDocuments()
      totalFormAssignments += assignmentsSnapshot.documents.count

      let submissionsSnapshot = try await db.collection("users").document(uid).collection("formSubmissions").getDocuments()
      completedFormSubmissions += submissionsSnapshot.documents.count
    }

    // Calculate rates
    let avgEngagement = studentCount > 0 ? totalEngagement / Double(studentCount) : 0.0
    let planCompletionRate = (activePlans + completedPlans) > 0
      ? Double(completedPlans) / Double(activePlans + completedPlans)
      : 0.0
    let formCompletionRate = totalFormAssignments > 0
      ? Double(completedFormSubmissions) / Double(totalFormAssignments)
      : 0.0

    // Fetch schools for counts
    let schoolsSnapshot = try await db.collection("districts").document(districtId).collection("schools").getDocuments()
    let totalSchools = schoolsSnapshot.documents.count
    let totalStaff = schoolsSnapshot.documents.reduce(0) { $0 + ($1.data()["staffCount"] as? Int ?? 0) }

    let metrics = DistrictMetrics(
      totalStudents: totalStudents,
      activePlansCount: activePlans,
      completedPlansCount: completedPlans,
      planCompletionRate: planCompletionRate,
      formCompletionRate: formCompletionRate,
      avgEngagementRate: avgEngagement,
      flaggedStudentsCount: flaggedStudents,
      totalSchools: totalSchools,
      totalStaff: totalStaff
    )

    print("[DistrictAnalyticsService] Computed metrics: \(totalStudents) students, \(activePlans + completedPlans) plans")
    return metrics
  }

  /// Compute metrics per school
  func computeSchoolMetrics(for districtId: String) async throws -> [SchoolMetrics] {
    print("[DistrictAnalyticsService] Computing school metrics for district: \(districtId)")

    // Fetch schools
    let schoolsSnapshot = try await db.collection("districts").document(districtId).collection("schools").getDocuments()

    var allSchoolMetrics: [SchoolMetrics] = []

    for schoolDoc in schoolsSnapshot.documents {
      let schoolId = schoolDoc.documentID
      let schoolName = schoolDoc.data()["name"] as? String ?? "Unknown School"

      // Fetch users in this school
      let usersSnapshot = try await db.collection("users")
        .whereField("schoolId", isEqualTo: schoolId)
        .getDocuments()

      var studentCount = 0
      var activePlans = 0
      var completedPlans = 0
      var totalEngagement: Double = 0.0
      var engagementCount = 0
      var flaggedStudents = 0
      var totalFormAssignments = 0
      var completedFormSubmissions = 0

      for userDoc in usersSnapshot.documents {
        let uid = userDoc.documentID

        // Students
        let studentsSnapshot = try await db.collection("users").document(uid).collection("students")
          .whereField("schoolId", isEqualTo: schoolId)
          .getDocuments()

        for studentDoc in studentsSnapshot.documents {
          studentCount += 1

          if let engagementHistory = studentDoc.data()["engagementHistory"] as? [[String: Any]],
             !engagementHistory.isEmpty {
            let scores = engagementHistory.compactMap { $0["score"] as? Double }
            let avgScore = scores.reduce(0.0, +) / Double(max(scores.count, 1))
            totalEngagement += avgScore
            engagementCount += 1

            if avgScore < 0.5 {
              flaggedStudents += 1
            }
          }
        }

        // Plans
        let plansSnapshot = try await db.collection("users").document(uid).collection("tmiPlans").getDocuments()
        for planDoc in plansSnapshot.documents {
          let progress = planDoc.data()["progress"] as? Double ?? 0.0
          if progress < 1.0 {
            activePlans += 1
          } else {
            completedPlans += 1
          }
        }

        // Forms
        let assignmentsSnapshot = try await db.collection("users").document(uid).collection("formAssignments").getDocuments()
        totalFormAssignments += assignmentsSnapshot.documents.count

        let submissionsSnapshot = try await db.collection("users").document(uid).collection("formSubmissions").getDocuments()
        completedFormSubmissions += submissionsSnapshot.documents.count
      }

      let engagementRate = engagementCount > 0 ? totalEngagement / Double(engagementCount) : 0.0
      let formCompletionRate = totalFormAssignments > 0
        ? Double(completedFormSubmissions) / Double(totalFormAssignments)
        : 0.0

      let schoolMetrics = SchoolMetrics(
        schoolId: schoolId,
        schoolName: schoolName,
        studentCount: studentCount,
        activePlansCount: activePlans,
        completedPlansCount: completedPlans,
        engagementRate: engagementRate,
        formCompletionRate: formCompletionRate,
        flaggedStudentsCount: flaggedStudents
      )

      allSchoolMetrics.append(schoolMetrics)
    }

    print("[DistrictAnalyticsService] Computed metrics for \(allSchoolMetrics.count) schools")
    return allSchoolMetrics
  }

  /// Get students needing attention
  func fetchStudentsNeedingAttention(for districtId: String, limit: Int = 20) async throws -> [StudentNeedAlert] {
    print("[DistrictAnalyticsService] Fetching students needing attention for district: \(districtId)")

    var alerts: [StudentNeedAlert] = []

    // Fetch all users in the district
    let usersSnapshot = try await db.collection("users")
      .whereField("districtId", isEqualTo: districtId)
      .getDocuments()

    for userDoc in usersSnapshot.documents {
      let uid = userDoc.documentID

      // Fetch students
      let studentsSnapshot = try await db.collection("users").document(uid).collection("students").getDocuments()

      for studentDoc in studentsSnapshot.documents {
        let studentId = studentDoc.documentID
        let studentName = studentDoc.data()["name"] as? String ?? "Unknown Student"
        let schoolId = studentDoc.data()["schoolId"] as? String ?? ""
        let schoolName = studentDoc.data()["schoolName"] as? String ?? "Unknown School"

        // Check engagement
        if let engagementHistory = studentDoc.data()["engagementHistory"] as? [[String: Any]],
           !engagementHistory.isEmpty {
          let scores = engagementHistory.compactMap { $0["score"] as? Double }
          let avgScore = scores.reduce(0.0, +) / Double(max(scores.count, 1))

          if avgScore < 0.4 {
            alerts.append(StudentNeedAlert(
              id: UUID().uuidString,
              studentId: studentId,
              studentName: studentName,
              schoolId: schoolId,
              schoolName: schoolName,
              alertType: .lowEngagement,
              alertMessage: "Engagement score is \(String(format: "%.0f%%", avgScore * 100))",
              severity: avgScore < 0.3 ? .critical : .high,
              timestamp: Date()
            ))
          }
        }

        // Check last interaction
        if let lastInteraction = studentDoc.data()["lastInteractionDate"] as? Timestamp {
          let daysSince = Calendar.current.dateComponents([.day], from: lastInteraction.dateValue(), to: Date()).day ?? 0
          if daysSince > 30 {
            alerts.append(StudentNeedAlert(
              id: UUID().uuidString,
              studentId: studentId,
              studentName: studentName,
              schoolId: schoolId,
              schoolName: schoolName,
              alertType: .noRecentInteraction,
              alertMessage: "No interaction in \(daysSince) days",
              severity: daysSince > 60 ? .high : .medium,
              timestamp: Date()
            ))
          }
        }
      }
    }

    // Sort by severity and limit
    alerts.sort { alert1, alert2 in
      let severityOrder: [StudentNeedAlert.Severity: Int] = [.critical: 0, .high: 1, .medium: 2, .low: 3]
      return (severityOrder[alert1.severity] ?? 999) < (severityOrder[alert2.severity] ?? 999)
    }

    let limitedAlerts = Array(alerts.prefix(limit))
    print("[DistrictAnalyticsService] Found \(limitedAlerts.count) students needing attention")
    return limitedAlerts
  }

  /// Generate AI insights for district
  func generateInsights(for metrics: DistrictMetrics, schoolMetrics: [SchoolMetrics]) async -> [String] {
    print("[DistrictAnalyticsService] Generating insights...")

    var insights: [String] = []

    // Engagement insights
    if metrics.avgEngagementRate > 0.75 {
      insights.append("District engagement is strong at \(metrics.engagementPercentage)")
    } else if metrics.avgEngagementRate < 0.6 {
      insights.append("⚠️ District engagement below target at \(metrics.engagementPercentage)")
    }

    // Plan completion insights
    if metrics.planCompletionRate > 0.7 {
      insights.append("Excellent TMI plan completion rate at \(metrics.planCompletionPercentage)")
    } else if metrics.planCompletionRate < 0.5 {
      insights.append("⚠️ TMI plan completion needs improvement (\(metrics.planCompletionPercentage))")
    }

    // School comparison
    if !schoolMetrics.isEmpty {
      let sortedByEngagement = schoolMetrics.sorted { $0.engagementRate > $1.engagementRate }
      if let topSchool = sortedByEngagement.first {
        insights.append("\(topSchool.schoolName) leads in engagement at \(String(format: "%.0f%%", topSchool.engagementRate * 100))")
      }
    }

    // Flagged students
    if metrics.flaggedStudentsCount > 0 {
      insights.append("\(metrics.flaggedStudentsCount) students require immediate attention")
    }

    // Form completion
    if metrics.formCompletionRate > 0.8 {
      insights.append("Strong form completion at \(metrics.formCompletionPercentage)")
    }

    print("[DistrictAnalyticsService] Generated \(insights.count) insights")
    return insights
  }

  /// Use sample data for development/demo
  func getSampleMetrics() -> DistrictMetrics {
    return .sample
  }

  func getSampleSchoolMetrics() -> [SchoolMetrics] {
    return SchoolMetrics.sampleSchools
  }

  func getSampleAlerts() -> [StudentNeedAlert] {
    return StudentNeedAlert.sampleAlerts
  }
}

// MARK: - Error Handling

enum DistrictAnalyticsError: Error, LocalizedError {
  case districtNotFound
  case insufficientData
  case calculationFailed(String)

  var errorDescription: String? {
    switch self {
    case .districtNotFound:
      return "District not found"
    case .insufficientData:
      return "Insufficient data to generate analytics"
    case .calculationFailed(let message):
      return "Analytics calculation failed: \(message)"
    }
  }
}
