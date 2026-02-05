//
//  DistrictStateModel.swift
//  TMI
//
//  Authoritative state model for district-level data.
//  Manages district metrics, approvals queue, and compliance config.
//

import Foundation
import Observation
import SwiftUI
import FirebaseFirestore

// MARK: - District State Model

@Observable
final class DistrictStateModel: BaseStateModel<District, IdentifiableError> {
    
    // MARK: - Dependencies
    
    private let districtService: DistrictService
    private let planApprovalService: PlanApprovalService
    private let complianceService: ComplianceService
    
    // MARK: - State
    
    /// Current district
    private(set) var district: District?
    
    /// District metrics
    private(set) var metrics: DistrictMetrics?
    
    /// Pending plan approvals
    private(set) var pendingApprovals: [TMIPlan] = []
    
    /// Compliance settings
    private(set) var complianceSettings: ComplianceSettings?
    
    /// Schools in the district
    private(set) var schools: [School] = []
    
    /// Analytics data
    private(set) var analytics: DistrictAnalytics?
    
    // MARK: - Filter State
    
    /// Selected school filter
    private(set) var selectedSchoolId: String?
    
    /// Date range for analytics
    private(set) var analyticsDateRange: ClosedRange<Date>?
    
    // MARK: - Computed Properties
    
    /// Count of pending approvals
    var pendingApprovalCount: Int {
        pendingApprovals.count
    }
    
    /// Whether there are urgent items needing attention
    var hasUrgentItems: Bool {
        // Approvals pending > 7 days or compliance issues
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return pendingApprovals.contains { $0.creationDate < sevenDaysAgo }
    }
    
    /// Students needing attention (no active plan, low engagement, etc.)
    var studentsNeedingAttention: Int {
        metrics?.flaggedStudentsCount ?? 0
    }
    
    /// Intervention coverage percentage
    var interventionCoverage: Double {
        guard let metrics = metrics else { return 0 }
        guard metrics.totalStudents > 0 else { return 0 }
        return Double(metrics.activePlansCount) / Double(metrics.totalStudents)
    }
    
    // MARK: - Initialization
    
    init(
        districtService: DistrictService = .shared,
        planApprovalService: PlanApprovalService = .shared,
        complianceService: ComplianceService = .shared
    ) {
        self.districtService = districtService
        self.planApprovalService = planApprovalService
        self.complianceService = complianceService
        super.init()
    }
    
    // MARK: - Fetch Operations
    
    @MainActor
    override func fetch() async {
        // Requires district ID to be set first
        guard let districtId = district?.id else {
            print("[DistrictStateModel] No district ID set, skipping fetch")
            return
        }
        
        await loadDistrict(id: districtId)
    }
    
    /// Load district data by ID
    @MainActor
    func loadDistrict(id: String) async {
        updateState(.loading)
        
        do {
            // Fetch district in parallel with related data
            async let districtTask = districtService.fetchDistrict(id: id)
            async let metricsTask = fetchMetrics(districtId: id)
            async let approvalsTask = fetchPendingApprovals(districtId: id)
            async let complianceTask = fetchComplianceSettings(districtId: id)
            async let schoolsTask = fetchSchools(districtId: id)
            
            let fetchedDistrict = try await districtTask
            district = fetchedDistrict
            
            // These can fail independently
            _ = try? await metricsTask
            _ = try? await approvalsTask
            _ = try? await complianceTask
            _ = try? await schoolsTask
            
            updateState(.loaded(fetchedDistrict))
            print("[DistrictStateModel] Loaded district: \(fetchedDistrict.name)")
        } catch {
            let identifiableError = IdentifiableError(message: error.localizedDescription)
            updateState(.error(identifiableError))
            print("[DistrictStateModel] Error loading district: \(error.localizedDescription)")
        }
    }
    
