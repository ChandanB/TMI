//
//  SocialServicesCareers.swift
//  TMI
//
//  Career data for the Social Services category (25 careers)
//

import Foundation

enum SocialServicesCareers {
    static let all: [CareerPath] = [

        // MARK: - Counseling

        CareerPath(
            title: "Clinical Social Worker",
            category: "social_services",
            subcategory: "Counseling",
            description: "Clinical social workers provide therapy and mental health support to individuals, families, and groups dealing with challenges like trauma, depression, or substance use. They assess clients' needs, develop treatment plans, and connect people with community resources.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 52_000, max: 95_000),
            educationLevel: .masters,
            icon: "heart.text.clipboard.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Child Welfare Worker",
            category: "social_services",
            subcategory: "Counseling",
            description: "Child welfare workers investigate reports of child abuse or neglect and work to ensure the safety, stability, and well-being of vulnerable children and families. They coordinate care plans, connect families to supportive services, and advocate for children's best interests.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 40_000, max: 72_000),
            educationLevel: .bachelors,
            icon: "figure.2.arms.open",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Crisis Counselor",
            category: "social_services",
            subcategory: "Counseling",
            description: "Crisis counselors provide immediate emotional support and intervention to individuals experiencing mental health emergencies, suicidal thoughts, or acute trauma. They work on hotlines, in emergency rooms, or in community settings to stabilize situations and connect people to ongoing care.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "phone.fill.badge.plus",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Rehabilitation Counselor",
            category: "social_services",
            subcategory: "Counseling",
            description: "Rehabilitation counselors help people with physical, mental, developmental, or emotional disabilities live independently and find meaningful employment. They assess clients' strengths, develop individualized plans, and coordinate medical and vocational services.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 42_000, max: 78_000),
            educationLevel: .masters,
            icon: "figure.roll",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Grief Counselor",
            category: "social_services",
            subcategory: "Counseling",
            description: "Grief counselors support individuals who are coping with the loss of a loved one, a major life change, or other profound loss through therapy and compassionate guidance. They help clients process emotions, develop healthy coping strategies, and find their path forward.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .masters,
            icon: "heart.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Substance Abuse Counselor",
            category: "social_services",
            subcategory: "Counseling",
            description: "Substance abuse counselors work with individuals struggling with addiction to alcohol, drugs, or other substances by providing therapy, education, and relapse prevention support. They often work in treatment centers, hospitals, or community health organizations.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 40_000, max: 75_000),
            educationLevel: .bachelors,
            icon: "hand.raised.fill",
            color: "#1ABC9C"
        ),

        // MARK: - Community Development

        CareerPath(
            title: "Community Health Worker",
            category: "social_services",
            subcategory: "Community Development",
            description: "Community health workers serve as a bridge between healthcare providers and underserved communities by connecting residents to medical services, health education, and social supports. They often come from the communities they serve and are trusted guides for navigating complex systems.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 35_000, max: 62_000),
            educationLevel: .someCollege,
            icon: "person.3.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Community Development Director",
            category: "social_services",
            subcategory: "Community Development",
            description: "Community development directors lead organizations that strengthen neighborhoods through economic development, affordable housing, job creation, and resident engagement programs. They manage staff, secure funding, and build partnerships with government, businesses, and community groups.",
            pathway: nil,
            requiredInterests: ["social_services", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .masters,
            icon: "building.2.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Housing Coordinator",
            category: "social_services",
            subcategory: "Community Development",
            description: "Housing coordinators help low-income individuals and families access affordable housing programs, navigate rental assistance, and maintain stable living situations. They connect clients with landlords, government programs, and supportive services to prevent homelessness.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "house.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Homeless Services Coordinator",
            category: "social_services",
            subcategory: "Community Development",
            description: "Homeless services coordinators manage programs and resources that help people experiencing homelessness access shelter, food, healthcare, and a path to stable housing. They work with government agencies, nonprofits, and volunteers to coordinate a community-wide response.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 40_000, max: 72_000),
            educationLevel: .bachelors,
            icon: "hands.sparkles.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Urban Outreach Worker",
            category: "social_services",
            subcategory: "Community Development",
            description: "Urban outreach workers go directly into communities to connect at-risk individuals with social services, health resources, and crisis support where they already are. Their presence in streets, shelters, and community spaces makes help accessible to people who may not seek it on their own.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 34_000, max: 60_000),
            educationLevel: .someCollege,
            icon: "figure.walk.circle.fill",
            color: "#1ABC9C"
        ),

        // MARK: - Advocacy

        CareerPath(
            title: "Human Rights Advocate",
            category: "social_services",
            subcategory: "Advocacy",
            description: "Human rights advocates work to protect the fundamental rights and dignity of individuals and communities by documenting abuses, lobbying for policy changes, and raising public awareness. They often work with international organizations, nonprofits, or legal teams to hold governments and institutions accountable.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 42_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "person.badge.shield.checkmark.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Disability Rights Specialist",
            category: "social_services",
            subcategory: "Advocacy",
            description: "Disability rights specialists advocate for equal access, inclusion, and legal protections for people with physical, cognitive, and sensory disabilities. They help individuals navigate accommodation requests, investigate discrimination complaints, and educate organizations on compliance with disability law.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 45_000, max: 82_000),
            educationLevel: .bachelors,
            icon: "figure.roll.runningpace",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Victim Advocate",
            category: "social_services",
            subcategory: "Advocacy",
            description: "Victim advocates provide emotional support, information, and practical assistance to people who have experienced crime, abuse, or trauma as they navigate the legal system and access recovery services. They work in courthouses, law enforcement agencies, hospitals, and community organizations.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "shield.lefthalf.filled",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Patient Advocate",
            category: "social_services",
            subcategory: "Advocacy",
            description: "Patient advocates help individuals and families understand medical diagnoses, navigate healthcare systems, and ensure that patients' rights and wishes are respected. They work in hospitals, insurance companies, or as independent consultants to resolve billing issues and improve care coordination.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "stethoscope",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Immigration Services Worker",
            category: "social_services",
            subcategory: "Advocacy",
            description: "Immigration services workers assist immigrants and refugees in navigating legal processes, accessing community resources, and adjusting to life in a new country. They provide case management, language support, and connections to education, employment, and legal aid.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "globe.americas.fill",
            color: "#1ABC9C"
        ),

        // MARK: - Youth Services

        CareerPath(
            title: "Youth Counselor",
            category: "social_services",
            subcategory: "Youth Services",
            description: "Youth counselors provide guidance, emotional support, and skill-building to young people facing challenges like family conflict, academic struggles, or mental health issues. They create safe, trusting relationships that empower youth to develop resilience and make positive choices.",
            pathway: nil,
            requiredInterests: ["social_services", "education"],
            estimatedSalary: SalaryRange(min: 36_000, max: 65_000),
            educationLevel: .bachelors,
            icon: "figure.2.arms.open",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Juvenile Probation Officer",
            category: "social_services",
            subcategory: "Youth Services",
            description: "Juvenile probation officers supervise young people who have been involved in the justice system to support their rehabilitation and help them avoid future offenses. They connect youth with counseling, education, and community programs while monitoring their compliance with court conditions.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 42_000, max: 78_000),
            educationLevel: .bachelors,
            icon: "person.badge.key.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "After-School Program Director",
            category: "social_services",
            subcategory: "Youth Services",
            description: "After-school program directors design and manage enrichment programs that provide safe, supportive environments for young people outside of school hours. They lead staff, build community partnerships, and develop activities that promote academic success and social development.",
            pathway: nil,
            requiredInterests: ["social_services", "education"],
            estimatedSalary: SalaryRange(min: 45_000, max: 80_000),
            educationLevel: .bachelors,
            icon: "clock.badge.checkmark.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Mentorship Coordinator",
            category: "social_services",
            subcategory: "Youth Services",
            description: "Mentorship coordinators match young people with caring adult mentors and manage programs that build these supportive relationships over time. They recruit and train volunteers, track outcomes, and create structured activities that help youth thrive academically and personally.",
            pathway: nil,
            requiredInterests: ["social_services", "education"],
            estimatedSalary: SalaryRange(min: 38_000, max: 65_000),
            educationLevel: .bachelors,
            icon: "person.2.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Youth Minister",
            category: "social_services",
            subcategory: "Youth Services",
            description: "Youth ministers lead faith-based programs for young people that focus on spiritual development, community service, and character building. They organize activities, provide guidance, and create welcoming environments where youth can explore their beliefs and build meaningful connections.",
            pathway: nil,
            requiredInterests: ["social_services", "education"],
            estimatedSalary: SalaryRange(min: 32_000, max: 62_000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#1ABC9C"
        ),

        // MARK: - Family Services

        CareerPath(
            title: "Family Services Coordinator",
            category: "social_services",
            subcategory: "Family Services",
            description: "Family services coordinators assess families' needs and connect them with resources like food assistance, parenting support, and healthcare to help them become stable and self-sufficient. They work in schools, nonprofits, and government agencies to support family well-being.",
            pathway: nil,
            requiredInterests: ["social_services", "health_wellness"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "house.and.flag.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Domestic Violence Advocate",
            category: "social_services",
            subcategory: "Family Services",
            description: "Domestic violence advocates provide crisis support, safety planning, and long-term assistance to survivors of intimate partner violence as they navigate leaving dangerous situations and rebuilding their lives. They work in shelters, courthouses, and hotlines to be a consistent source of help.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 36_000, max: 65_000),
            educationLevel: .bachelors,
            icon: "heart.circle.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Foster Care Case Manager",
            category: "social_services",
            subcategory: "Family Services",
            description: "Foster care case managers oversee the placement and well-being of children in the foster care system, working to ensure they are safe, supported, and moving toward a permanent, loving home. They coordinate between foster families, biological parents, courts, and service providers.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "figure.2.and.child.holdinghands",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Adoption Specialist",
            category: "social_services",
            subcategory: "Family Services",
            description: "Adoption specialists guide families through the legal, emotional, and logistical process of adopting a child, ensuring the best possible match and outcomes for both children and families. They conduct home studies, prepare documentation, and provide support before, during, and after placement.",
            pathway: nil,
            requiredInterests: ["social_services", "law_government"],
            estimatedSalary: SalaryRange(min: 40_000, max: 72_000),
            educationLevel: .bachelors,
            icon: "person.badge.plus",
            color: "#1ABC9C"
        ),

        // MARK: - Legacy Migrated

        CareerPath(
            title: "Social Worker",
            category: "social_services",
            subcategory: "Social Work",
            description: "Help individuals and families overcome challenges and access resources.",
            pathway: CareerPathways.socialWorkerPathway,
            requiredInterests: ["social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .masters,
            icon: "hands.sparkles.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Counselor",
            category: "social_services",
            subcategory: "Counseling",
            description: "Provide mental health support and guidance to clients.",
            pathway: CareerPathways.counselorPathway,
            requiredInterests: ["social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 85000),
            educationLevel: .masters,
            icon: "brain.head.profile",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Community Organizer",
            category: "social_services",
            subcategory: "Community & Advocacy",
            description: "Build community power and advocate for social change.",
            pathway: CareerPathways.communityOrganizerPathway,
            requiredInterests: ["social_services"],
            estimatedSalary: SalaryRange(min: 35000, max: 70000),
            educationLevel: .bachelors,
            icon: "person.3.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Nonprofit Director",
            category: "social_services",
            subcategory: "Nonprofit & Government",
            description: "Lead nonprofit organizations making a difference in communities.",
            pathway: CareerPathways.nonprofitDirectorPathway,
            requiredInterests: ["social_services", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50000, max: 120000),
            educationLevel: .bachelors,
            icon: "building.2.fill",
            color: "#1ABC9C"
        )
    ]
}
