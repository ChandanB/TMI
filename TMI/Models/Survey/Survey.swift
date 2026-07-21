//
//  Survey.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

nonisolated struct Survey: Codable, Identifiable, Sendable {
    var id: String? = nil
    var title: String
    var studentId: String
    var date: Date
    var questions: [Question]
    var completed: Bool
    var surveyType: SurveyType

    private enum CodingKeys: String, CodingKey {
        case title
        case studentId
        case date
        case questions
        case completed
        case surveyType
    }
    
    nonisolated enum SurveyType: String, Codable, CaseIterable, Sendable {
        case interests
        case hobbies
        case career
        case academic
        case behavioral
    }
    
    nonisolated struct Question: Codable, Identifiable, Sendable {
        var id: String
        var text: String
        var answerType: AnswerType
        var answer: String?
        var options: [String]?
        
        nonisolated enum AnswerType: String, Codable, Sendable {
            case text
            case multipleChoice
            case scale
        }
    }
    
    init(id: String? = nil, title: String, studentId: String, date: Date, questions: [Question], completed: Bool, surveyType: SurveyType) {
        self.id = id
        self.title = title
        self.studentId = studentId
        self.date = date
        self.questions = questions
        self.completed = completed
        self.surveyType = surveyType
    }
}

nonisolated extension Survey {
    static var sampleSurvey: Survey {
        Survey(
            id: "sample_survey_1",
            title: "Interest and Hobbies Survey",
            studentId: "student_123",
            date: Date(),
            questions: [
                Question(id: "q1", text: "What are your favorite subjects?", answerType: .multipleChoice, options: ["Math", "Science", "History", "Art", "Music"]),
                Question(id: "q2", text: "What extracurricular activities do you enjoy?", answerType: .text),
                Question(id: "q3", text: "On a scale of 1-5, how interested are you in pursuing a career in technology?", answerType: .scale)
            ],
            completed: false,
            surveyType: .interests
        )
    }
}