    /// Fetch district metrics
    @MainActor
    private func fetchMetrics(districtId: String) async throws {
        do {
            // Fetch metrics from analytics service
            if let analytics = try? await DistrictAnalyticsService.shared.fetchAnalytics(districtId: districtId, dateRange: nil) {
                metrics = analytics.metrics
                print("[DistrictStateModel] Loaded metrics for district")
            }
        } catch {
            print("[DistrictStateModel] Error fetching metrics: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch pending approvals
    @MainActor
    private func fetchPendingApprovals(districtId: String) async throws {
        do {
            let approvals = try await planApprovalService.fetchPendingApprovals(districtId: districtId)
            pendingApprovals = approvals
            print("[DistrictStateModel] Loaded \(approvals.count) pending approvals")
        } catch {
            print("[DistrictStateModel] Error fetching approvals: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch compliance settings
    @MainActor
    private func fetchComplianceSettings(districtId: String) async throws {
        do {
            let settings = try await complianceService.fetchSettings(districtId: districtId)
            complianceSettings = settings
            print("[DistrictStateModel] Loaded compliance settings")
        } catch {
            print("[DistrictStateModel] Error fetching compliance settings: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch schools in district
    @MainActor
    private func fetchSchools(districtId: String) async throws {
        do {
            let fetchedSchools = try await districtService.fetchSchools(for: districtId)
            schools = fetchedSchools
            print("[DistrictStateModel] Loaded \(schools.count) schools")
        } catch {
            print("[DistrictStateModel] Error fetching schools: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch analytics data
    @MainActor
    func fetchAnalytics(dateRange: ClosedRange<Date>? = nil) async {
        guard let districtId = district?.id else { return }
        
        analyticsDateRange = dateRange
        
        do {
            let fetchedAnalytics = try await DistrictAnalyticsService.shared.fetchAnalytics(
                districtId: districtId,
                dateRange: dateRange
            )
            analytics = fetchedAnalytics
            print("[DistrictStateModel] Loaded analytics data")
        } catch {
            print("[DistrictStateModel] Error fetching analytics: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Approval Operations
    
    /// Approve a plan
    @MainActor
    func approvePlan(_ plan: TMIPlan, comments: String? = nil) async throws {
        guard let planId = plan.id else {
            throw DistrictStateError.invalidPlanId
        }
        
        try await planApprovalService.approvePlan(plan: plan, comment: comments)
        
        // Remove from pending
        pendingApprovals.removeAll { $0.id == planId }
        
        print("[DistrictStateModel] Approved plan: \(planId)")
    }
    
    /// Reject a plan
    @MainActor
    func rejectPlan(_ plan: TMIPlan, reason: String) async throws {
        guard let planId = plan.id else {
            throw DistrictStateError.invalidPlanId
        }
        
        try await planApprovalService.rejectPlan(plan: plan, reason: reason)
        
        // Remove from pending
        pendingApprovals.removeAll { $0.id == planId }
        
        print("[DistrictStateModel] Rejected plan: \(planId)")
    }
    
    /// Request revisions on a plan
    @MainActor
    func requestRevisions(_ plan: TMIPlan, feedback: String) async throws {
        guard let planId = plan.id else {
            throw DistrictStateError.invalidPlanId
        }
        
        try await planApprovalService.requestChanges(plan: plan, feedback: feedback)
        
        // Remove from pending (moves to revision status)
        pendingApprovals.removeAll { $0.id == planId }
        
        print("[DistrictStateModel] Requested revisions for plan: \(planId)")
    }
    
    // MARK: - Compliance Operations
    
    /// Update compliance settings
    @MainActor
    func updateComplianceSettings(_ settings: ComplianceSettings) async throws {
        guard let districtId = district?.id else {
            throw DistrictStateError.noDistrictLoaded
        }
        
        try await complianceService.updateSettings(districtId: districtId, settings: settings)
        complianceSettings = settings
        
        print("[DistrictStateModel] Updated compliance settings")
    }
    
    // MARK: - School Filtering
    
    /// Filter by school
    @MainActor
    func filterBySchool(_ schoolId: String?) {
        selectedSchoolId = schoolId
        
        // Re-fetch data with school filter if needed
        // This would typically trigger a new fetch with the school filter applied
    }
    
    // MARK: - Clear State
    
    @MainActor
    func clearState() {
        district = nil
        metrics = nil
        pendingApprovals = []
        complianceSettings = nil
        schools = []
        analytics = nil
        selectedSchoolId = nil
        analyticsDateRange = nil
        
        resetState()
    }
}

// MARK: - District State Errors

enum DistrictStateError: LocalizedError {
    case noDistrictLoaded
    case invalidPlanId
    case approvalFailed(String)
    case complianceUpdateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noDistrictLoaded:
            return "No district is currently loaded"
        case .invalidPlanId:
            return "Invalid plan ID"
        case .approvalFailed(let message):
            return "Approval failed: \(message)"
        case .complianceUpdateFailed(let message):
            return "Compliance update failed: \(message)"
        }
    }
}

// MARK: - Environment Key

private struct DistrictStateModelKey: EnvironmentKey {
    static let defaultValue = DistrictStateModel()
}

extension EnvironmentValues {
    var districtStateModel: DistrictStateModel {
        get { self[DistrictStateModelKey.self] }
        set { self[DistrictStateModelKey.self] = newValue }
    }
}
