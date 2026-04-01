//
//  StudentContextStateModel.swift
//  TMI
//
//  Authoritative shared context for which student/plan the user is working on.
//  Replaces ad-hoc "pass student around" navigation patterns.
//

import Foundation
import Observation
import SwiftUI
import Combine

// MARK: - Context Scope

/// Defines the scope/mode in which student context is being accessed
enum StudentContextScope: String, Codable, Sendable {
    /// Staff member viewing/managing student data
    case staff
    /// Staff-initiated student mode session (restricted UI)
    case studentMode
    /// Signed-in student accessing their own data
    case signedInStudent
}

// MARK: - Student Context State Model

/// Authoritative state model for the currently selected student and plan context.
/// All modules that need student/plan context should read from this single source of truth.
@Observable
final class StudentContextStateModel {
    
    // MARK: - Context State
    
    /// Currently selected student ID (authoritative)
    private(set) var selectedStudentId: String?
    
    /// Currently selected plan ID (authoritative)
    private(set) var selectedPlanId: String?
    
    /// Current context scope (staff vs studentMode vs signedInStudent)
    private(set) var scope: StudentContextScope = .staff
    
    /// Cached student object (for quick access without re-fetching)
    private(set) var cachedStudent: Student?
    
    /// Cached plan object (for quick access without re-fetching)
    private(set) var cachedPlan: TMIPlan?
    
    /// Timestamp of last context change (for cache invalidation)
    private(set) var lastContextChange: Date = Date()
    
    // MARK: - Prefetch State
    
    /// Whether student edges (interests, career state) are being prefetched
    private(set) var isPrefetchingEdges: Bool = false
    
    /// Student ID currently being prefetched.
    private(set) var prefetchingStudentId: String?
    
    /// Prefetched student interests (from edge collection)
    private(set) var prefetchedInterests: [Interest] = []
    
    /// Prefetched student career state
    private(set) var prefetchedCareerState: StudentCareerState?
    
    /// Prefetched student plans
    private(set) var prefetchedPlans: [TMIPlan] = []
    
    // MARK: - Navigation State
    
    /// Pending deep link to process after context is set
    private(set) var pendingDeepLink: DeepLinkDestination?
    
    private var prefetchTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Whether a student is currently selected
    var hasActiveStudent: Bool {
        selectedStudentId != nil
    }
    
    /// Whether a plan is currently selected
    var hasActivePlan: Bool {
        selectedPlanId != nil
    }
    
    /// Whether context is in student mode (restricted access)
    var isStudentMode: Bool {
        scope == .studentMode || scope == .signedInStudent
    }
    
    /// Whether the current user can edit student data
    var canEditStudentData: Bool {
        scope == .staff
    }
    
    /// Whether the current user can create/edit plans
    var canManagePlans: Bool {
        scope == .staff
    }
    
    /// Display name for current context (for UI headers)
    var contextDisplayName: String {
        if let student = cachedStudent {
            return student.displayName
        }
        return selectedStudentId ?? "No Student Selected"
    }
    
    // MARK: - Context Management
    
    /// Set the active student context
    /// - Parameters:
    ///   - studentId: The student ID to set as active
    ///   - student: Optional cached student object
    ///   - scope: The context scope (defaults to .staff)
    ///   - prefetchEdges: Whether to prefetch student edges (interests, careers, plans)
    @MainActor
    func setActiveStudent(
        _ studentId: String?,
        student: Student? = nil,
        scope: StudentContextScope = .staff,
        prefetchEdges: Bool = true
    ) async {
        let shouldPrefetch = Self.shouldPrefetchEdges(
            requested: prefetchEdges,
            incomingStudentId: studentId,
            currentStudentId: selectedStudentId,
            incomingScope: scope,
            currentScope: self.scope,
            hasPrefetchedEdges: hasPrefetchedEdges,
            isPrefetching: isPrefetchingEdges && prefetchingStudentId == studentId
        )
        
        // Clear plan when changing students
        if studentId != selectedStudentId {
            prefetchTask?.cancel()
            selectedPlanId = nil
            cachedPlan = nil
            prefetchedInterests = []
            prefetchedCareerState = nil
            prefetchedPlans = []
        }
        
        selectedStudentId = studentId
        cachedStudent = student
        self.scope = scope
        lastContextChange = Date()
        
        // Prefetch edges if requested and we have a valid student ID
        if shouldPrefetch, let studentId = studentId {
            await prefetchStudentEdges(studentId: studentId)
        }
        
        print("[StudentContext] Set active student: \(studentId ?? "nil"), scope: \(scope.rawValue)")
    }
    
