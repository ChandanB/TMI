//
//  AICareerGenerator.swift
//  TMI
//
//  Created by Chandan Brown on 8/20/25.
//

import Foundation

// MARK: - AI Career Generator Service

@available(iOS 18.0, *)
final class AICareerGenerator: Sendable {
    static let shared = AICareerGenerator()
    private init() {}
    
    // MARK: - Main Career Generation Methods
    
    /// Generate intelligent careers based on search query using rule-based AI patterns
    func generateIntelligentCareers(for query: String, student: Student?) -> [Career] {
        let lowercaseQuery = query.lowercased()
        var generatedCareers: [Career] = []
        
        // Special handling for basketball and other sports to ensure we get comprehensive results
        if lowercaseQuery.contains("basketball") {
            generatedCareers = generateBasketballCareers()
        } else if lowercaseQuery.contains("football") || lowercaseQuery.contains("soccer") {
            generatedCareers = generateSportsCareers(sport: query)
        } else {
            // Determine the search context
            let searchContext = analyzeSearchContext(query: lowercaseQuery)
            
            // Generate careers based on the context
            switch searchContext.type {
            case .specificCareer:
                generatedCareers = generateSpecificCareerVariations(query: query, context: searchContext)
            case .field:
                generatedCareers = generateFieldCareers(field: query, context: searchContext)
            case .subject:
                generatedCareers = generateSubjectRelatedCareers(subject: query, context: searchContext)
            case .skill:
                generatedCareers = generateSkillBasedCareers(skill: query, context: searchContext)
            case .general:
                generatedCareers = generateGeneralCareers(for: query)
            }
        }
        
        // Apply student personalization if available
        if let student = student {
            Task {
                generatedCareers = await personalizeCareerRecommendations(careers: generatedCareers, for: student)
            }
        }
        
        return Array(generatedCareers.prefix(10)) // Limit to 10 careers
    }
    
    /// Generate career recommendations personalized to a given student profile
    @MainActor
    func generatePersonalizedCareers(for student: Student?) async -> [Career] {
        guard let student = student else { return [] }

        // Load interests from edge collection
        let interests: [Interest]
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
        } catch {
            print("[AICareerGenerator] Error loading interests: \(error.localizedDescription)")
            return []
        }

        // Use all interests as seed queries
        let queries = interests.map { $0.name }
        var allCareers: [Career] = []
        for query in queries {
            let context = analyzeSearchContext(query: query)
            // For each, generate careers using the regular logic
            switch context.type {
            case .field:
                allCareers += generateFieldCareers(field: query, context: context)
            case .subject:
                allCareers += generateSubjectRelatedCareers(subject: query, context: context)
            case .skill:
                allCareers += generateSkillBasedCareers(skill: query, context: context)
            case .specificCareer:
                allCareers += generateSpecificCareerVariations(query: query, context: context)
            case .general:
                allCareers += generateIntelligentCareers(for: query, student: student)
            }
        }
        // Remove duplicates by title+field
        var seen = Set<String>()
        let deduped = allCareers.filter { career in
            let key = career.title.lowercased() + ":" + career.field.lowercased()
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
        return Array(deduped.prefix(10))
    }
    
    // MARK: - Search Context Analysis
    
    func analyzeSearchContext(query: String) -> SearchContext {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Specific career keywords
        let careerKeywords = ["engineer", "teacher", "nurse", "scientist", "developer", "consultant", "manager", "analyst", "designer", "therapist", "coach", "trainer", "journalist", "director"]
        if careerKeywords.contains(where: { lower.contains($0) }) {
            return SearchContext(type: .specificCareer, info: nil)
        }
        
        // Skill keywords
        let skillKeywords = ["programming", "leadership", "writing", "communication", "problem solving"]
        if skillKeywords.contains(where: { lower.contains($0) }) {
            return SearchContext(type: .skill, info: nil)
        }

        // Subject keywords
        let subjectKeywords = ["math", "science", "biology", "art", "psychology"]
        if subjectKeywords.contains(where: { lower.contains($0) }) {
            return SearchContext(type: .subject, info: nil)
        }
        
        // Known fields
        let fields = ["technology", "healthcare", "education", "business", "engineering", "science"]
        if fields.contains(where: { lower.contains($0) }) {
            return SearchContext(type: .field, info: nil)
        }
        
        // Otherwise treat as general
        return SearchContext(type: .general, info: nil)
    }
    
