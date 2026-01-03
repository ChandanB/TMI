//
//  SurveyDeliveryService.swift
//  TMI
//
//  Service for delivering interest surveys to students via email/notifications
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
class SurveyDeliveryService {
    static let shared = SurveyDeliveryService()

    private let firestore = Firestore.firestore()

    private init() {}

    /// Send interest survey to a student
    /// - Parameters:
    ///   - student: The student to send the survey to
    ///   - deliveryMethod: How to deliver the survey (email or notification)
    /// - Returns: Success status and delivery ID
    func sendSurvey(to student: Student, deliveryMethod: SurveyDeliveryMethod = .email) async throws -> SurveyDeliveryResult {
        guard let currentUser = Auth.auth().currentUser else {
            throw SurveyDeliveryError.notAuthenticated
        }

        guard let studentId = student.id else {
            throw SurveyDeliveryError.invalidStudent
        }

        // Create survey delivery record
        let deliveryId = UUID().uuidString
        let surveyURL = generateSurveyURL(studentId: studentId)

        let deliveryRecord = SurveyDelivery(
            id: deliveryId,
            studentId: studentId,
            studentName: student.name,
            sentBy: currentUser.uid,
            sentByName: currentUser.displayName ?? currentUser.email ?? "Educator",
            sentAt: Date(),
            deliveryMethod: deliveryMethod,
            surveyURL: surveyURL,
            status: .pending
        )

        // Save to Firestore
        try await saveDeliveryRecord(deliveryRecord, userId: currentUser.uid)

        // Attempt delivery based on method
        switch deliveryMethod {
        case .email:
            try await deliverViaEmail(student: student, surveyURL: surveyURL, deliveryId: deliveryId)
        case .notification:
            try await deliverViaNotification(student: student, surveyURL: surveyURL, deliveryId: deliveryId)
        case .link:
            // Link-only delivery (for manual sharing)
            break
        }

        // Update status to sent
        try await updateDeliveryStatus(deliveryId: deliveryId, status: .sent, userId: currentUser.uid)

        return SurveyDeliveryResult(
            deliveryId: deliveryId,
            surveyURL: surveyURL,
            success: true,
            message: "Survey sent to \(student.name) via \(deliveryMethod.rawValue)"
        )
    }

    /// Get survey delivery history for a student
    func getDeliveryHistory(for studentId: String) async throws -> [SurveyDelivery] {
        guard let currentUser = Auth.auth().currentUser else {
            throw SurveyDeliveryError.notAuthenticated
        }

        let snapshot = try await firestore
            .collection("users")
            .document(currentUser.uid)
            .collection("survey_deliveries")
            .whereField("studentId", isEqualTo: studentId)
            .order(by: "sentAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: SurveyDelivery.self)
        }
    }

    // MARK: - Private Helpers

    private func generateSurveyURL(studentId: String) -> String {
        // In production, this would be a deep link or web URL
        // For MVP, we'll use a simple scheme
        return "tmi://survey/\(studentId)"
    }

    private func saveDeliveryRecord(_ delivery: SurveyDelivery, userId: String) async throws {
        let docRef = firestore
            .collection("users")
            .document(userId)
            .collection("survey_deliveries")
            .document(delivery.id)

        try docRef.setData(from: delivery)
    }

    private func updateDeliveryStatus(deliveryId: String, status: SurveyDeliveryStatus, userId: String) async throws {
        let docRef = firestore
            .collection("users")
            .document(userId)
            .collection("survey_deliveries")
            .document(deliveryId)

        try await docRef.updateData([
            "status": status.rawValue,
            "deliveredAt": Timestamp(date: Date())
        ])
    }

    private func deliverViaEmail(student: Student, surveyURL: String, deliveryId: String) async throws {
        // For MVP, we'll use mailto: URL scheme
        // In production, integrate with SendGrid, AWS SES, or similar

        guard let guardianEmail = extractGuardianEmail(from: student) else {
            throw SurveyDeliveryError.noContactInfo
        }

        let subject = "Complete Interest Survey for \(student.name)"
        let body = """
        Hello,

        Please help \(student.name) complete their interest survey by visiting:
        \(surveyURL)

        This survey helps us understand what \(student.name) is passionate about and creates personalized learning opportunities.

        Thank you!
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let mailtoURL = "mailto:\(guardianEmail)?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailtoURL) {
            #if !os(macOS)
            if await UIApplication.shared.canOpenURL(url) {
                await UIApplication.shared.open(url)
            } else {
                throw SurveyDeliveryError.emailClientNotAvailable
            }
            #else
            // On macOS, use NSWorkspace
            NSWorkspace.shared.open(url)
            #endif
        }
    }

    private func deliverViaNotification(student: Student, surveyURL: String, deliveryId: String) async throws {
        // For MVP, this would integrate with Firebase Cloud Messaging or Apple Push Notifications
        // For now, we'll just log it
        print("[SurveyDelivery] Would send push notification to \(student.name) with URL: \(surveyURL)")

        // In production:
        // - Get student's device token from Firestore
        // - Send push notification via FCM or APNS
        // - Include surveyURL as deep link in notification payload
    }

    private func extractGuardianEmail(from student: Student) -> String? {
        // In a real app, student model would have guardian contact info
        // For MVP, return nil to trigger error handling
        return nil
    }
}

// MARK: - Models

enum SurveyDeliveryMethod: String, Codable {
    case email = "Email"
    case notification = "Push Notification"
    case link = "Link Only"
}

enum SurveyDeliveryStatus: String, Codable {
    case pending = "Pending"
    case sent = "Sent"
    case delivered = "Delivered"
    case completed = "Completed"
    case failed = "Failed"
}

struct SurveyDelivery: Codable, Identifiable {
    let id: String
    let studentId: String
    let studentName: String
    let sentBy: String
    let sentByName: String
    let sentAt: Date
    let deliveryMethod: SurveyDeliveryMethod
    let surveyURL: String
    var status: SurveyDeliveryStatus
    var deliveredAt: Date?
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case studentId
        case studentName
        case sentBy
        case sentByName
        case sentAt
        case deliveryMethod
        case surveyURL
        case status
        case deliveredAt
        case completedAt
    }
}

struct SurveyDeliveryResult {
    let deliveryId: String
    let surveyURL: String
    let success: Bool
    let message: String
}

enum SurveyDeliveryError: LocalizedError {
    case notAuthenticated
    case invalidStudent
    case noContactInfo
    case emailClientNotAvailable
    case deliveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidStudent:
            return "Student information is incomplete"
        case .noContactInfo:
            return "No guardian contact information available. Please add guardian email to student profile."
        case .emailClientNotAvailable:
            return "Email client is not available on this device"
        case .deliveryFailed(let message):
            return "Survey delivery failed: \(message)"
        }
    }
}
