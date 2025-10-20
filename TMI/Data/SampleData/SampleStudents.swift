//
//  SampleStudents.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation

extension Student {
    static var comprehensiveSampleStudents: [Student] {
        return [
            // MARK: - High Engagement Students
            Student(
                name: "Alex Chen",
                grade: "10",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -15, to: Date()) ?? Date(),
                studentID: "ST-001",
                interests: [
                    Interest(name: "Robotics", category: [.technology, .science]),
                    Interest(name: "Computer Programming", category: [.technology]),
                    Interest(name: "Arduino Projects", category: [.technology]),
                    Interest(name: "Video Game Development", category: [.gaming, .technology])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_alex_001",
                        surveyName: "Interest & Career Assessment",
                        date: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                        isComplete: true,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What subjects do you enjoy most?",
                                answer: "Computer Science, Mathematics, Physics"
                            ),
                            SurveyResult.SurveyResponse(
                                questionID: "q2",
                                question: "What do you want to do after graduation?",
                                answer: "Study Computer Engineering and work in robotics"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 3.8,
                    subjects: [
                        SubjectPerformance(name: "Computer Science", grade: "A", score: 0.95, interestAlignment: 0.98),
                        SubjectPerformance(name: "Mathematics", grade: "A-", score: 0.88, interestAlignment: 0.85),
                        SubjectPerformance(name: "Physics", grade: "B+", score: 0.85, interestAlignment: 0.92),
                        SubjectPerformance(name: "English", grade: "B", score: 0.82, interestAlignment: 0.45)
                    ],
                    strengths: ["Problem-solving", "Logical thinking", "Technical skills"],
                    areasForImprovement: ["Communication skills", "Group presentation skills"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-60 * 24 * 60 * 60), score: 0.75, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-30 * 24 * 60 * 60), score: 0.85, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-7 * 24 * 60 * 60), score: 0.92, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-21 * 24 * 60 * 60),
                        author: "Mr. Patterson",
                        content: "Alex shows exceptional aptitude in programming and has been helping other students. Recommending for advanced placement.",
                        category: .academic
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-2 * 24 * 60 * 60)
            ),
            
            // MARK: - Creative Arts Student
            Student(
                name: "Maria Rodriguez",
                grade: "11",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date(),
                studentID: "ST-002",
                interests: [
                    Interest(name: "Creative Writing", category: [.literature, .arts]),
                    Interest(name: "Drama & Theater", category: [.arts, .entertainment]),
                    Interest(name: "Digital Art", category: [.arts, .technology]),
                    Interest(name: "Poetry Writing", category: [.arts, .literature]),
                    Interest(name: "Digital Photography", category: [.arts, .technology]),
                    Interest(name: "Theater Performance", category: [.arts, .entertainment])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_maria_001",
                        surveyName: "Creative Expression Assessment",
                        date: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                        isComplete: true,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "How do you best express yourself?",
                                answer: "Through writing stories and performing on stage"
                            ),
                            SurveyResult.SurveyResponse(
                                questionID: "q2",
                                question: "What career paths interest you?",
                                answer: "Journalism, screenwriting, or theater directing"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 3.6,
                    subjects: [
                        SubjectPerformance(name: "English", grade: "A", score: 0.94, interestAlignment: 0.95),
                        SubjectPerformance(name: "Drama", grade: "A", score: 0.96, interestAlignment: 0.98),
                        SubjectPerformance(name: "History", grade: "B+", score: 0.87, interestAlignment: 0.75),
                        SubjectPerformance(name: "Mathematics", grade: "C+", score: 0.72, interestAlignment: 0.25)
                    ],
                    strengths: ["Creative expression", "Public speaking", "Storytelling"],
                    areasForImprovement: ["Mathematics skills", "Scientific reasoning"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-45 * 24 * 60 * 60), score: 0.80, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-20 * 24 * 60 * 60), score: 0.88, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-5 * 24 * 60 * 60), score: 0.85, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-15 * 24 * 60 * 60),
                        author: "Ms. Thompson",
                        content: "Maria's creative writing has improved dramatically. She's been selected for the state writing competition.",
                        category: .academic
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-1 * 24 * 60 * 60)
            ),
            
            // MARK: - Sports-Focused Student
            Student(
                name: "Jordan Williams",
                grade: "12",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -17, to: Date()) ?? Date(),
                studentID: "ST-003",
                interests: [
                    Interest(name: "Basketball", category: [.sports]),
                    Interest(name: "Sports Medicine", category: [.science, .wellness]),
                    Interest(name: "Team Leadership", category: [.leadership]),
                    Interest(name: "Fitness Training", category: [.sports, .wellness]),
                    Interest(name: "Sports Statistics Analysis", category: [.mathematics, .sports])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_jordan_001",
                        surveyName: "Athletics & Career Planning",
                        date: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                        isComplete: true,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What motivates you most?",
                                answer: "Leading my team to victory and helping teammates improve"
                            ),
                            SurveyResult.SurveyResponse(
                                questionID: "q2",
                                question: "Future career interests?",
                                answer: "Physical therapy, sports coaching, or athletic training"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 3.4,
                    subjects: [
                        SubjectPerformance(name: "Physical Education", grade: "A", score: 0.98, interestAlignment: 0.99),
                        SubjectPerformance(name: "Biology", grade: "B+", score: 0.85, interestAlignment: 0.80),
                        SubjectPerformance(name: "Mathematics", grade: "B", score: 0.80, interestAlignment: 0.60),
                        SubjectPerformance(name: "English", grade: "B-", score: 0.75, interestAlignment: 0.40)
                    ],
                    strengths: ["Leadership", "Team collaboration", "Physical coordination"],
                    areasForImprovement: ["Written communication", "Study consistency"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-90 * 24 * 60 * 60), score: 0.70, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-45 * 24 * 60 * 60), score: 0.82, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-10 * 24 * 60 * 60), score: 0.88, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                        author: "Coach Martinez",
                        content: "Jordan has shown exceptional leadership as team captain. Academic performance improving with sports-integrated learning.",
                        category: .behavioral
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-3 * 24 * 60 * 60)
            ),
            
            // MARK: - Struggling Student - Needs TMI Support
            Student(
                name: "Taylor Johnson",
                grade: "9",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -14, to: Date()) ?? Date(),
                studentID: "ST-004",
                interests: [
                    Interest(name: "Music Production", category: [.music, .technology]),
                    Interest(name: "Social Media", category: [.entertainment, .technology]),
                    Interest(name: "Making Beats", category: [.music, .technology]),
                    Interest(name: "TikTok Creation", category: [.entertainment, .social]),
                    Interest(name: "Skateboarding", category: [.sports])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_taylor_001",
                        surveyName: "Interest Discovery Survey",
                        date: Date().addingTimeInterval(-5 * 24 * 60 * 60),
                        isComplete: false,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What do you enjoy doing in your free time?",
                                answer: "Making music and skateboarding with friends"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 2.1,
                    subjects: [
                        SubjectPerformance(name: "Music", grade: "B", score: 0.82, interestAlignment: 0.90),
                        SubjectPerformance(name: "Art", grade: "C+", score: 0.70, interestAlignment: 0.75),
                        SubjectPerformance(name: "English", grade: "D+", score: 0.62, interestAlignment: 0.30),
                        SubjectPerformance(name: "Mathematics", grade: "D", score: 0.58, interestAlignment: 0.20),
                        SubjectPerformance(name: "Science", grade: "D", score: 0.55, interestAlignment: 0.25)
                    ],
                    strengths: ["Creative expression", "Peer relationships"],
                    areasForImprovement: ["Study habits", "Assignment completion", "Academic engagement"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-60 * 24 * 60 * 60), score: 0.35, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-30 * 24 * 60 * 60), score: 0.40, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-15 * 24 * 60 * 60), score: 0.45, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-20 * 24 * 60 * 60),
                        author: "Ms. Garcia",
                        content: "Taylor shows genuine talent in music but struggles with traditional academic subjects. Recommend TMI intervention focusing on music-integrated learning.",
                        category: .tmiPlan
                    ),
                    StudentNote(
                        date: Date().addingTimeInterval(-10 * 24 * 60 * 60),
                        author: "Mr. Davis",
                        content: "Attendance issues continue. Family reports challenges at home. Consider social worker referral.",
                        category: .behavioral
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-4 * 24 * 60 * 60)
            ),
            
            // MARK: - Science-Focused Student
            Student(
                name: "Aisha Patel",
                grade: "11",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date(),
                studentID: "ST-005",
                interests: [
                    Interest(name: "Environmental Science", category: [.science, .outdoors, .socialCauses]),
                    Interest(name: "Marine Biology", category: [.science, .outdoors]),
                    Interest(name: "Climate Action", category: [.socialCauses, .science]),
                    Interest(name: "Nature Photography", category: [.arts, .outdoors]),
                    Interest(name: "Gardening", category: [.outdoors, .science]),
                    Interest(name: "Science Fair Projects", category: [.science, .academics])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_aisha_001",
                        surveyName: "STEM Interest Assessment",
                        date: Date().addingTimeInterval(-12 * 24 * 60 * 60),
                        isComplete: true,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What scientific fields interest you most?",
                                answer: "Environmental science and marine conservation"
                            ),
                            SurveyResult.SurveyResponse(
                                questionID: "q2",
                                question: "How do you want to make a difference?",
                                answer: "By researching climate change solutions and protecting ocean ecosystems"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 3.9,
                    subjects: [
                        SubjectPerformance(name: "Biology", grade: "A", score: 0.96, interestAlignment: 0.98),
                        SubjectPerformance(name: "Chemistry", grade: "A-", score: 0.92, interestAlignment: 0.85),
                        SubjectPerformance(name: "Environmental Science", grade: "A", score: 0.98, interestAlignment: 0.99),
                        SubjectPerformance(name: "Mathematics", grade: "B+", score: 0.86, interestAlignment: 0.70)
                    ],
                    strengths: ["Scientific inquiry", "Environmental awareness", "Research skills"],
                    areasForImprovement: ["Mathematical modeling", "Public speaking"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-75 * 24 * 60 * 60), score: 0.88, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-35 * 24 * 60 * 60), score: 0.92, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-8 * 24 * 60 * 60), score: 0.94, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-25 * 24 * 60 * 60),
                        author: "Dr. Kim",
                        content: "Aisha's environmental science project on local water quality won the regional science fair. Excellent potential for advanced research.",
                        category: .academic
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-1 * 24 * 60 * 60)
            ),
            
            // MARK: - Introverted Student - Needs Confidence Building
            Student(
                name: "Sam Peterson",
                grade: "10",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -15, to: Date()) ?? Date(),
                studentID: "ST-006",
                interests: [
                    Interest(name: "Reading Fantasy Novels", category: [.literature]),
                    Interest(name: "Digital Art", category: [.arts, .technology]),
                    Interest(name: "Board Games", category: [.entertainment, .socialCauses]),
                    Interest(name: "Book Reading", category: [.literature]),
                    Interest(name: "Digital Drawing", category: [.arts, .technology]),
                    Interest(name: "Chess", category: [.gaming, .academics])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_sam_001",
                        surveyName: "Personality & Interest Survey",
                        date: Date().addingTimeInterval(-18 * 24 * 60 * 60),
                        isComplete: true,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What activities make you feel most comfortable?",
                                answer: "Reading alone, drawing, playing strategic games"
                            ),
                            SurveyResult.SurveyResponse(
                                questionID: "q2",
                                question: "What would help you participate more in class?",
                                answer: "Smaller groups and written responses instead of speaking out loud"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 3.5,
                    subjects: [
                        SubjectPerformance(name: "English", grade: "A-", score: 0.90, interestAlignment: 0.88),
                        SubjectPerformance(name: "Art", grade: "A", score: 0.94, interestAlignment: 0.95),
                        SubjectPerformance(name: "Mathematics", grade: "B", score: 0.82, interestAlignment: 0.60),
                        SubjectPerformance(name: "History", grade: "B+", score: 0.84, interestAlignment: 0.75)
                    ],
                    strengths: ["Written communication", "Attention to detail", "Independent work"],
                    areasForImprovement: ["Oral participation", "Group collaboration", "Self-advocacy"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-50 * 24 * 60 * 60), score: 0.55, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-25 * 24 * 60 * 60), score: 0.62, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-12 * 24 * 60 * 60), score: 0.68, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-16 * 24 * 60 * 60),
                        author: "Ms. Wilson",
                        content: "Sam has exceptional writing skills but rarely participates in class discussions. Recommend TMI 'From Meek to Promising Protector' model.",
                        category: .tmiPlan
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-6 * 24 * 60 * 60)
            ),
            
            // MARK: - Leadership-Focused Student
            Student(
                name: "Marcus Thompson",
                grade: "12",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -17, to: Date()) ?? Date(),
                studentID: "ST-007",
                interests: [
                    Interest(name: "Student Government", category: [.leadership, .socialCauses]),
                    Interest(name: "Community Service", category: [.socialCauses, .leadership]),
                    Interest(name: "Public Speaking", category: [.leadership]),
                    Interest(name: "Debate Club", category: [.academics, .leadership]),
                    Interest(name: "Volunteer Work", category: [.socialCauses]),
                    Interest(name: "Event Planning", category: [.social, .leadership])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_marcus_001",
                        surveyName: "Leadership Assessment",
                        date: Date().addingTimeInterval(-9 * 24 * 60 * 60),
                        isComplete: true,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What leadership roles have you taken?",
                                answer: "Student body president, volunteer coordinator at local shelter"
                            ),
                            SurveyResult.SurveyResponse(
                                questionID: "q2",
                                question: "What issues are you passionate about?",
                                answer: "Educational equity and youth empowerment"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 3.7,
                    subjects: [
                        SubjectPerformance(name: "Government", grade: "A", score: 0.95, interestAlignment: 0.98),
                        SubjectPerformance(name: "History", grade: "A-", score: 0.88, interestAlignment: 0.85),
                        SubjectPerformance(name: "English", grade: "B+", score: 0.84, interestAlignment: 0.80),
                        SubjectPerformance(name: "Economics", grade: "B", score: 0.82, interestAlignment: 0.75)
                    ],
                    strengths: ["Public speaking", "Organization", "Motivating others"],
                    areasForImprovement: ["Time management", "Delegation skills"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-80 * 24 * 60 * 60), score: 0.85, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-40 * 24 * 60 * 60), score: 0.90, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-10 * 24 * 60 * 60), score: 0.93, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-22 * 24 * 60 * 60),
                        author: "Principal Johnson",
                        content: "Marcus has been instrumental in organizing school-wide community service initiatives. Strong candidate for leadership development programs.",
                        category: .behavioral
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-1 * 24 * 60 * 60)
            ),
            
            // MARK: - At-Risk Student - Behavioral Challenges
            Student(
                name: "Devon Smith",
                grade: "11",
                school: "Sample High School",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date(),
                studentID: "ST-008",
                interests: [
                    Interest(name: "Automotive Repair", category: [.technology, .crafts]),
                    Interest(name: "Hip-Hop Music", category: [.music, .entertainment]),
                    Interest(name: "Martial Arts", category: [.sports, .wellness]),
                    Interest(name: "Car Restoration", category: [.technology, .crafts]),
                    Interest(name: "Rap Music Writing", category: [.music, .literature]),
                    Interest(name: "Boxing", category: [.sports, .wellness])
                ],
                surveyResults: [
                    SurveyResult(
                        id: "survey_devon_001",
                        surveyName: "Behavioral Assessment Survey",
                        date: Date().addingTimeInterval(-6 * 24 * 60 * 60),
                        isComplete: false,
                        responses: [
                            SurveyResult.SurveyResponse(
                                questionID: "q1",
                                question: "What makes you feel most successful?",
                                answer: "Working on cars and writing lyrics"
                            )
                        ]
                    )
                ],
                academicPerformance: AcademicPerformance(
                    gpa: 2.3,
                    subjects: [
                        SubjectPerformance(name: "Auto Shop", grade: "A-", score: 0.88, interestAlignment: 0.95),
                        SubjectPerformance(name: "Music", grade: "B", score: 0.80, interestAlignment: 0.85),
                        SubjectPerformance(name: "English", grade: "C-", score: 0.68, interestAlignment: 0.40),
                        SubjectPerformance(name: "Mathematics", grade: "D+", score: 0.62, interestAlignment: 0.30),
                        SubjectPerformance(name: "History", grade: "D", score: 0.58, interestAlignment: 0.25)
                    ],
                    strengths: ["Hands-on learning", "Mechanical aptitude", "Creative expression"],
                    areasForImprovement: ["Anger management", "Academic engagement", "Following directions"]
                ),
                engagementHistory: [
                    EngagementRecord(date: Date().addingTimeInterval(-70 * 24 * 60 * 60), score: 0.25, source: .teacherInput),
                    EngagementRecord(date: Date().addingTimeInterval(-35 * 24 * 60 * 60), score: 0.35, source: .survey),
                    EngagementRecord(date: Date().addingTimeInterval(-15 * 24 * 60 * 60), score: 0.42, source: .activityCompletion)
                ],
                notes: [
                    StudentNote(
                        date: Date().addingTimeInterval(-28 * 24 * 60 * 60),
                        author: "Mr. Rodriguez",
                        content: "Devon shows significant behavioral issues in traditional classroom settings but excels in auto shop. Multiple disciplinary referrals this semester.",
                        category: .behavioral
                    ),
                    StudentNote(
                        date: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                        author: "Ms. Foster",
                        content: "Recommend TMI 'Direct & Correct' intervention with focus on automotive interests. Family meeting scheduled.",
                        category: .tmiPlan
                    )
                ],
                lastInteractionDate: Date().addingTimeInterval(-2 * 24 * 60 * 60)
            )
        ]
    }
}