    // MARK: - Basketball and Sports Career Generation
    
    func generateBasketballCareers() -> [Career] {
        let basketballCareers = [
            ("Basketball Player", "Sports", "Professional or amateur basketball player competing at various levels from high school to professional leagues. Requires exceptional athletic ability, teamwork, and dedication to training.", ["Basketball Skills", "Teamwork", "Physical Fitness", "Mental Toughness", "Communication"], "High school diploma minimum; college basketball experience preferred for professional levels.", 45000.0...15000000.0, "Variable based on level; professional opportunities limited but well-compensated", 0.05),
            
            ("Basketball Coach", "Sports", "Train and develop basketball players, create game strategies, and lead teams. Work at various levels from youth leagues to professional teams.", ["Leadership", "Basketball Strategy", "Communication", "Player Development", "Game Analysis"], "Bachelor's degree preferred; coaching certifications required; playing experience valuable.", 35000.0...250000.0, "Good opportunities at all levels, especially youth and high school", 0.08),
            
            ("Athletic Trainer", "Healthcare", "Provide injury prevention, treatment, and rehabilitation services for basketball players and other athletes. Work closely with medical professionals.", ["Sports Medicine", "Injury Assessment", "Rehabilitation", "Emergency Care", "Communication"], "Bachelor's degree in Athletic Training; state certification required; Master's degree increasingly preferred.", 48000.0...75000.0, "Strong growth due to increased awareness of sports injuries", 0.21),
            
            ("Sports Journalist", "Media", "Cover basketball games, interview players and coaches, and write articles or create content about basketball news and events.", ["Writing", "Communication", "Research", "Interviewing", "Sports Knowledge"], "Bachelor's degree in Journalism, Communications, or related field; portfolio of sports writing required.", 35000.0...85000.0, "Moderate growth with digital media creating new opportunities", 0.06),
            
            ("Team Manager", "Sports", "Handle administrative duties for basketball teams including scheduling, equipment management, player logistics, and operational support.", ["Organization", "Communication", "Problem Solving", "Attention to Detail", "Teamwork"], "Bachelor's degree in Sports Management, Business, or related field preferred.", 40000.0...95000.0, "Steady growth as sports organizations expand operations", 0.09),
            
            ("Basketball Scout", "Sports", "Evaluate basketball talent at various levels, provide reports on players, and help teams make informed decisions about recruitment and drafting.", ["Player Evaluation", "Basketball Knowledge", "Travel Flexibility", "Report Writing", "Networking"], "Bachelor's degree preferred; extensive basketball knowledge and networking essential.", 35000.0...150000.0, "Limited opportunities but growing with analytics integration", 0.07),
            
            ("Basketball Referee", "Sports", "Officiate basketball games at various levels, enforce rules, and ensure fair play. Requires extensive knowledge of basketball rules and regulations.", ["Rules Knowledge", "Decision Making", "Communication", "Physical Fitness", "Conflict Resolution"], "High school diploma; referee training and certification required; continuing education mandatory.", 20000.0...75000.0, "Steady demand at all levels of basketball", 0.05),
            
            ("Sports Marketing Manager", "Business", "Develop and execute marketing strategies for basketball teams, events, and products. Focus on fan engagement and revenue generation.", ["Marketing Strategy", "Digital Marketing", "Event Planning", "Social Media", "Analytics"], "Bachelor's degree in Marketing, Business, or Sports Management; experience in sports industry preferred.", 50000.0...120000.0, "Strong growth with increasing focus on fan engagement and digital marketing", 0.15),
            
            ("Sports Equipment Designer", "Design", "Design and develop basketball equipment including shoes, apparel, basketballs, and training equipment. Combine sports knowledge with design expertise.", ["Product Design", "Material Science", "3D Modeling", "Sports Knowledge", "Innovation"], "Bachelor's degree in Industrial Design, Engineering, or related field; knowledge of sports biomechanics helpful.", 55000.0...110000.0, "Good growth with technological advances in sports equipment", 0.12),
            
            ("Basketball Analyst", "Technology", "Analyze basketball performance data, create statistical models, and provide insights to teams for strategic decision-making using advanced analytics.", ["Data Analysis", "Statistics", "Basketball Knowledge", "Programming", "Critical Thinking"], "Bachelor's degree in Statistics, Data Science, or related field; strong basketball knowledge required.", 60000.0...130000.0, "Rapid growth as analytics become essential in sports", 0.25)
        ]
        
        return basketballCareers.map { (title, field, description, skills, education, salaryRange, jobOutlook, growthRate) in
            Career(
                title: title,
                field: field,
                description: description,
                skills: skills,
                education: education,
                salaryRange: salaryRange,
                jobOutlook: jobOutlook,
                growthRate: growthRate
            )
        }
    }
    