    /// Set the active plan context
    /// - Parameters:
    ///   - planId: The plan ID to set as active
    ///   - plan: Optional cached plan object
    @MainActor
    func setActivePlan(_ planId: String?, plan: TMIPlan? = nil) {
        selectedPlanId = planId
        cachedPlan = plan
        lastContextChange = Date()
        
        print("[StudentContext] Set active plan: \(planId ?? "nil")")
    }
    
    /// Clear all context (e.g., on sign out or tab change)
    @MainActor
    func clearContext() {
        prefetchTask?.cancel()
        prefetchTask = nil
        selectedStudentId = nil
        selectedPlanId = nil
        cachedStudent = nil
        cachedPlan = nil
        prefetchedInterests = []
        prefetchedCareerState = nil
        prefetchedPlans = []
        isPrefetchingEdges = false
        prefetchingStudentId = nil
        scope = .staff
        lastContextChange = Date()
        
        print("[StudentContext] Context cleared")
    }
    
    /// Update scope without changing the selected student/plan
    @MainActor
    func updateScope(_ newScope: StudentContextScope) {
        scope = newScope
        lastContextChange = Date()
        
        print("[StudentContext] Scope updated to: \(newScope.rawValue)")
    }
    
    // MARK: - Cache Management
    
    /// Update the cached student (e.g., after an edit)
    @MainActor
    func updateCachedStudent(_ student: Student) {
        guard student.id == selectedStudentId else {
            print("[StudentContext] Warning: Attempted to update cache with mismatched student ID")
            return
        }
        cachedStudent = student
    }
    
    /// Update the cached plan (e.g., after an edit)
    @MainActor
    func updateCachedPlan(_ plan: TMIPlan) {
        guard plan.id == selectedPlanId else {
            print("[StudentContext] Warning: Attempted to update cache with mismatched plan ID")
            return
        }
        cachedPlan = plan
    }
    
    /// Invalidate caches (forces re-fetch on next access)
    @MainActor
    func invalidateCaches() {
        prefetchTask?.cancel()
        prefetchTask = nil
        cachedStudent = nil
        cachedPlan = nil
        prefetchedInterests = []
        prefetchedCareerState = nil
        prefetchedPlans = []
        isPrefetchingEdges = false
        prefetchingStudentId = nil
        lastContextChange = Date()
    }
    
    var hasPrefetchedEdges: Bool {
        !prefetchedInterests.isEmpty || prefetchedCareerState != nil || !prefetchedPlans.isEmpty
    }
    
    static func shouldPrefetchEdges(
        requested: Bool,
        incomingStudentId: String?,
        currentStudentId: String?,
        incomingScope: StudentContextScope,
        currentScope: StudentContextScope,
        hasPrefetchedEdges: Bool,
        isPrefetching: Bool
    ) -> Bool {
        guard requested, let incomingStudentId else { return false }
        
        let isSameContext = incomingStudentId == currentStudentId && incomingScope == currentScope
        if isSameContext && (hasPrefetchedEdges || isPrefetching) {
            return false
        }
        
        return true
    }
    
    // MARK: - Prefetch Operations
    
