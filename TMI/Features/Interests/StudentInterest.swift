import Foundation
@preconcurrency import FirebaseFirestore

nonisolated struct StudentInterestMergeRecord: Codable, Equatable, Sendable {
    let responseID: String?
    let definitionID: String?
    let definitionVersion: Int?
    let approvedBy: String
    let approvedAt: Date
    let previousStrength: Int?
}

struct StudentInterest: Identifiable, Codable, Sendable, Equatable {
    @DocumentID var id: String?
    let studentId: String
    let interestId: String
    let name: String?
    let category: String
    let strength: Int
    let rank: Int
    let source: StudentInterestSource
    let capturedAt: Date
    let updatedAt: Date
    let createdBy: String
    let sourceResponseID: String?
    let sourceDefinitionID: String?
    let sourceDefinitionVersion: Int?
    let mergeHistory: [StudentInterestMergeRecord]

    enum StudentInterestSource: String, Codable, CaseIterable, Sendable {
        case survey
        case staff
        case imported = "import"
    }

    var level: Int { strength }

    init(
        id: String? = nil,
        studentId: String,
        interestId: String,
        level: Int,
        source: StudentInterestSource,
        updatedAt: Date = Date(),
        createdBy: String
    ) {
        self.init(
            id: id,
            studentId: studentId,
            interestId: interestId,
            name: nil,
            category: "other",
            strength: level,
            rank: 0,
            source: source,
            capturedAt: updatedAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            sourceResponseID: nil,
            sourceDefinitionID: nil,
            sourceDefinitionVersion: nil,
            mergeHistory: []
        )
    }

    init(
        id: String? = nil,
        studentId: String,
        interestId: String,
        name: String?,
        category: String,
        strength: Int,
        rank: Int,
        source: StudentInterestSource,
        capturedAt: Date,
        updatedAt: Date,
        createdBy: String,
        sourceResponseID: String?,
        sourceDefinitionID: String?,
        sourceDefinitionVersion: Int?,
        mergeHistory: [StudentInterestMergeRecord]
    ) {
        self.id = id
        self.studentId = studentId
        self.interestId = interestId
        self.name = name
        self.category = category
        self.strength = max(1, min(5, strength))
        self.rank = max(0, rank)
        self.source = source
        self.capturedAt = capturedAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.sourceResponseID = sourceResponseID
        self.sourceDefinitionID = sourceDefinitionID
        self.sourceDefinitionVersion = sourceDefinitionVersion
        self.mergeHistory = mergeHistory
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "studentId": studentId,
            "interestId": interestId,
            "category": category,
            "strength": strength,
            "level": strength,
            "rank": rank,
            "source": source.rawValue,
            "capturedAt": Timestamp(date: capturedAt),
            "updatedAt": Timestamp(date: updatedAt),
            "createdBy": createdBy,
            "mergeHistory": mergeHistory.map { record in
                var item: [String: Any] = [
                    "approvedBy": record.approvedBy,
                    "approvedAt": Timestamp(date: record.approvedAt),
                ]
                item["responseId"] = record.responseID
                item["definitionId"] = record.definitionID
                item["definitionVersion"] = record.definitionVersion
                item["previousStrength"] = record.previousStrength
                return item
            },
        ]
        data["name"] = name
        data["sourceResponseId"] = sourceResponseID
        data["sourceDefinitionId"] = sourceDefinitionID
        data["sourceDefinitionVersion"] = sourceDefinitionVersion
        return data
    }

    static func fromFirestore(id: String, data: [String: Any]) -> StudentInterest? {
        guard let studentID = data["studentId"] as? String,
              let interestID = data["interestId"] as? String,
              let sourceValue = data["source"] as? String,
              let source = StudentInterestSource(rawValue: sourceValue),
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        return StudentInterest(
            id: id,
            studentId: studentID,
            interestId: interestID,
            name: data["name"] as? String,
            category: data["category"] as? String ?? "other",
            strength: data["strength"] as? Int ?? data["level"] as? Int ?? 1,
            rank: data["rank"] as? Int ?? 0,
            source: source,
            capturedAt: (data["capturedAt"] as? Timestamp)?.dateValue() ?? updatedAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            sourceResponseID: data["sourceResponseId"] as? String,
            sourceDefinitionID: data["sourceDefinitionId"] as? String,
            sourceDefinitionVersion: data["sourceDefinitionVersion"] as? Int,
            mergeHistory: []
        )
    }

    var isHighAffinity: Bool { strength >= 4 }
    var isMediumAffinity: Bool { strength == 3 }
    var isLowAffinity: Bool { strength <= 2 }

    var levelDescription: String {
        switch strength {
        case 5: "Very High Interest"
        case 4: "High Interest"
        case 3: "Moderate Interest"
        case 2: "Some Interest"
        case 1: "Slight Interest"
        default: "Unknown"
        }
    }
}