    func generateSportsCareers(sport: String) -> [Career] {
        let sportName = sport.capitalized
        let sportsCareers = [
            ("\(sportName) Player", "Sports"),
            ("\(sportName) Coach", "Sports"),
            ("Athletic Trainer", "Healthcare"),
            ("Sports Journalist", "Media"),
            ("Team Manager", "Sports"),
            ("\(sportName) Scout", "Sports"),
            ("Sports Referee", "Sports"),
            ("Sports Marketing Manager", "Business")
        ]
        
        return sportsCareers.map { (title, field) in
            let baseSalary = inferBaseSalary(for: title, field: field)
            return Career(
                title: title,
                field: field,
                description: generateCareerDescription(for: title, field: field),
                skills: generateSkills(for: title, field: field),
                education: generateEducationRequirements(for: title, field: field),
                salaryRange: Double(baseSalary * 0.8)...Double(baseSalary * 1.2),
                jobOutlook: generateJobOutlook(for: field),
                growthRate: generateGrowthRate(for: field)
            )
        }
    }
    
    // MARK: - Specific Career Type Generation
    
    func generateSpecificCareerVariations(query: String, context: SearchContext) -> [Career] {
        var careers: [Career] = []
        let baseTitle = query.capitalized
        
        // Generate variations and related careers
        let variations = [
            ("Senior \(baseTitle)", 1.2, 10000.0),
            ("Junior \(baseTitle)", 0.8, -15000.0),
            ("Lead \(baseTitle)", 1.4, 20000.0),
            ("\(baseTitle) Specialist", 1.1, 5000.0),
            ("Principal \(baseTitle)", 1.5, 30000.0)
        ]
        
        for (title, multiplier, salaryAdjustment) in variations {
            let field = inferFieldFromCareer(query)
            let baseSalary = inferBaseSalary(for: query, field: field)
            let adjustedSalary = baseSalary + salaryAdjustment
            
            let career = Career(
                title: title,
                field: field,
                description: generateCareerDescription(for: title, field: field),
                skills: generateSkills(for: title, field: field),
                education: generateEducationRequirements(for: title, field: field),
                salaryRange: Double(adjustedSalary * 0.8)...Double(adjustedSalary * 1.2),
                jobOutlook: generateJobOutlook(for: field),
                growthRate: generateGrowthRate(for: field) * multiplier
            )
            careers.append(career)
        }
        
        return careers
    }
    
    func generateFieldCareers(field: String, context: SearchContext) -> [Career] {
        let fieldMap: [String: [String]] = [
            "technology": ["Software Engineer", "Data Scientist", "UX Designer", "DevOps Engineer", "Cybersecurity Analyst", "Product Manager", "AI Engineer", "Full Stack Developer"],
            "healthcare": ["Registered Nurse", "Physical Therapist", "Medical Assistant", "Healthcare Administrator", "Pharmacist", "Medical Technologist", "Respiratory Therapist", "Occupational Therapist"],
            "education": ["Elementary Teacher", "High School Teacher", "School Counselor", "Educational Administrator", "Curriculum Developer", "Special Education Teacher", "Instructional Designer", "Academic Coach"],
            "business": ["Business Analyst", "Marketing Manager", "Sales Representative", "Human Resources Manager", "Financial Advisor", "Operations Manager", "Project Manager", "Business Consultant"],
            "engineering": ["Civil Engineer", "Mechanical Engineer", "Electrical Engineer", "Chemical Engineer", "Environmental Engineer", "Aerospace Engineer", "Biomedical Engineer", "Industrial Engineer"],
            "science": ["Research Scientist", "Lab Technician", "Environmental Scientist", "Biologist", "Chemist", "Physicist", "Geologist", "Forensic Scientist"]
        ]
        
        let careerTitles = fieldMap[field.lowercased()] ?? ["\(field.capitalized) Specialist", "\(field.capitalized) Manager", "\(field.capitalized) Consultant"]
        
        return careerTitles.map { title in
            let baseSalary = inferBaseSalary(for: title, field: field)
            return Career(
                title: title,
                field: field.capitalized,
                description: generateCareerDescription(for: title, field: field),
                skills: generateSkills(for: title, field: field),
                education: generateEducationRequirements(for: title, field: field),
                salaryRange: Double(baseSalary * 0.8)...Double(baseSalary * 1.2),
                jobOutlook: generateJobOutlook(for: field),
                growthRate: generateGrowthRate(for: field)
            )
        }
    }
    
