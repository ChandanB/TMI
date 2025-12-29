//
//  StudentAccessPolicy.swift
//  TMI
//
//  Centralized policy for student access restrictions.
//  Used by both StudentModeView and StudentMainView to ensure consistent behavior.
//

import Foundation
import SwiftUI

// MARK: - Student Access Policy

/// Centralized policy determining what features are accessible in different student contexts
struct StudentAccessPolicy {
    
    // MARK: - Tab Access
    
    /// Get allowed tabs for a given access mode
    static func allowedTabs(in mode: StudentAccessMode) -> Set<StudentTab> {
        switch mode {
        case .signedInStudent:
            return [.myInterests, .careers, .myProgress, .activities, .profile]
        case .studentMode:
            return [.myInterests, .careers, .myProgress]
        case .staffViewing:
            // Staff viewing student detail can see everything
            return Set(StudentTab.allCases)
        }
    }
    
    /// Check if a specific tab is accessible in the given mode
    static func isTabAccessible(_ tab: StudentTab, in mode: StudentAccessMode) -> Bool {
        allowedTabs(in: mode).contains(tab)
    }
    
    // MARK: - Feature Access
    
    /// Check if editing is allowed in the given mode
    static func canEdit(in mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent, .studentMode:
            return false
        case .staffViewing:
            return true
        }
    }
    
    /// Check if student can take surveys in the given mode
    static func canTakeSurveys(in mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent, .studentMode:
            return true
        case .staffViewing:
            return false // Staff observes, doesn't take surveys as student
        }
    }
    
    /// Check if student can browse careers in the given mode
    static func canBrowseCareers(in mode: StudentAccessMode) -> Bool {
        // All modes can browse careers
        return true
    }
    
    /// Check if student can bookmark careers in the given mode
    static func canBookmarkCareers(in mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent, .studentMode:
            return true
        case .staffViewing:
            return false
        }
    }
    
    /// Check if the mode allows plan management
    static func canManagePlans(in mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent, .studentMode:
            return false
        case .staffViewing:
            return true
        }
    }
    
    /// Check if the mode allows scheduling meetings
    static func canScheduleMeetings(in mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent, .studentMode:
            return false
        case .staffViewing:
            return true
        }
    }
    
    // MARK: - Data Access
    
    /// Check what student data fields are visible in the given mode
    static func visibleDataFields(in mode: StudentAccessMode) -> Set<StudentDataField> {
        switch mode {
        case .signedInStudent:
            return [.name, .grade, .interests, .careers, .progress, .activities]
        case .studentMode:
            return [.firstName, .grade, .interests, .careers, .progress]
        case .staffViewing:
            return Set(StudentDataField.allCases)
        }
    }
    
    /// Check if a specific data field is visible in the given mode
    static func isDataFieldVisible(_ field: StudentDataField, in mode: StudentAccessMode) -> Bool {
        visibleDataFields(in: mode).contains(field)
    }
    
    // MARK: - Navigation Restrictions
    
    /// Check if navigation to other students is allowed
    static func canNavigateToOtherStudents(in mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent, .studentMode:
            return false
        case .staffViewing:
            return true
        }
    }
    
    /// Check if the user can exit the current mode
    static func canExitMode(_ mode: StudentAccessMode) -> Bool {
        switch mode {
        case .signedInStudent:
            return true // Can sign out
        case .studentMode:
            return true // Can exit with authentication
        case .staffViewing:
            return true // Can always navigate away
        }
    }
    
    /// Whether authentication is required to exit
    static func requiresAuthToExit(_ mode: StudentAccessMode) -> Bool {
        switch mode {
        case .studentMode:
            return true // Biometric/passcode to exit
        default:
            return false
        }
    }
}

// MARK: - Student Access Mode

/// Defines the access mode for student-facing features
enum StudentAccessMode: String, Codable, Sendable {
    /// Student signed in with their own account
    case signedInStudent
    /// Staff-initiated student mode (restricted session)
    case studentMode
    /// Staff viewing student detail (full access)
    case staffViewing
    
    /// Convert from StudentContextScope
    init(from scope: StudentContextScope) {
        switch scope {
        case .signedInStudent:
            self = .signedInStudent
        case .studentMode:
            self = .studentMode
        case .staff:
            self = .staffViewing
        }
    }
}

// MARK: - Student Tab (for Student Experience)

/// Tabs available in the student-facing experience
enum StudentTab: String, CaseIterable, Identifiable, Sendable {
    case myInterests = "My Interests"
    case careers = "Careers"
    case myProgress = "My Progress"
    case activities = "Activities"
    case profile = "Profile"
    case plans = "Plans"
    case meetings = "Meetings"
    case resources = "Resources"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .myInterests: return "heart.fill"
        case .careers: return "briefcase.fill"
        case .myProgress: return "chart.line.uptrend.xyaxis"
        case .activities: return "list.bullet.clipboard"
        case .profile: return "person.circle.fill"
        case .plans: return "doc.text.fill"
        case .meetings: return "calendar"
        case .resources: return "books.vertical.fill"
        }
    }
    
    var title: String {
        rawValue
    }
}

// MARK: - Student Data Field

/// Data fields on a student profile
enum StudentDataField: String, CaseIterable, Sendable {
    case name
    case firstName
    case grade
    case school
    case dateOfBirth
    case age
    case studentID
    case photo
    case interests
    case careers
    case progress
    case activities
    case academicPerformance
    case engagementHistory
    case notes
    case plans
    case meetings
    case surveyResults
}

// MARK: - View Modifiers

extension View {
    /// Apply access policy restrictions to a view
    func restrictedAccess(
        _ mode: StudentAccessMode,
        requiredCapability: @escaping () -> Bool
    ) -> some View {
        self.modifier(RestrictedAccessModifier(
            mode: mode,
            isAccessible: requiredCapability
        ))
    }
}

private struct RestrictedAccessModifier: ViewModifier {
    let mode: StudentAccessMode
    let isAccessible: () -> Bool
    
    func body(content: Content) -> some View {
        if isAccessible() {
            content
        } else {
            RestrictedAccessPlaceholder(mode: mode)
        }
    }
}

struct RestrictedAccessPlaceholder: View {
    let mode: StudentAccessMode
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.tmiTextTertiary)
            
            Text("Access Restricted")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(restrictionMessage)
                .font(.caption)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tmiBackground)
    }
    
    private var restrictionMessage: String {
        switch mode {
        case .signedInStudent:
            return "This feature is not available for student accounts."
        case .studentMode:
            return "This feature is not available in student mode."
        case .staffViewing:
            return "This feature requires different permissions."
        }
    }
}

// MARK: - Environment Key for Access Mode

private struct StudentAccessModeKey: EnvironmentKey {
    static let defaultValue: StudentAccessMode = .staffViewing
}

extension EnvironmentValues {
    var studentAccessMode: StudentAccessMode {
        get { self[StudentAccessModeKey.self] }
        set { self[StudentAccessModeKey.self] = newValue }
    }
}

