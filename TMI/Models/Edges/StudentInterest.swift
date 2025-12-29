//
//  StudentInterest.swift
//  TMI
//
//  Student Interest Edge Model
//  Represents a student's relationship with an interest from the global library
//

import Foundation
import FirebaseFirestore

struct StudentInterest: Identifiable, Codable, Sendable, Equatable {
    @DocumentID var id: String?
    let studentId: String
    let interestId: String
    let level: Int  // 1-5 affinity score
    let source: StudentInterestSource
    let updatedAt: Date
    let createdBy: String  // UID of who created this relationship

    enum StudentInterestSource: String, Codable, CaseIterable, Sendable {
        case survey = "survey"
        case staff = "staff"
        case imported = "import"  // Note: 'import' is a Swift keyword, using 'imported'
    }

    // MARK: - Initializer

    init(
        id: String? = nil,
        studentId: String,
        interestId: String,
        level: Int,
        source: StudentInterestSource,
        updatedAt: Date = Date(),
        createdBy: String
    ) {
        self.id = id
        self.studentId = studentId
        self.interestId = interestId
        self.level = max(1, min(5, level))  // Clamp to 1-5 range
        self.source = source
        self.updatedAt = updatedAt
        self.createdBy = createdBy
    }

    // MARK: - Firestore Helpers

    /// Convert to Firestore data dictionary
    func toFirestoreData() -> [String: Any] {
        [
            "studentId": studentId,
            "interestId": interestId,
            "level": level,
            "source": source.rawValue,
            "updatedAt": Timestamp(date: updatedAt),
            "createdBy": createdBy
        ]
    }

    /// Create from Firestore document
    static func fromFirestore(id: String, data: [String: Any]) -> StudentInterest? {
        guard
            let studentId = data["studentId"] as? String,
            let interestId = data["interestId"] as? String,
            let level = data["level"] as? Int,
            let sourceString = data["source"] as? String,
            let source = StudentInterestSource(rawValue: sourceString),
            let createdBy = data["createdBy"] as? String
        else {
            return nil
        }

        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? Timestamp(date: Date())
        let updatedAt = updatedAtTimestamp.dateValue()

        return StudentInterest(
            id: id,
            studentId: studentId,
            interestId: interestId,
            level: level,
            source: source,
            updatedAt: updatedAt,
            createdBy: createdBy
        )
    }

    // MARK: - Equatable

    static func == (lhs: StudentInterest, rhs: StudentInterest) -> Bool {
        lhs.id == rhs.id &&
        lhs.studentId == rhs.studentId &&
        lhs.interestId == rhs.interestId
    }
}

// MARK: - Helper Extensions

extension StudentInterest {
    /// Check if this is a high-affinity interest (level 4-5)
    var isHighAffinity: Bool {
        level >= 4
    }

    /// Check if this is a medium-affinity interest (level 3)
    var isMediumAffinity: Bool {
        level == 3
    }

    /// Check if this is a low-affinity interest (level 1-2)
    var isLowAffinity: Bool {
        level <= 2
    }

    /// Get a display string for the level
    var levelDescription: String {
        switch level {
        case 5: return "Very High Interest"
        case 4: return "High Interest"
        case 3: return "Moderate Interest"
        case 2: return "Some Interest"
        case 1: return "Slight Interest"
        default: return "Unknown"
        }
    }
}