    func generateSubjectRelatedCareers(subject: String, context: SearchContext) -> [Career] {
        let subjectCareerMap: [String: [(String, String)]] = [
            "math": [("Actuary", "Finance"), ("Data Analyst", "Technology"), ("Math Teacher", "Education"), ("Statistician", "Science")],
            "science": [("Research Scientist", "Science"), ("Lab Technician", "Healthcare"), ("Science Teacher", "Education"), ("Environmental Consultant", "Science")],
            "biology": [("Biologist", "Science"), ("Medical Doctor", "Healthcare"), ("Biotechnology Researcher", "Science"), ("Wildlife Biologist", "Science")],
            "art": [("Graphic Designer", "Arts"), ("Art Teacher", "Education"), ("Museum Curator", "Arts"), ("Art Therapist", "Healthcare")],
            "psychology": [("Psychologist", "Healthcare"), ("School Counselor", "Education"), ("Human Resources Specialist", "Business"), ("Social Worker", "Public Service")]
        ]
        
        let careerData = subjectCareerMap[subject.lowercased()] ?? [("\(subject.capitalized) Specialist", "Education")]
        
        return careerData.map { (title, field) in
            let baseSalary = inferBaseSalary(for: title, field: field)
            return Career(
                title: title,
                field: field,
                description: generateCareerDescription(for: title, field: field),
                skills: generateSkills(for: title, field: field),
                education: generateEducationRequirements(for: title, field: field),
                salaryRange: Double(baseSalary * 0.8)...Double(baseSalary * 1.2),
                jobOutlook: generateJobOutlook(for: field),
                growthRate: generateGrowthRate(for: field)
            )
        }
    }
    
    func generateSkillBasedCareers(skill: String, context: SearchContext) -> [Career] {
        // Generate careers that heavily use the specified skill
        let skillCareerMap: [String: [(String, String)]] = [
            "programming": [("Software Developer", "Technology"), ("Web Developer", "Technology"), ("Mobile App Developer", "Technology"), ("Systems Analyst", "Technology")],
            "writing": [("Technical Writer", "Business"), ("Content Creator", "Media"), ("Journalist", "Media"), ("Grant Writer", "Business")],
            "communication": [("Public Relations Specialist", "Business"), ("Marketing Coordinator", "Business"), ("Customer Success Manager", "Business"), ("Training Specialist", "Education")],
            "leadership": [("Project Manager", "Business"), ("Team Lead", "Business"), ("Department Manager", "Business"), ("Executive Director", "Business")]
        ]
        
        let careerData = skillCareerMap[skill.lowercased()] ?? [("\(skill.capitalized) Specialist", "Business")]
        
        return careerData.map { (title, field) in
            let baseSalary = inferBaseSalary(for: title, field: field)
            return Career(
                title: title,
                field: field,
                description: generateCareerDescription(for: title, field: field),
                skills: generateSkills(for: title, field: field, emphasize: skill),
                education: generateEducationRequirements(for: title, field: field),
                salaryRange: Double(baseSalary * 0.8)...Double(baseSalary * 1.2),
                jobOutlook: generateJobOutlook(for: field),
                growthRate: generateGrowthRate(for: field)
            )
        }
    }
    
