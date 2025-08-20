//
//  AIPromptBuilder.swift
//  TMI
//
//  Created by Chandan Brown on 8/20/25.
//

import Foundation

// MARK: - AI Prompt Builder Service

@available(iOS 18.0, *)
final class AIPromptBuilder: Sendable {
    static let shared = AIPromptBuilder()
    private init() {}
    
    // MARK: - Career Prompt Generation
    
    func generateCareerSearchPrompt(query: String, student: Student?) -> String {
        var prompt = """
        You are an expert career counselor. Generate comprehensive career recommendations based on the search query: "\(query)"

        **TASK:** 
        Create careers related to "\(query)" - this could be a sport (basketball), field (technology), subject (biology), skill (writing), or specific job title.

        **OUTPUT FORMAT:** 
        Respond with ONLY a valid JSON object in this exact structure:

        {
          "careers": [
            {
              "id": "uuid-string",
              "title": "Career Title",
              "field": "Industry Category",
              "description": "Detailed career description (2-3 sentences)",
              "skills": ["Skill1", "Skill2", "Skill3", "Skill4", "Skill5"],
              "education": "Education requirements description",
              "salaryRangeLowerBound": 50000,
              "salaryRangeUpperBound": 90000,
              "jobOutlook": "Job market outlook description",
              "growthRate": 0.15
            }
          ],
          "insights": {
            "totalCareersExplored": 8,
            "personalizedRecommendations": 5,
            "topInterestCategory": "Sports",
            "strongestCareerFields": ["Sports", "Media", "Business"],
            "emergingOpportunities": [],
            "skillGaps": ["Leadership", "Communication"],
            "nextSteps": ["Research specific roles", "Network with professionals"],
            "generatedAt": 1703097600
          }
        }

        **MANDATORY REQUIREMENTS FOR "\(query)":**
        - You MUST generate EXACTLY 8-10 DIFFERENT careers related to "\(query)"
        - DO NOT generate just 1 career - this is unacceptable and will be rejected
        - For basketball: include Basketball Player, Basketball Coach, Athletic Trainer, Sports Journalist, Team Manager, Scout, Referee, Sports Marketing Manager, Sports Equipment Designer, Basketball Analyst
        - For technology: include Software Developer, Data Scientist, Cybersecurity Analyst, UX Designer, Product Manager, DevOps Engineer, AI Engineer, Cybersecurity Specialist
        - For any field: provide diverse roles across different experience levels and specializations
        - Use realistic 2024-2025 salary ranges in USD
        - Include diverse career levels (entry to senior)
        - Ensure all skills, education, and descriptions are accurate and unique
        - Each career MUST have a different "id" value (use uuid-style strings)

        **ABSOLUTELY CRITICAL:** 
        1. Return ONLY the JSON object, no additional text
        2. The "careers" array MUST contain AT LEAST 8 different career objects
        3. Each career must have a unique title and description
        4. If you generate fewer than 8 careers, the response will be considered invalid
        5. For basketball specifically, you MUST include these diverse roles: Player, Coach, Athletic Trainer, Sports Journalist, Team Manager, Scout, Referee, Marketing Manager
        """

        if let student = student {
            prompt += """
            
            **STUDENT PERSONALIZATION:**
            - Name: \(student.name)
            - Grade: \(student.grade)
            - Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
            - Hobbies: \(student.hobbies.map { $0.name }.joined(separator: ", "))
            - Academic Performance (GPA): \(student.academicPerformance?.gpa ?? 0.0)
            
            **PERSONALIZATION INSTRUCTIONS:**
            - Prioritize careers within the search domain that align with student interests
            - Adjust education requirements suggestions based on current grade level
            - Include student-appropriate entry pathways and progression routes
            - Tailor skill gaps and next steps specifically for this student's profile
            """
        }

        prompt += "\n\nGenerate the JSON response focusing on careers related to \"\(query)\" now:"
        return prompt
    }

