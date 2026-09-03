import Foundation

nonisolated enum SurveyDefinitionError: Error, Equatable, Sendable {
    case invalidIdentifier(String)
    case invalidVersion
    case invalidQuestion(String)
    case duplicateQuestionID(String)
    case duplicateOptionID(String)
    case duplicateBranchRuleID(String)
    case unknownQuestionReference(String)
    case unknownOptionReference(String)
    case incompatiblePredicate(String)
    case branchCycle
    case unknownAnswer(String)
    case answerTypeMismatch(String)
    case answerOutOfRange(String)
    case requiredAnswerMissing(String)
}

nonisolated enum SurveyQuestionKind: Codable, Equatable, Sendable {
    case singleChoice
    case multiSelect(maxSelections: Int?)
    case shortText(maxLength: Int)
    case rating(minimum: Int, maximum: Int)
    case imageChoice

    private enum CodingKeys: String, CodingKey {
        case type
        case maxSelections
        case maxLength
        case minimum
        case maximum
    }

    private enum Kind: String, Codable {
        case singleChoice
        case multiSelect
        case shortText
        case rating
        case imageChoice
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .singleChoice:
            try container.encode(Kind.singleChoice, forKey: .type)
        case .multiSelect(let maxSelections):
            try container.encode(Kind.multiSelect, forKey: .type)
            try container.encodeIfPresent(maxSelections, forKey: .maxSelections)
        case .shortText(let maxLength):
            try container.encode(Kind.shortText, forKey: .type)
            try container.encode(maxLength, forKey: .maxLength)
        case .rating(let minimum, let maximum):
            try container.encode(Kind.rating, forKey: .type)
            try container.encode(minimum, forKey: .minimum)
            try container.encode(maximum, forKey: .maximum)
        case .imageChoice:
            try container.encode(Kind.imageChoice, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .singleChoice:
            self = .singleChoice
        case .multiSelect:
            self = .multiSelect(
                maxSelections: try container.decodeIfPresent(
                    Int.self,
                    forKey: .maxSelections
                )
            )
        case .shortText:
            self = .shortText(
                maxLength: try container.decode(Int.self, forKey: .maxLength)
            )
        case .rating:
            self = .rating(
                minimum: try container.decode(Int.self, forKey: .minimum),
                maximum: try container.decode(Int.self, forKey: .maximum)
            )
        case .imageChoice:
            self = .imageChoice
        }
    }
}

nonisolated struct SurveyOption: Codable, Equatable, Sendable {
    let id: String
    let label: String
    let imageReference: String?

    init(id: String, label: String, imageReference: String? = nil) {
        self.id = id
        self.label = label
        self.imageReference = imageReference
    }
}

