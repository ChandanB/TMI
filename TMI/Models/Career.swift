//
//  Career.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseFirestore

struct Career: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let field: String
    let description: String
    let skills: [String]
    let education: String
    let salaryRange: ClosedRange<Int>
    let jobOutlook: String
}

extension Career {
    static var sampleCareers: [Career] {
        [
            Career(
                title: "Software Developer",
                field: "Technology",
                description: "Design, develop, and maintain software applications and systems.",
                skills: ["Programming", "Problem Solving", "Teamwork"],
                education: "Bachelor's degree in Computer Science or related field",
                salaryRange: 60000...150000,
                jobOutlook: "Faster than average growth expected over the next decade"
            ),
            Career(
                title: "Data Scientist",
                field: "Technology / Analytics",
                description: "Analyze complex data to help organizations make better decisions.",
                skills: ["Statistics", "Machine Learning", "Data Visualization"],
                education: "Master's or Ph.D. in Data Science, Statistics, or related field",
                salaryRange: 80000...180000,
                jobOutlook: "Much faster than average growth expected over the next decade"
            )
        ]
    }
}
