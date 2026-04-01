//
//  Career.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

@preconcurrency import FirebaseFirestore
import SwiftUI

struct Career: Identifiable, Codable, Sendable, Equatable {
    @DocumentID var id: String?
    let title: String
    let field: String
    let description: String
    let skills: [String]
    let education: String
    let salaryRange: ClosedRange<Double>
    let jobOutlook: String
    let growthRate: Double

    // Related data
    let relatedInterests: [String]
    let tags: [String]

    // Timestamps
    let createdAt: Date
    let updatedAt: Date

    // Library Scope
    let scope: CareerScope
    let districtId: String?

    // Custom CodingKeys for salaryRange and new fields
    enum CodingKeys: String, CodingKey, Sendable {
        case id, title, field, description, skills, education, jobOutlook, growthRate
        case relatedInterests, tags
        case createdAt, updatedAt, scope, districtId
        case salaryRangeLowerBound
        case salaryRangeUpperBound
    }

    enum CareerScope: String, Codable, CaseIterable, Identifiable, Sendable {
        case global = "global"
        case district = "district"

        var id: String { rawValue }
    }

    // Custom initializer for decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        field = try container.decode(String.self, forKey: .field)
        description = try container.decode(String.self, forKey: .description)
        skills = try container.decode([String].self, forKey: .skills)
        education = try container.decode(String.self, forKey: .education)
        jobOutlook = try container.decode(String.self, forKey: .jobOutlook)
        growthRate = try container.decode(Double.self, forKey: .growthRate)

        relatedInterests = try container.decodeIfPresent([String].self, forKey: .relatedInterests) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        scope = try container.decodeIfPresent(CareerScope.self, forKey: .scope) ?? .global
        districtId = try container.decodeIfPresent(String.self, forKey: .districtId)

