//
//  Career.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import FirebaseFirestore
import SwiftUI

struct Career: Identifiable {
    let id = UUID()
    let title: String
    let field: String
    let description: String
    let skills: [String]
    let education: String
    let salaryRange: ClosedRange<Double>
    let jobOutlook: String
    let growthRate: Double
    
    // Sample careers for preview
    static var sampleCareers: [Career] = [
        Career(
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