    func generateCareerPrompt(for student: Student?) -> String {
        var prompt = """
        Generate a JSON object containing an array of diverse career profiles and a career discovery insights summary.
        
        **CAREER PROFILE STRUCTURE:**
        Each career profile in the 'careers' array should have the following keys:
        - \"id\": String (UUID)
        - \"title\": String (e.g., \"Software Engineer\")
        - \"field\": String (e.g., \"Technology\", \"Healthcare\", \"Business\")
        - \"description\": String (detailed overview)
        - \"skills\": [String] (key skills required)
        - \"education\": String (typical education path)
        - \"salaryRange\": {\"lowerBound\": Double, \"upperBound\": Double} (annual salary range in USD)
        - \"jobOutlook\": String (e.g., \"Rapid growth\", \"Stable\", \"Declining\")
        - \"growthRate\": Double (e.g., 0.22 for 22% growth)

        **CAREER DISCOVERY INSIGHTS STRUCTURE:**
        The 'insights' object should have the following keys:
        - \"totalCareersExplored\": Int
        - \"personalizedRecommendations\": Int
        - \"topInterestCategory\": String
        - \"strongestCareerFields\": [String]
        - \"emergingOpportunities\": [Career] (array of Career objects)
        - \"skillGaps\": [String]
        - \"nextSteps\": [String]
        - \"generatedAt\": Double (Unix timestamp)

        **INSTRUCTIONS:**
        - Generate 10-15 diverse career profiles.
        - Ensure 'salaryRange' values are realistic.
        - 'growthRate' should be a decimal (e.g., 0.15 for 15%).
        - For 'insights', populate based on the generated careers and any provided student data.
        - 'emergingOpportunities' should be a subset of the generated careers with high growth potential.
        - 'skillGaps' and 'nextSteps' should be relevant to the generated careers and student profile.
        """

        if let student = student {
            prompt += """
            
            **STUDENT PROFILE FOR PERSONALIZATION:**
            - Name: \(student.name)
            - Grade: \(student.grade)
            - Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
            - Hobbies: \(student.hobbies.map { $0.name }.joined(separator: ", "))
            - Academic Performance (GPA): \(student.academicPerformance?.gpa ?? 0.0)
            - Academic Subjects: \(student.academicPerformance?.subjects.map { "\($0.name) (\($0.grade))" }.joined(separator: ", ") ?? "N/A")
            
            **PERSONALIZATION FOCUS:**
            - Prioritize careers that align with the student's interests, hobbies, and academic strengths.
            - Identify specific skill gaps for this student based on recommended careers.
            - Suggest actionable next steps tailored to this student's profile.
            """
        }
        
        prompt += "\n\nGenerate the JSON response now:"
        return prompt
    }
    
    // MARK: - Insights Analysis Prompt Generation
    
    func generateAnalysisPrompt(from context: [String: Any]) -> String {
        let totalStudents = context["totalStudents"] as? Int ?? 0
        let completionRate = context["completionRate"] as? Double ?? 0
        let alignmentRate = context["alignmentRate"] as? Double ?? 0
        let engagementTrend = context["engagementTrend"] as? String ?? "stable"
        let recentActivities = context["recentActivities"] as? Int ?? 0
        let activePlans = context["activePlans"] as? Int ?? 0
        let interestsIdentified = context["interestsIdentified"] as? Int ?? 0
        
        let prompt = """
        Analyze the following TMI (Tangible Modification Intervention) educational data and provide actionable insights:

        **STUDENT POPULATION METRICS:**
        - Total Students: \(totalStudents)
        - Survey Completion Rate: \(String(format: "%.1f", completionRate * 100))%
        - Plan Alignment Rate: \(String(format: "%.1f", alignmentRate * 100))%
        - Active TMI Plans: \(activePlans)
        - Interests Identified: \(interestsIdentified)
        - Recent Activities (7 days): \(recentActivities)
        - Engagement Trend: \(engagementTrend)

        **ANALYSIS REQUIREMENTS:**
        
        1. **Critical Issues Identification**: Identify any urgent concerns requiring immediate intervention
        2. **Engagement Pattern Analysis**: Analyze student engagement patterns and predict future trends
        3. **Intervention Effectiveness**: Evaluate current TMI plan effectiveness and coverage gaps
        4. **Predictive Insights**: Forecast potential outcomes and success likelihood
        5. **Actionable Recommendations**: Provide specific, prioritized action items for educators
        
        **OUTPUT FORMAT:**
        Return insights as JSON array with this structure:
        {
            "insights": [
                {
                    "title": "Clear, concise insight title",
                    "description": "Detailed explanation with specific metrics and context",
                    "confidence": 0.85,
                    "priority": "high|medium|low|critical",
                    "category": "engagement|alignment|performance|recommendations|trends|interventions",
                    "actionItems": ["Specific action 1", "Specific action 2"],
                    "dataPoints": ["Supporting metric 1", "Supporting metric 2"]
                }
            ]
        }
        
        **FOCUS AREAS:**
        - Provide 3-6 highest-priority insights
        - Include confidence scores (0.0-1.0) based on data quality and pattern strength
        - Prioritize actionable recommendations over general observations
        - Consider both immediate needs and long-term trends
        - Highlight both concerning patterns and positive achievements
        
        Generate insights now:
        """
        
        return prompt
    }
    