    /// Prefetch student edges (interests, career state, plans) for better UX
    @MainActor
    private func prefetchStudentEdges(studentId: String) async {
        prefetchTask?.cancel()
        isPrefetchingEdges = true
        prefetchingStudentId = studentId
        
        let task = Task { @MainActor in
            defer {
                if self.prefetchingStudentId == studentId {
                    self.isPrefetchingEdges = false
                    self.prefetchingStudentId = nil
                    self.prefetchTask = nil
                }
            }
        
            print("[StudentContext] Prefetching edges for student: \(studentId)")
        
            // Fetch in parallel
            await withTaskGroup(of: Void.self) { group in
                // Fetch interests
                group.addTask { @MainActor in
                    do {
                        let edges = try await StudentInterestService.shared.getStudentInterests(studentId: studentId)
                        let interestIds = edges.map { $0.interestId }
                        
                        // Fetch full interest objects from library
                        let allInterests = try await InterestLibraryService.shared.fetchAllInterests()
                        let interests = allInterests.filter { interestIds.contains($0.id ?? "") }
                        self.prefetchedInterests = interests
                        
                        print("[StudentContext] Prefetched \(interests.count) interests")
                    } catch is CancellationError {
                        print("[StudentContext] Interest prefetch cancelled for student: \(studentId)")
                    } catch {
                        print("[StudentContext] Failed to prefetch interests: \(error.localizedDescription)")
                    }
                }
                
                // Fetch career state
                group.addTask { @MainActor in
                    do {
                        let careers = try await StudentCareerService.shared.getStudentCareers(studentId: studentId)
                        self.prefetchedCareerState = careers.first
                        
                        print("[StudentContext] Prefetched \(careers.count) career states")
                    } catch is CancellationError {
                        print("[StudentContext] Career prefetch cancelled for student: \(studentId)")
                    } catch {
                        print("[StudentContext] Failed to prefetch career state: \(error.localizedDescription)")
                    }
                }
                
                // Fetch plans
                group.addTask { @MainActor in
                    do {
                        let planService = TMIPlanService.shared
                        let allPlans = try await planService.fetchPlans()
                        
                        // Filter to plans containing this student
                        let studentPlans = allPlans.filter { plan in
                            plan.students.contains(where: { $0.id == studentId })
                        }
                        self.prefetchedPlans = studentPlans
                        
                        print("[StudentContext] Prefetched \(studentPlans.count) plans")
                    } catch is CancellationError {
                        print("[StudentContext] Plan prefetch cancelled for student: \(studentId)")
                    } catch {
                        print("[StudentContext] Failed to prefetch plans: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        prefetchTask = task
        await task.value
    }
    
    // MARK: - Deep Link Handling
    
    /// Queue a deep link for processing after context is ready
    func queueDeepLink(_ destination: DeepLinkDestination) {
        pendingDeepLink = destination
    }
    
    /// Clear pending deep link after processing
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }
}

// MARK: - Deep Link Destinations

/// Represents navigable destinations via deep links
enum DeepLinkDestination: Equatable {
    case student(id: String)
    case plan(id: String)
    case meeting(id: String)
    case resource(id: String)
    case studentInterests(studentId: String)
    case studentCareers(studentId: String)
    case planRecommendations(planId: String)
    case districtApprovals(districtId: String)
    case districtCompliance(districtId: String)
    case scheduleMeeting(planId: String)
    
    /// Parse a deep link URL into a destination
    static func from(url: URL) -> DeepLinkDestination? {
        guard url.scheme == "tmi" else { return nil }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch url.host {
        case "student":
            if pathComponents.count >= 1 {
                let studentId = pathComponents[0]
                if pathComponents.count >= 2 {
                    switch pathComponents[1] {
                    case "interests":
                        return .studentInterests(studentId: studentId)
                    case "careers":
                        return .studentCareers(studentId: studentId)
                    default:
                        break
                    }
                }
                return .student(id: studentId)
            }
        case "plan":
            if pathComponents.count >= 1 {
                let planId = pathComponents[0]
                if pathComponents.count >= 2 {
                    switch pathComponents[1] {
                    case "recommendations":
                        return .planRecommendations(planId: planId)
                    case "schedule":
                        return .scheduleMeeting(planId: planId)
                    default:
                        break
                    }
                }
                return .plan(id: planId)
            }
        case "meeting":
            if pathComponents.count >= 1 {
                return .meeting(id: pathComponents[0])
            }
        case "resource":
            if pathComponents.count >= 1 {
                return .resource(id: pathComponents[0])
            }
        case "district":
            if pathComponents.count >= 2 {
                let districtId = pathComponents[0]
                switch pathComponents[1] {
                case "approvals":
                    return .districtApprovals(districtId: districtId)
                case "compliance":
                    return .districtCompliance(districtId: districtId)
                default:
                    break
                }
            }
        default:
            break
        }
        
        return nil
    }
}

// MARK: - Environment Key

private struct StudentContextStateModelKey: EnvironmentKey {
    static let defaultValue = StudentContextStateModel()
}

extension EnvironmentValues {
    var studentContext: StudentContextStateModel {
        get { self[StudentContextStateModelKey.self] }
        set { self[StudentContextStateModelKey.self] = newValue }
    }
}

// MARK: - View Extension for Context Access

extension View {
    /// Convenience modifier to set student context when a view appears
    func withStudentContext(
        _ studentId: String?,
        student: Student? = nil,
        scope: StudentContextScope = .staff
    ) -> some View {
        self.modifier(StudentContextModifier(
            studentId: studentId,
            student: student,
            scope: scope
        ))
    }
}

private struct StudentContextModifier: ViewModifier {
    @Environment(\.studentContext) private var context
    
    let studentId: String?
    let student: Student?
    let scope: StudentContextScope
    
    func body(content: Content) -> some View {
        content
            .task {
                await context.setActiveStudent(studentId, student: student, scope: scope)
            }
    }
}
