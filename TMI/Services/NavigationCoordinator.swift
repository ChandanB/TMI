
//
//  NavigationCoordinator.swift
//  TMI
//
//  Created by Chandan Brown on 8/13/25.
//

import SwiftUI
import Observation

@Observable
final class NavigationCoordinator {
    static let shared = NavigationCoordinator()
    
    var path = NavigationPath()
    
    private init() {}
    
    func navigate(to destination: NavigationDestination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToDestination<T: Hashable>(_ type: T.Type) {
        // This function is not currently used, but kept for potential future use
        // Implementation would need to be fixed to properly find and navigate to destination
    }
}

// Navigation destinations
enum NavigationDestination: Hashable {
    // Student-related destinations
    case studentDetail(Student)
    case addStudent
    
    // TMI Plan destinations
    case tmiPlanDetail(TMIPlan)
    case newTMIPlan
    
    // Form destinations
    case formDetail(FormTemplate)
    case formCreation
    case formBuilder
    case studentFormSubmissions(studentId: String)
    case userFormSubmissions(userId: String)
    case dynamicForm(String) // templateId
    
    // Career destinations
    case careerDetail(Career)
    
    // Dashboard destinations
    case dashboardInsights(DashboardData)
    
    // Settings destinations
    case userProfile
    case changePassword
    case settings
    
    // Other destinations
    case recommendations(student: Student)
    case resources
    case interestsAndHobbies
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.studentDetail(let lhsStudent), .studentDetail(let rhsStudent)):
            return lhsStudent.id == rhsStudent.id
        case (.addStudent, .addStudent):
            return true
        case (.tmiPlanDetail(let lhsPlan), .tmiPlanDetail(let rhsPlan)):
            return lhsPlan.id == rhsPlan.id
        case (.formDetail(let lhsForm), .formDetail(let rhsForm)):
            return lhsForm.id == rhsForm.id
        case (.careerDetail(let lhsCareer), .careerDetail(let rhsCareer)):
            return lhsCareer.id == rhsCareer.id
        case (.studentFormSubmissions(let lhsId), .studentFormSubmissions(let rhsId)):
            return lhsId == rhsId
        case (.userFormSubmissions(let lhsId), .userFormSubmissions(let rhsId)):
            return lhsId == rhsId
        case (.dynamicForm(let lhsId), .dynamicForm(let rhsId)):
            return lhsId == rhsId
        case (.dashboardInsights(let lhsData), .dashboardInsights(let rhsData)):
            return lhsData.totalStudents == rhsData.totalStudents // Simple comparison
        case (.recommendations(let lhsStudent), .recommendations(let rhsStudent)):
            return lhsStudent.id == rhsStudent.id
        case (.newTMIPlan, .newTMIPlan),
             (.formCreation, .formCreation),
             (.formBuilder, .formBuilder),
             (.userProfile, .userProfile),
             (.changePassword, .changePassword),
             (.settings, .settings),
             (.resources, .resources),
             (.interestsAndHobbies, .interestsAndHobbies):
            return true
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .studentDetail(let student):
            hasher.combine("studentDetail")
            hasher.combine(student.id)
        case .addStudent:
            hasher.combine("addStudent")
        case .tmiPlanDetail(let plan):
            hasher.combine("tmiPlanDetail")
            hasher.combine(plan.id)
        case .newTMIPlan:
            hasher.combine("newTMIPlan")
        case .formDetail(let form):
            hasher.combine("formDetail")
            hasher.combine(form.id)
        case .formCreation:
            hasher.combine("formCreation")
        case .formBuilder:
            hasher.combine("formBuilder")
        case .studentFormSubmissions(let studentId):
            hasher.combine("studentFormSubmissions")
            hasher.combine(studentId)
        case .userFormSubmissions(let userId):
            hasher.combine("userFormSubmissions")
            hasher.combine(userId)
        case .dynamicForm(let templateId):
            hasher.combine("dynamicForm")
            hasher.combine(templateId)
        case .careerDetail(let career):
            hasher.combine("careerDetail")
            hasher.combine(career.id)
        case .dashboardInsights(let data):
            hasher.combine("dashboardInsights")
            hasher.combine(data.totalStudents)
        case .userProfile:
            hasher.combine("userProfile")
        case .changePassword:
            hasher.combine("changePassword")
        case .settings:
            hasher.combine("settings")
        case .recommendations(let student):
            hasher.combine("recommendations")
            hasher.combine(student.id)
        case .resources:
            hasher.combine("resources")
        case .interestsAndHobbies:
            hasher.combine("interestsAndHobbies")
        }
    }
}