    func generateGeneralCareers(for query: String) -> [Career] {
        // For general or unknown queries, generate 8-10 careers themed around the query string
        let baseTitles = [
            "Coach",
            "Analyst",
            "Manager",
            "Trainer",
            "Marketer",
            "Operations Specialist",
            "Journalist",
            "Scout",
            "Event Coordinator",
            "Consultant"
        ]
        
        // Generate careers by combining base titles with the query for thematic relevance
        var careers: [Career] = []
        for (index, baseTitle) in baseTitles.enumerated() {
            // Limit to 8-10 careers max
            if index >= 10 { break }
            
            let title = "\(baseTitle) - \(query.capitalized)"
            
            // Infer career field as query capitalized or a relevant broad category
            let field = inferFieldFromGeneralQuery(query)
            
            // Generate a realistic description incorporating the query
            let description = "A \(baseTitle.lowercased()) specializing in \(query.lowercased()). Responsible for applying expertise in \(query.lowercased()) to improve outcomes and drive success in related projects."
            
            // Skills including the query as a core skill and some generic skills
            let skills = generateSkillsForGeneralCareer(query: query, baseTitle: baseTitle)
            
            // Education requirements based on the base title
            let education = generateEducationForGeneralCareer(baseTitle: baseTitle)
            
            // Salary range based on field and role seniority
            let baseSalary = inferBaseSalary(for: baseTitle, field: field)
            let salaryRange = Double(baseSalary * 0.75)...Double(baseSalary * 1.25)
            
            // Job outlook and growth rate assumptions
            let jobOutlook = generateJobOutlook(for: field)
            let growthRate = generateGrowthRate(for: field)
            
            let career = Career(
                title: title,
                field: field,
                description: description,
                skills: skills,
                education: education,
                salaryRange: salaryRange,
                jobOutlook: jobOutlook,
                growthRate: growthRate
            )
            
            careers.append(career)
        }
        
        return careers
    }
}

// MARK: - Career Generation Helpers

extension AICareerGenerator {
    
    // Helper to infer a plausible field for general query careers
    func inferFieldFromGeneralQuery(_ query: String) -> String {
        // Attempt to map some keywords in query to known fields
        let lower = query.lowercased()
        let fieldMap: [String: String] = [
            "sport": "Sports",
            "technology": "Technology",
            "business": "Business",
            "education": "Education",
            "health": "Healthcare",
            "media": "Media",
            "finance": "Finance",
            "art": "Creative Arts",
            "science": "Science"
        ]
        for (key, field) in fieldMap {
            if lower.contains(key) {
                return field
            }
        }
        // Default fallback
        return query.capitalized
    }
    
    // Helper to generate plausible skills for a general career themed around the query
    func generateSkillsForGeneralCareer(query: String, baseTitle: String) -> [String] {
        var skills = [String]()
        // Core skill is the query name capitalized
        skills.append(query.capitalized)
        
        // Add some generic skills based on baseTitle category
        switch baseTitle.lowercased() {
        case "coach", "trainer", "scout":
            skills += ["Communication", "Leadership", "Teamwork", "Motivation"]
        case "analyst", "consultant":
            skills += ["Data Analysis", "Problem Solving", "Critical Thinking", "Presentation"]
        case "manager", "operations specialist", "event coordinator":
            skills += ["Project Management", "Organization", "Strategic Planning", "Multitasking"]
        case "marketer", "journalist":
            skills += ["Content Creation", "Creativity", "Research", "Social Media"]
        default:
            skills += ["Adaptability", "Collaboration", "Time Management"]
        }
        
        // Return unique sorted skills, limited to 6
        return Array(Set(skills)).prefix(6).sorted()
    }
    
    // Helper to generate education requirements based on baseTitle
    func generateEducationForGeneralCareer(baseTitle: String) -> String {
        switch baseTitle.lowercased() {
        case "coach", "trainer", "scout":
            return "Relevant certification or degree in the field; practical experience preferred."
        case "analyst", "consultant":
            return "Bachelor's degree in related field; advanced degrees or certifications are a plus."
        case "manager", "operations specialist", "event coordinator":
            return "Bachelor's degree in Business, Management, or related field; leadership experience preferred."
        case "marketer":
            return "Bachelor's degree in Marketing, Communications, or related field."
        case "journalist":
            return "Bachelor's degree in Journalism, Communications, or related discipline."
        default:
            return "Bachelor's degree or equivalent experience in related field."
        }
    }
    