        let lowerBound = try container.decode(Double.self, forKey: .salaryRangeLowerBound)
        let upperBound = try container.decode(Double.self, forKey: .salaryRangeUpperBound)
        salaryRange = lowerBound...upperBound
    }

    // Custom encoder for encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(field, forKey: .field)
        try container.encode(description, forKey: .description)
        try container.encode(skills, forKey: .skills)
        try container.encode(education, forKey: .education)
        try container.encode(jobOutlook, forKey: .jobOutlook)
        try container.encode(growthRate, forKey: .growthRate)
        try container.encode(relatedInterests, forKey: .relatedInterests)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(scope, forKey: .scope)
        try container.encodeIfPresent(districtId, forKey: .districtId)
        try container.encode(salaryRange.lowerBound, forKey: .salaryRangeLowerBound)
        try container.encode(salaryRange.upperBound, forKey: .salaryRangeUpperBound)
    }

    // Existing initializer (must be kept for sample data and direct creation)
    init(
        id: String? = nil,
        title: String,
        field: String,
        description: String,
        skills: [String],
        education: String,
        salaryRange: ClosedRange<Double>,
        jobOutlook: String,
        growthRate: Double,
        relatedInterests: [String] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        scope: CareerScope = .global,
        districtId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.field = field
        self.description = description
        self.skills = skills
        self.education = education
        self.salaryRange = salaryRange
        self.jobOutlook = jobOutlook
        self.growthRate = growthRate
        self.relatedInterests = relatedInterests
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scope = scope
        self.districtId = districtId
    }

    // Sample careers for preview
    static let sampleCareers: [Career] = [
        Career(
            id: "sample-software-developer",
            title: "Software Developer",
            field: "Technology",
            description: "Design, build, and maintain computer programs. Work with various programming languages to create software solutions for businesses and consumers.",
            skills: ["JavaScript", "Python", "Problem Solving", "Critical Thinking", "Communication"],
            education: "Bachelor's degree in Computer Science, Software Engineering, or related field. Some positions may require a Master's degree for advanced development roles.",
            salaryRange: 70000...120000,
            jobOutlook: "Rapid growth expected with a 22% increase in jobs over the next decade, much faster than average for all occupations.",
            growthRate: 0.22
        ),
        Career(
            id: "sample-data-scientist",
            title: "Data Scientist",
            field: "Technology",
            description: "Analyze large datasets to extract meaningful insights. Use statistical methods and machine learning algorithms to solve complex problems and inform business decisions.",
            skills: ["Statistics", "Machine Learning", "Python", "SQL", "Data Visualization"],
            education: "Master's degree or Ph.D. in Computer Science, Statistics, Mathematics, or a related field.",
            salaryRange: 90000...150000,
            jobOutlook: "Fast growth with a 31% projected increase over the next decade due to the expanding need for data analysis across industries.",
            growthRate: 0.31
        ),
        Career(
            id: "sample-nurse-practitioner",
            title: "Nurse Practitioner",
            field: "Healthcare",
            description: "Provide advanced nursing care to patients, including diagnosing illnesses, prescribing medications, and developing treatment plans.",
            skills: ["Patient Care", "Medical Knowledge", "Communication", "Critical Thinking", "Empathy"],
            education: "Master's degree in Nursing plus national certification in a specialty area. Requires an RN license as prerequisite.",
            salaryRange: 90000...130000,
            jobOutlook: "Significant growth expected with a 45% increase in jobs over the next decade due to aging population and healthcare expansion.",
            growthRate: 0.45
        ),
        Career(
            id: "sample-marketing-manager",
            title: "Marketing Manager",
            field: "Business",
            description: "Develop and implement marketing strategies to promote products or services. Analyze market trends and oversee marketing campaigns to drive business growth.",
            skills: ["Strategic Planning", "Communication", "Creativity", "Analytics", "Project Management"],
            education: "Bachelor's degree in Marketing, Business, or Communications. MBA often preferred for senior positions.",
            salaryRange: 65000...120000,
            jobOutlook: "Steady growth with a 10% projected increase over the next decade, about as fast as average for all occupations.",
            growthRate: 0.10
        ),
        Career(
            id: "sample-civil-engineer",
            title: "Civil Engineer",
            field: "Engineering",
            description: "Design, construct, and maintain infrastructure projects and systems, including roads, bridges, dams, and water supply systems.",
            skills: ["Mathematical Analysis", "Problem Solving", "CAD Software", "Project Management", "Technical Drawing"],
            education: "Bachelor's degree in Civil Engineering required. Many positions require Professional Engineer (PE) licensure.",
            salaryRange: 70000...120000,
            jobOutlook: "Moderate growth with an 8% increase expected over the next decade, primarily driven by infrastructure improvement needs.",
            growthRate: 0.08
        ),
        Career(
            id: "sample-high-school-teacher",
            title: "High School Teacher",
            field: "Education",
            description: "Educate students in grades 9-12 in specific subject areas. Develop lesson plans, assess student progress, and prepare them for college or careers.",
            skills: ["Subject Expertise", "Communication", "Classroom Management", "Patience", "Adaptability"],
            education: "Bachelor's degree in Education or subject area plus state teaching certification. Some positions may require a Master's degree.",
            salaryRange: 50000...85000,
            jobOutlook: "Stable growth with a 4% increase expected over the next decade, about as fast as average for all occupations.",
            growthRate: 0.04
        ),
        Career(
            id: "sample-graphic-designer",
            title: "Graphic Designer",
            field: "Arts",
            description: "Create visual concepts to communicate ideas. Design layouts for websites, advertisements, brochures, magazines, and corporate reports.",
            skills: ["Creativity", "Adobe Creative Suite", "Typography", "Visual Communication", "Problem Solving"],
            education: "Bachelor's degree in Graphic Design or a related field. Strong portfolio of work typically required.",
            salaryRange: 45000...85000,
            jobOutlook: "Slow growth with a 3% increase expected over the next decade, slower than average due to automation of some design tasks.",
            growthRate: 0.03
        ),
        Career(
            id: "sample-financial-analyst",
            title: "Financial Analyst",
            field: "Business",
            description: "Evaluate investment opportunities and provide guidance for businesses and individuals. Analyze financial data to forecast business, industry, and economic conditions.",
            skills: ["Financial Modeling", "Data Analysis", "Research", "Communication", "Problem Solving"],
            education: "Bachelor's degree in Finance, Accounting, Economics, or related field. MBA or CFA certification often preferred for advancement.",
            salaryRange: 65000...115000,
            jobOutlook: "Above average growth with a 9% increase expected over the next decade, driven by complex financial regulations and products.",
            growthRate: 0.09
        ),
        Career(
            id: "sample-environmental-scientist",
            title: "Environmental Scientist",
            field: "Science",
            description: "Study environmental problems and develop solutions. Collect and analyze data to monitor environmental impacts and protect human health and natural resources.",
            skills: ["Research", "Data Analysis", "Technical Writing", "Problem Solving", "Field Work"],
            education: "Bachelor's degree in Environmental Science or related field required. Master's degree often needed for advancement.",
            salaryRange: 55000...95000,
            jobOutlook: "Strong growth with an 8% increase expected over the next decade due to growing environmental concerns and regulations.",
            growthRate: 0.08
        )
    ]
}