    // MARK: - Student Specific Prompt Generation
    
    func generateStudentSkillGapsPrompt(for student: Student) -> String {
        return """
        Analyze this student's profile and identify skill gaps for career development:
        
        **STUDENT PROFILE:**
        - Name: \(student.name)
        - Grade: \(student.grade)
        - Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
        - Hobbies: \(student.hobbies.map { $0.name }.joined(separator: ", "))
        - Academic Performance (GPA): \(student.academicPerformance?.gpa ?? 0.0)
        
        **TASK:**
        Identify 3-5 key skill gaps that this student should develop for future career success based on their interests and academic profile.
        
        **OUTPUT FORMAT:**
        Return a JSON array of skill gaps:
        ["Skill Gap 1", "Skill Gap 2", "Skill Gap 3"]
        """
    }
    
    func generateStudentNextStepsPrompt(for student: Student) -> String {
        return """
        Generate personalized next steps for this student's career development:
        
        **STUDENT PROFILE:**
        - Name: \(student.name)
        - Grade: \(student.grade)
        - Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
        - Hobbies: \(student.hobbies.map { $0.name }.joined(separator: ", "))
        - Academic Performance (GPA): \(student.academicPerformance?.gpa ?? 0.0)
        
        **TASK:**
        Create 3-5 specific, actionable next steps this student can take to advance their career exploration and development.
        
        **OUTPUT FORMAT:**
        Return a JSON array of next steps:
        ["Next step 1", "Next step 2", "Next step 3"]
        """
    }
    
    // MARK: - Specialized Prompt Templates
    
    func generateInterventionPlanningPrompt(for student: Student, currentChallenges: [String]) -> String {
        return """
        Design an intervention plan for this student based on their profile and current challenges:
        
        **STUDENT PROFILE:**
        - Name: \(student.name)
        - Grade: \(student.grade)
        - Interests: \(student.interests.map { $0.name }.joined(separator: ", "))
        - Current Challenges: \(currentChallenges.joined(separator: ", "))
        
        **TASK:**
        Create a comprehensive intervention plan including:
        1. Root cause analysis
        2. Specific intervention strategies
        3. Timeline and milestones
        4. Success metrics
        
        **OUTPUT FORMAT:**
        Return as structured JSON with intervention details.
        """
    }
    
    func generateEngagementAnalysisPrompt(engagementData: [EngagementData]) -> String {
        let dataString = engagementData.map { 
            let dayInfo = $0.day ?? "Unknown"
            return "Day: \(dayInfo), Week: \($0.week), Level: \($0.engagementLevel)" 
        }.joined(separator: "; ")
        
        return """
        Analyze student engagement patterns from this data:
        
        **ENGAGEMENT DATA:**
        \(dataString)
        
        **ANALYSIS REQUIREMENTS:**
        1. Identify trends and patterns
        2. Predict future engagement levels
        3. Recommend intervention strategies
        4. Highlight risk factors
        
        **OUTPUT FORMAT:**
        Return comprehensive analysis as structured JSON.
        """
    }
}