    func generateCareerDescription(for title: String, field: String) -> String {
        let templates = [
            "Professionals in this role focus on developing innovative solutions and implementing best practices within the \(field.lowercased()) industry. They collaborate with cross-functional teams to deliver high-quality results that meet organizational objectives.",
            "This position involves analyzing complex challenges, designing strategic approaches, and executing projects that drive success in the \(field.lowercased()) sector. Strong analytical and communication skills are essential for success.",
            "Work involves specialized knowledge in \(field.lowercased()) principles, combined with practical application of industry-standard tools and methodologies. Professionals in this role contribute to organizational growth and innovation.",
            "This career path offers opportunities to make meaningful contributions to the \(field.lowercased()) field through research, development, and implementation of cutting-edge practices and technologies."
        ]
        return templates.randomElement() ?? templates[0]
    }
    
    func generateSkills(for title: String, field: String, emphasize: String? = nil) -> [String] {
        let baseSkills = ["Problem Solving", "Communication", "Critical Thinking", "Teamwork", "Adaptability"]
        
        let fieldSkills: [String: [String]] = [
            "technology": ["Programming", "Data Analysis", "System Design", "Technical Documentation", "Agile Methodology"],
            "healthcare": ["Patient Care", "Medical Knowledge", "Empathy", "Attention to Detail", "Clinical Skills"],
            "education": ["Curriculum Development", "Classroom Management", "Student Assessment", "Instructional Design", "Educational Technology"],
            "business": ["Strategic Planning", "Project Management", "Financial Analysis", "Leadership", "Market Research"],
            "engineering": ["Technical Design", "Mathematical Analysis", "CAD Software", "Quality Assurance", "Regulatory Compliance"],
            "science": ["Research Methodology", "Data Collection", "Laboratory Techniques", "Statistical Analysis", "Scientific Writing"]
        ]
        
        let specificSkills = fieldSkills[field.lowercased()] ?? ["Industry Knowledge", "Technical Expertise", "Professional Standards"]
        
        var allSkills = baseSkills + specificSkills
        
        if let emphasizedSkill = emphasize {
            allSkills.insert(emphasizedSkill.capitalized, at: 0)
        }
        
        return Array(Set(allSkills).prefix(6)).sorted()
    }
    
    func generateEducationRequirements(for title: String, field: String) -> String {
        let educationMap: [String: String] = [
            "technology": "Bachelor's degree in Computer Science, Software Engineering, or related field. Some positions may require specialized certifications or advanced degrees.",
            "healthcare": "Relevant healthcare degree and professional licensing required. May require specialized training, certifications, and continuing education.",
            "education": "Bachelor's degree in Education or subject area, plus state teaching certification. Some positions may require a Master's degree or specialized endorsements.",
            "business": "Bachelor's degree in Business, Management, or related field. MBA or professional certifications may be preferred for senior roles.",
            "engineering": "Bachelor's degree in Engineering or related technical field. Professional Engineer (PE) license may be required for some positions.",
            "science": "Bachelor's degree in relevant scientific field. Advanced degrees (Master's or Ph.D.) may be required for research positions."
        ]
        
        return educationMap[field.lowercased()] ?? "Bachelor's degree in relevant field. Additional certifications or specialized training may be beneficial."
    }
    
    func generateJobOutlook(for field: String) -> String {
        let outlookMap: [String: String] = [
            "technology": "Strong growth expected due to continued digital transformation and innovation across industries.",
            "healthcare": "Excellent growth prospects driven by aging population and healthcare expansion.",
            "education": "Stable growth with opportunities varying by specialization and geographic location.",
            "business": "Moderate growth with excellent opportunities for skilled professionals.",
            "engineering": "Good growth prospects, particularly in emerging technologies and sustainable solutions.",
            "science": "Steady growth with strong demand for research and development professionals."
        ]
        
        return outlookMap[field.lowercased()] ?? "Positive outlook with opportunities for qualified professionals."
    }
    
    func generateGrowthRate(for field: String) -> Double {
        let growthMap: [String: Double] = [
            "technology": 0.22,
            "healthcare": 0.18,
            "education": 0.08,
            "business": 0.12,
            "engineering": 0.14,
            "science": 0.10
        ]
        
        return growthMap[field.lowercased()] ?? 0.08
    }
    