nonisolated struct SurveyQuestion: Codable, Equatable, Sendable {
    let id: String
    let prompt: String
    let kind: SurveyQuestionKind
    let isRequired: Bool
    let options: [SurveyOption]

    private enum CodingKeys: String, CodingKey {
        case id
        case prompt
        case type
        case required
        case options
        case maxSelections
        case maxLength
        case minimum
        case maximum
    }

    private enum QuestionType: String, Codable {
        case singleChoice
        case multiSelect
        case shortText
        case rating
        case imageChoice
    }

    init(
        id: String,
        prompt: String,
        kind: SurveyQuestionKind,
        isRequired: Bool,
        options: [SurveyOption] = []
    ) {
        self.id = id
        self.prompt = prompt
        self.kind = kind
        self.isRequired = isRequired
        self.options = options
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(isRequired, forKey: .required)
        try container.encode(options, forKey: .options)
        switch kind {
        case .singleChoice:
            try container.encode(QuestionType.singleChoice, forKey: .type)
        case .multiSelect(let maxSelections):
            try container.encode(QuestionType.multiSelect, forKey: .type)
            try container.encodeIfPresent(
                maxSelections,
                forKey: .maxSelections
            )
        case .shortText(let maxLength):
            try container.encode(QuestionType.shortText, forKey: .type)
            try container.encode(maxLength, forKey: .maxLength)
        case .rating(let minimum, let maximum):
            try container.encode(QuestionType.rating, forKey: .type)
            try container.encode(minimum, forKey: .minimum)
            try container.encode(maximum, forKey: .maximum)
        case .imageChoice:
            try container.encode(QuestionType.imageChoice, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(QuestionType.self, forKey: .type)
        let kind: SurveyQuestionKind
        switch type {
        case .singleChoice:
            kind = .singleChoice
        case .multiSelect:
            kind = .multiSelect(
                maxSelections: try container.decodeIfPresent(
                    Int.self,
                    forKey: .maxSelections
                )
            )
        case .shortText:
            kind = .shortText(
                maxLength: try container.decode(Int.self, forKey: .maxLength)
            )
        case .rating:
            kind = .rating(
                minimum: try container.decode(Int.self, forKey: .minimum),
                maximum: try container.decode(Int.self, forKey: .maximum)
            )
        case .imageChoice:
            kind = .imageChoice
        }
        self.init(
            id: try container.decode(String.self, forKey: .id),
            prompt: try container.decode(String.self, forKey: .prompt),
            kind: kind,
            isRequired: try container.decode(Bool.self, forKey: .required),
            options: try container.decode([SurveyOption].self, forKey: .options)
        )
    }
}

nonisolated enum SurveyBranchEffect: String, Codable, Equatable, Sendable {
    case show
    case hide
}

nonisolated enum SurveyBranchPredicate: Codable, Equatable, Sendable {
    case equals(String)
    case contains(String)
    case ratingAtLeast(Int)
    case textIsNotEmpty

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum Kind: String, Codable {
        case equals
        case contains
        case ratingAtLeast
        case textIsNotEmpty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .equals(let value):
            try container.encode(Kind.equals, forKey: .type)
            try container.encode(value, forKey: .value)
        case .contains(let value):
            try container.encode(Kind.contains, forKey: .type)
            try container.encode(value, forKey: .value)
        case .ratingAtLeast(let value):
            try container.encode(Kind.ratingAtLeast, forKey: .type)
            try container.encode(value, forKey: .value)
        case .textIsNotEmpty:
            try container.encode(Kind.textIsNotEmpty, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .equals:
            self = .equals(try container.decode(String.self, forKey: .value))
        case .contains:
            self = .contains(try container.decode(String.self, forKey: .value))
        case .ratingAtLeast:
            self = .ratingAtLeast(
                try container.decode(Int.self, forKey: .value)
            )
        case .textIsNotEmpty:
            self = .textIsNotEmpty
        }
    }
}

nonisolated struct SurveyBranchRule: Codable, Equatable, Sendable {
    let id: String
    let sourceQuestionID: String
    let targetQuestionID: String
    let priority: Int
    let effect: SurveyBranchEffect
    let predicate: SurveyBranchPredicate

    init(
        id: String,
        sourceQuestionID: String,
        targetQuestionID: String,
        priority: Int = 0,
        effect: SurveyBranchEffect = .show,
        predicate: SurveyBranchPredicate
    ) {
        self.id = id
        self.sourceQuestionID = sourceQuestionID
        self.targetQuestionID = targetQuestionID
        self.priority = priority
        self.effect = effect
        self.predicate = predicate
    }
}

nonisolated enum SurveyDefinitionState: String, Codable, Equatable, Sendable {
    case published
}

nonisolated struct SurveyDefinition: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumQuestionCount = 100
    static let maximumBranchRuleCount = 200
    static let maximumOptionCount = 100
    static let maximumTextLength = 4_000
    static let maximumIdentifierUTF8Bytes = 1_500
    static let maximumPromptUTF8Bytes = 500
    static let maximumLabelUTF8Bytes = 200
    static let maximumImageReferenceUTF8Bytes = 500
    private static let maximumSafeInteger = 9_007_199_254_740_991

    let schemaVersion: Int
    let state: SurveyDefinitionState
    let id: String
    let version: Int
    let title: String
    let publishedAt: Date
    let questions: [SurveyQuestion]
    let branchRules: [SurveyBranchRule]
    /// Scores answers into proposed interests. The approval callable derives
    /// from this same published table, so the reviewer previews what the server
    /// will actually write.
    let interestRules: [InterestAnalysisRule]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case state
        case id = "definitionID"
        case version
        case title
        case publishedAt
        case questions
        case branchRules
        case interestRules
    }

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: String,
        version: Int,
        title: String,
        publishedAt: Date,
        questions: [SurveyQuestion],
        branchRules: [SurveyBranchRule] = [],
        interestRules: [InterestAnalysisRule] = []
    ) throws {
        self.schemaVersion = schemaVersion
        state = .published
        self.id = id
        self.version = version
        self.title = title
        self.publishedAt = publishedAt
        self.questions = questions
        self.branchRules = branchRules
        self.interestRules = interestRules
        try validateDefinition()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(String.self, forKey: .id),
            version: container.decode(Int.self, forKey: .version),
            title: container.decode(String.self, forKey: .title),
            publishedAt: container.decode(Date.self, forKey: .publishedAt),
            questions: container.decode(
                [SurveyQuestion].self,
                forKey: .questions
            ),
            branchRules: container.decode(
                [SurveyBranchRule].self,
                forKey: .branchRules
            ),
            // A definition published before interest scoring simply scores nothing.
            interestRules: container.decodeIfPresent(
                [InterestAnalysisRule].self,
                forKey: .interestRules
            ) ?? []
        )
        guard try container.decode(
            SurveyDefinitionState.self,
            forKey: .state
        ) == .published else {
            throw SurveyDefinitionError.invalidVersion
        }
    }

    func visibleQuestionIDs(
        answers: [String: SurveyAnswer]
    ) throws -> [String] {
        try validateProvidedAnswers(answers)
        let incoming = Dictionary(grouping: branchRules, by: \.targetQuestionID)
        var memo: [String: Bool] = [:]

        func isVisible(_ questionID: String) -> Bool {
            if let cached = memo[questionID] {
                return cached
            }
            guard let rules = incoming[questionID], !rules.isEmpty else {
                memo[questionID] = true
                return true
            }
            let ordered = rules.sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }
                return $0.id < $1.id
            }
            for rule in ordered where isVisible(rule.sourceQuestionID) {
                if rule.predicate.matches(answers[rule.sourceQuestionID]) {
                    let value = rule.effect == .show
                    memo[questionID] = value
                    return value
                }
            }
            memo[questionID] = false
            return false
        }

        return questions.map(\.id).filter(isVisible)
    }

    func validate(
        answers: [String: SurveyAnswer],
        requireVisibleAnswers: Bool
    ) throws {
        try validateProvidedAnswers(answers)
        guard requireVisibleAnswers else { return }
        let visibleIDs = try visibleQuestionIDs(answers: answers)
        let questionsByID = Dictionary(uniqueKeysWithValues: questions.map {
            ($0.id, $0)
        })
        for questionID in visibleIDs {
            guard let question = questionsByID[questionID], question.isRequired else {
                continue
            }
            guard let answer = answers[questionID], answer.isMeaningful else {
                throw SurveyDefinitionError.requiredAnswerMissing(questionID)
            }
        }
    }

    private func validateDefinition() throws {
        guard schemaVersion == Self.currentSchemaVersion,
              state == .published,
              (1...Self.maximumSafeInteger).contains(version) else {
            throw SurveyDefinitionError.invalidVersion
        }
        guard Self.isValidIdentifier(id) else {
            throw SurveyDefinitionError.invalidIdentifier(id)
        }
        guard !title.isEmpty,
              !questions.isEmpty,
              questions.count <= Self.maximumQuestionCount,
              branchRules.count <= Self.maximumBranchRuleCount else {
            throw SurveyDefinitionError.invalidQuestion(id)
        }
        var questionIDs: Set<String> = []
        for question in questions {
            guard Self.isValidIdentifier(question.id),
                  Self.isCanonicalString(
                    question.prompt,
                    maximumUTF8Bytes: Self.maximumPromptUTF8Bytes
                  ) else {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
            guard questionIDs.insert(question.id).inserted else {
                throw SurveyDefinitionError.duplicateQuestionID(question.id)
            }
            try validate(question)
        }
        var ruleIDs: Set<String> = []
        let questionMap = Dictionary(uniqueKeysWithValues: questions.map {
            ($0.id, $0)
        })
        for rule in branchRules {
            guard Self.isValidIdentifier(rule.id),
                  (-Self.maximumSafeInteger...Self.maximumSafeInteger)
                    .contains(rule.priority) else {
                throw SurveyDefinitionError.invalidIdentifier(rule.id)
            }
            guard ruleIDs.insert(rule.id).inserted else {
                throw SurveyDefinitionError.duplicateBranchRuleID(rule.id)
            }
            guard let source = questionMap[rule.sourceQuestionID] else {
                throw SurveyDefinitionError.unknownQuestionReference(
                    rule.sourceQuestionID
                )
            }
            guard questionMap[rule.targetQuestionID] != nil else {
                throw SurveyDefinitionError.unknownQuestionReference(
                    rule.targetQuestionID
                )
            }
            try validate(rule.predicate, source: source)
        }
        try rejectCycles()
    }

    private func validate(_ question: SurveyQuestion) throws {
        guard question.options.count <= Self.maximumOptionCount else {
            throw SurveyDefinitionError.invalidQuestion(question.id)
        }
        let requiresOptions: Bool
        switch question.kind {
        case .singleChoice, .imageChoice:
            requiresOptions = true
        case .multiSelect(let maximum):
            requiresOptions = true
            if let maximum,
               !(1...question.options.count).contains(maximum) {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
        case .shortText(let maximum):
            requiresOptions = false
            guard (1...Self.maximumTextLength).contains(maximum) else {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
        case .rating(let minimum, let maximum):
            requiresOptions = false
            guard (-Self.maximumSafeInteger...Self.maximumSafeInteger)
                    .contains(minimum),
                  (-Self.maximumSafeInteger...Self.maximumSafeInteger)
                    .contains(maximum),
                  minimum < maximum else {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
        }
        guard requiresOptions == !question.options.isEmpty else {
            throw SurveyDefinitionError.invalidQuestion(question.id)
        }
        var optionIDs: Set<String> = []
        for option in question.options {
            guard Self.isValidIdentifier(option.id),
                  Self.isCanonicalString(
                    option.label,
                    maximumUTF8Bytes: Self.maximumLabelUTF8Bytes
                  ) else {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
            guard optionIDs.insert(option.id).inserted else {
                throw SurveyDefinitionError.duplicateOptionID(option.id)
            }
            if let imageReference = option.imageReference,
               !Self.isCanonicalString(
                imageReference,
                maximumUTF8Bytes: Self.maximumImageReferenceUTF8Bytes
               ) {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
            if case .imageChoice = question.kind,
               option.imageReference == nil {
                throw SurveyDefinitionError.invalidQuestion(question.id)
            }
        }
    }

    private func validate(
        _ predicate: SurveyBranchPredicate,
        source: SurveyQuestion
    ) throws {
        switch (source.kind, predicate) {
        case (.singleChoice, .equals(let optionID)),
             (.imageChoice, .equals(let optionID)),
             (.multiSelect, .contains(let optionID)):
            guard source.options.contains(where: { $0.id == optionID }) else {
                throw SurveyDefinitionError.unknownOptionReference(optionID)
            }
        case (.rating(let minimum, let maximum), .ratingAtLeast(let value)):
            guard (minimum...maximum).contains(value) else {
                throw SurveyDefinitionError.answerOutOfRange(source.id)
            }
        case (.shortText, .textIsNotEmpty):
            break
        default:
            throw SurveyDefinitionError.incompatiblePredicate(source.id)
        }
    }

    private func rejectCycles() throws {
        let dependencies = Dictionary(grouping: branchRules, by: \.targetQuestionID)
            .mapValues { Set($0.map(\.sourceQuestionID)) }
        var visited: Set<String> = []
        var visiting: Set<String> = []

        func visit(_ questionID: String) throws {
            if visiting.contains(questionID) {
                throw SurveyDefinitionError.branchCycle
            }
            guard !visited.contains(questionID) else { return }
            visiting.insert(questionID)
            for dependency in dependencies[questionID] ?? [] {
                try visit(dependency)
            }
            visiting.remove(questionID)
            visited.insert(questionID)
        }

        for question in questions {
            try visit(question.id)
        }
    }

    private func validateProvidedAnswers(
        _ answers: [String: SurveyAnswer]
    ) throws {
        let questionsByID = Dictionary(uniqueKeysWithValues: questions.map {
            ($0.id, $0)
        })
        for (questionID, answer) in answers {
            guard let question = questionsByID[questionID] else {
                throw SurveyDefinitionError.unknownAnswer(questionID)
            }
            try question.validate(answer)
        }
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        !value.isEmpty &&
            value != "." &&
            value != ".." &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.utf8.count <= maximumIdentifierUTF8Bytes &&
            !value.contains("/") &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }

    private static func isCanonicalString(
        _ value: String,
        maximumUTF8Bytes: Int
    ) -> Bool {
        !value.isEmpty &&
            value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            value.utf8.count <= maximumUTF8Bytes &&
            value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}

private nonisolated extension SurveyQuestion {
    func validate(_ answer: SurveyAnswer) throws {
        switch (kind, answer) {
        case (.singleChoice, .single(let optionID)),
             (.imageChoice, .image(let optionID)):
            guard options.contains(where: { $0.id == optionID }) else {
                throw SurveyDefinitionError.unknownOptionReference(optionID)
            }
        case (.multiSelect(let maximum), .multiple(let optionIDs)):
            guard optionIDs.allSatisfy({ optionID in
                options.contains(where: { $0.id == optionID })
            }) else {
                throw SurveyDefinitionError.unknownOptionReference(id)
            }
            if let maximum, optionIDs.count > maximum {
                throw SurveyDefinitionError.answerOutOfRange(id)
            }
        case (.shortText(let maximum), .text(let value)):
            guard value.count <= maximum else {
                throw SurveyDefinitionError.answerOutOfRange(id)
            }
        case (.rating(let minimum, let maximum), .rating(let value)):
            guard (minimum...maximum).contains(value) else {
                throw SurveyDefinitionError.answerOutOfRange(id)
            }
        default:
            throw SurveyDefinitionError.answerTypeMismatch(id)
        }
    }
}

private nonisolated extension SurveyBranchPredicate {
    func matches(_ answer: SurveyAnswer?) -> Bool {
        switch (self, answer) {
        case (.equals(let expected), .single(let actual)),
             (.equals(let expected), .image(let actual)):
            return expected == actual
        case (.contains(let expected), .multiple(let actual)):
            return actual.contains(expected)
        case (.ratingAtLeast(let expected), .rating(let actual)):
            return actual >= expected
        case (.textIsNotEmpty, .text(let actual)):
            return !actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}