    func inferFieldFromCareer(_ career: String) -> String {
        let careerLower = career.lowercased()
        
        if careerLower.contains("engineer") || careerLower.contains("developer") || careerLower.contains("programmer") {
            return "Technology"
        } else if careerLower.contains("nurse") || careerLower.contains("doctor") || careerLower.contains("therapist") {
            return "Healthcare"
        } else if careerLower.contains("teacher") || careerLower.contains("educator") || careerLower.contains("instructor") {
            return "Education"
        } else if careerLower.contains("manager") || careerLower.contains("analyst") || careerLower.contains("consultant") {
            return "Business"
        } else if careerLower.contains("scientist") || careerLower.contains("researcher") {
            return "Science"
        } else {
            return "Business"
        }
    }
    
    func inferBaseSalary(for career: String, field: String) -> Double {
        let baseSalaries: [String: Double] = [
            "technology": 95000,
            "healthcare": 75000,
            "education": 55000,
            "business": 70000,
            "engineering": 80000,
            "science": 68000
        ]
        
        let baseSalary = baseSalaries[field.lowercased()] ?? 60000
        
        // Adjust based on career level
        if career.lowercased().contains("senior") || career.lowercased().contains("lead") {
            return baseSalary * 1.3
        } else if career.lowercased().contains("junior") || career.lowercased().contains("entry") {
            return baseSalary * 0.7
        } else if career.lowercased().contains("principal") || career.lowercased().contains("director") {
            return baseSalary * 1.6
        }
        
        return baseSalary
    }
    
    @MainActor
    func personalizeCareerRecommendations(careers: [Career], for student: Student) async -> [Career] {
        // Load interests from edge collection
        let interests: [Interest]
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
        } catch {
            print("[AICareerGenerator] Error loading interests: \(error.localizedDescription)")
            interests = []
        }

        // Score careers based on student interests and academic performance
        let scoredCareers = careers.map { career -> (Career, Double) in
            var score = 0.0

            // Interest alignment scoring
            for interest in interests {
                if career.skills.contains(where: { $0.lowercased().contains(interest.name.lowercased()) }) {
                    score += 0.3
                }
                if career.field.lowercased().contains(interest.name.lowercased()) {
                    score += 0.5
                }
            }
            
            // Academic performance scoring
            if let academicPerformance = student.academicPerformance {
                for subject in academicPerformance.subjects {
                    let gradeValue = gradeToNumeric(subject.grade)
                    if career.field.lowercased().contains(subject.name.lowercased()) && gradeValue >= 3.0 {
                        score += gradeValue * 0.2
                    }
                }
            }
            
            return (career, score)
        }
        
        // Return careers sorted by personalization score
        return scoredCareers.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
    
    func gradeToNumeric(_ grade: String) -> Double {
        switch grade.uppercased() {
        case "A+", "A": return 4.0
        case "A-": return 3.7
        case "B+": return 3.3
        case "B": return 3.0
        case "B-": return 2.7
        case "C+": return 2.3
        case "C": return 2.0
        case "C-": return 1.7
        case "D": return 1.0
        default: return 0.0
        }
    }
    
    // MARK: - Sample Response Generation
    
    func generateSampleCareerSearchResponse(query: String, student: Student?) -> AICareerResponse {
        // Use intelligent career generation instead of just filtering sample data
        let aiGeneratedCareers = generateIntelligentCareers(for: query, student: student)
        
        let insights = CareerDiscoveryInsights(
            totalCareersExplored: aiGeneratedCareers.count,
            personalizedRecommendations: student != nil ? min(aiGeneratedCareers.count, 5) : 0,
            topInterestCategory: inferTopCategory(from: query),
            strongestCareerFields: Array(Set(aiGeneratedCareers.map { $0.field }).prefix(3)),
            emergingOpportunities: aiGeneratedCareers.filter { $0.growthRate > 0.15 }.prefix(3).map { $0 },
            skillGaps: generateSkillGaps(for: query, student: student),
            nextSteps: generateNextSteps(for: query, student: student)
        )
        
        return AICareerResponse(careers: aiGeneratedCareers, insights: insights)
    }

    func generateSampleAICareerResponse(for student: Student?) async -> AICareerResponse {
        let personalizedCareers = await generatePersonalizedCareers(for: student)
        let topCategory: String = await {
            if let student = student {
                do {
                    let interests = try await student.fetchInterestsFromEdgeCollection()
                    let categories = interests.flatMap { $0.category }
                    return categories.first?.rawValue ?? "General"
                } catch {
                    return "General"
                }
            } else {
                return "General"
            }
        }()
        let sampleInsights = CareerDiscoveryInsights(
            totalCareersExplored: personalizedCareers.count,
            personalizedRecommendations: student != nil ? personalizedCareers.count : 0,
            topInterestCategory: topCategory,
            strongestCareerFields: Array(Set(personalizedCareers.map { $0.field }).prefix(3)),
            emergingOpportunities: personalizedCareers.filter { $0.growthRate > 0.15 }.prefix(3).map { $0 },
            skillGaps: student != nil ? await generatePersonalizedSkillGaps(for: student!) : [],
            nextSteps: student != nil ? generatePersonalizedNextSteps(for: student!) : []
        )
        return AICareerResponse(careers: personalizedCareers, insights: sampleInsights)
    }
    
    func inferTopCategory(from query: String) -> String {
        let categoryMap: [String: String] = [
            "technology": "STEM",
            "healthcare": "Service",
            "education": "Social",
            "business": "Leadership",
            "engineering": "STEM",
            "science": "STEM",
            "art": "Creative"
        ]
        
        for (key, value) in categoryMap {
            if query.lowercased().contains(key) {
                return value
            }
        }
        
        return "General"
    }
    
    func generateSkillGaps(for query: String, student: Student?) -> [String] {
        let queryLower = query.lowercased()
        
        if queryLower.contains("technology") || queryLower.contains("software") {
            return ["Programming Languages", "Cloud Computing", "Data Analysis", "Cybersecurity Basics"]
        } else if queryLower.contains("healthcare") {
            return ["Medical Terminology", "Patient Communication", "Healthcare Technology", "Evidence-Based Practice"]
        } else if queryLower.contains("business") {
            return ["Financial Literacy", "Project Management", "Digital Marketing", "Data Analytics"]
        } else {
            return ["Digital Literacy", "Communication Skills", "Critical Thinking", "Adaptability"]
        }
    }
    
    func generateNextSteps(for query: String, student: Student?) -> [String] {
        let baseSteps = [
            "Research \(query.lowercased()) careers in detail",
            "Connect with professionals in the field",
            "Explore relevant education and training programs"
        ]
        
        if student != nil {
            let personalizedSteps = [
                "Complete career assessments to identify strengths",
                "Seek internships or volunteer opportunities",
                "Join student organizations related to \(query.lowercased())",
                "Develop a portfolio showcasing relevant skills"
            ]
            return baseSteps + personalizedSteps.prefix(2)
        }
        
        return baseSteps
    }
    
    func generatePersonalizedSkillGaps(for student: Student) async -> [String] {
        var skillGaps: [String] = []

        // Load interests from edge collection
        let interests: [Interest]
        do {
            interests = try await student.fetchInterestsFromEdgeCollection()
        } catch {
            print("[AICareerGenerator] Error loading interests: \(error.localizedDescription)")
            interests = []
        }

        let interestCategories = interests.flatMap { $0.category }
        let categoryStrings = interestCategories.map { $0.rawValue.lowercased() }

        if categoryStrings.contains(where: { $0.contains("stem") || $0.contains("science") || $0.contains("math") }) {
            skillGaps.append(contentsOf: ["Advanced Mathematics", "Programming", "Data Analysis"])
        }

        if categoryStrings.contains(where: { $0.contains("creative") || $0.contains("art") }) {
            skillGaps.append(contentsOf: ["Design Software", "Creative Writing", "Digital Media"])
        }

        if categoryStrings.contains(where: { $0.contains("social") || $0.contains("leadership") }) {
            skillGaps.append(contentsOf: ["Public Speaking", "Leadership", "Conflict Resolution"])
        }

        return Array(Set(skillGaps).prefix(5))
    }
    
    func generatePersonalizedNextSteps(for student: Student) -> [String] {
        var nextSteps: [String] = [
            "Complete a comprehensive career assessment",
            "Research colleges and programs aligned with your interests"
        ]
        
        // Add grade-specific recommendations
        if student.grade.contains("9") || student.grade.contains("10") {
            nextSteps.append("Explore extracurricular activities related to your interests")
            nextSteps.append("Consider job shadowing opportunities")
        } else {
            nextSteps.append("Apply for internships or part-time jobs in your field of interest")
            nextSteps.append("Begin college application research and preparation")
        }
        
        return nextSteps
    }
}

