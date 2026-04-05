//
//  EducationCareers.swift
//  TMI
//
//  Career data for Education category (25 careers)
//

import Foundation

enum EducationCareers {
    static let all: [CareerPath] = [

        // MARK: - Teaching (7)

        CareerPath(
            title: "Elementary Teacher",
            category: "education",
            subcategory: "Teaching",
            description: "Teach foundational subjects like reading, math, and science to students in grades K-5. Help young learners develop curiosity and a love of school.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 65000),
            educationLevel: .bachelors,
            icon: "book.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Middle School Teacher",
            category: "education",
            subcategory: "Teaching",
            description: "Guide students in grades 6-8 through important academic and social transitions. Specialize in a subject area while supporting the whole student.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 42000, max: 68000),
            educationLevel: .bachelors,
            icon: "book.pages.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "High School Teacher",
            category: "education",
            subcategory: "Teaching",
            description: "Teach specialized subjects to teenagers and help prepare them for college, careers, and adulthood. Build meaningful relationships with young adults.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 75000),
            educationLevel: .bachelors,
            icon: "graduationcap.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "College Professor",
            category: "education",
            subcategory: "Teaching",
            description: "Teach courses at the university level, conduct original research, and mentor students pursuing advanced degrees. Share deep expertise in a field.",
            pathway: nil,
            requiredInterests: ["education", "science_research"],
            estimatedSalary: SalaryRange(min: 55000, max: 140000),
            educationLevel: .doctorate,
            icon: "building.columns.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Preschool Teacher",
            category: "education",
            subcategory: "Teaching",
            description: "Support the development of children ages 3-5 through play-based learning, social skills, and early literacy. Create a nurturing classroom environment.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 28000, max: 50000),
            educationLevel: .someCollege,
            icon: "figure.and.child.holdinghands",
            color: "#E67E22"
        ),

        CareerPath(
            title: "ESL Teacher",
            category: "education",
            subcategory: "Teaching",
            description: "Help non-native speakers learn English as a second language in schools, community programs, or abroad. Bridge language and cultural barriers for students.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 38000, max: 65000),
            educationLevel: .bachelors,
            icon: "text.bubble.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Substitute Teacher",
            category: "education",
            subcategory: "Teaching",
            description: "Fill in for classroom teachers across grade levels and subjects. Maintain a positive learning environment and keep students on track with their lessons.",
            pathway: nil,
            requiredInterests: ["education"],
            estimatedSalary: SalaryRange(min: 25000, max: 45000),
            educationLevel: .someCollege,
            icon: "person.2.fill",
            color: "#E67E22"
        ),

        // MARK: - Administration (5)

        CareerPath(
            title: "Principal",
            category: "education",
            subcategory: "Administration",
            description: "Lead a school's staff, programs, and culture to ensure student success. Manage budgets, resolve conflicts, and build partnerships with families and the community.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 75000, max: 120000),
            educationLevel: .masters,
            icon: "building.2.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Superintendent",
            category: "education",
            subcategory: "Administration",
            description: "Oversee an entire school district's operations, strategy, and goals. Work with school boards, government agencies, and community leaders to improve education.",
            pathway: nil,
            requiredInterests: ["education", "law_government"],
            estimatedSalary: SalaryRange(min: 110000, max: 220000),
            educationLevel: .doctorate,
            icon: "person.badge.key.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Dean of Students",
            category: "education",
            subcategory: "Administration",
            description: "Manage student life, discipline, and support services at a school or university. Serve as an advocate for students and help resolve academic or behavioral concerns.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 55000, max: 95000),
            educationLevel: .masters,
            icon: "person.crop.circle.badge.checkmark",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Academic Advisor",
            category: "education",
            subcategory: "Administration",
            description: "Help students plan their course schedules, choose majors, and meet graduation requirements. Provide guidance to keep students on track for success.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 65000),
            educationLevel: .bachelors,
            icon: "list.clipboard.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Admissions Counselor",
            category: "education",
            subcategory: "Administration",
            description: "Guide prospective students through the college application and enrollment process. Review applications, host campus events, and help students find the right fit.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 38000, max: 62000),
            educationLevel: .bachelors,
            icon: "envelope.open.fill",
            color: "#E67E22"
        ),

        // MARK: - Special Education (4)

        CareerPath(
            title: "Special Education Teacher",
            category: "education",
            subcategory: "Special Education",
            description: "Develop and implement individualized education plans for students with disabilities. Adapt lessons and environments to help every student reach their potential.",
            pathway: nil,
            requiredInterests: ["education", "health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 75000),
            educationLevel: .bachelors,
            icon: "heart.text.square.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Speech-Language Pathologist",
            category: "education",
            subcategory: "Special Education",
            description: "Diagnose and treat communication disorders including speech, language, and swallowing difficulties. Work with students of all ages in schools and clinical settings.",
            pathway: nil,
            requiredInterests: ["education", "health_wellness"],
            estimatedSalary: SalaryRange(min: 60000, max: 100000),
            educationLevel: .masters,
            icon: "waveform.path.ecg",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Behavioral Therapist",
            category: "education",
            subcategory: "Special Education",
            description: "Use evidence-based techniques to improve social, communication, and learning behaviors in students. Support children with autism, ADHD, and related developmental needs.",
            pathway: nil,
            requiredInterests: ["education", "health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 80000),
            educationLevel: .bachelors,
            icon: "brain.head.profile",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Learning Disability Specialist",
            category: "education",
            subcategory: "Special Education",
            description: "Evaluate and support students with dyslexia, dyscalculia, and other learning differences. Design targeted strategies that help students overcome academic challenges.",
            pathway: nil,
            requiredInterests: ["education", "health_wellness"],
            estimatedSalary: SalaryRange(min: 48000, max: 80000),
            educationLevel: .masters,
            icon: "magnifyingglass.circle.fill",
            color: "#E67E22"
        ),

        // MARK: - Training & Development (4)

        CareerPath(
            title: "Corporate Trainer",
            category: "education",
            subcategory: "Training & Development",
            description: "Design and deliver training programs for employees at businesses and organizations. Help teams build new skills and improve job performance.",
            pathway: nil,
            requiredInterests: ["education", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50000, max: 90000),
            educationLevel: .bachelors,
            icon: "person.3.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Instructional Designer",
            category: "education",
            subcategory: "Training & Development",
            description: "Create effective learning experiences by designing courses, curriculum, and educational materials. Combine knowledge of learning science with visual design and technology.",
            pathway: nil,
            requiredInterests: ["education", "technology"],
            estimatedSalary: SalaryRange(min: 55000, max: 95000),
            educationLevel: .bachelors,
            icon: "pencil.and.ruler.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "E-Learning Developer",
            category: "education",
            subcategory: "Training & Development",
            description: "Build interactive online courses and digital training modules using multimedia tools and learning management systems. Make education accessible through technology.",
            pathway: nil,
            requiredInterests: ["education", "technology"],
            estimatedSalary: SalaryRange(min: 55000, max: 100000),
            educationLevel: .bachelors,
            icon: "desktopcomputer",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Curriculum Developer",
            category: "education",
            subcategory: "Training & Development",
            description: "Research, design, and evaluate educational materials and lesson plans for schools or training programs. Align content with learning standards and student needs.",
            pathway: nil,
            requiredInterests: ["education", "science_research"],
            estimatedSalary: SalaryRange(min: 50000, max: 85000),
            educationLevel: .masters,
            icon: "doc.text.fill",
            color: "#E67E22"
        ),

        // MARK: - Library Science (5)

        CareerPath(
            title: "Librarian",
            category: "education",
            subcategory: "Library Science",
            description: "Manage library collections, help patrons find information, and promote a love of reading and learning in communities and schools.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 75000),
            educationLevel: .masters,
            icon: "books.vertical.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Children's Librarian",
            category: "education",
            subcategory: "Library Science",
            description: "Create programs and reading experiences that inspire young readers. Work with children and families to build early literacy skills and a lifelong love of books.",
            pathway: nil,
            requiredInterests: ["education", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 68000),
            educationLevel: .masters,
            icon: "book.closed.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Archivist",
            category: "education",
            subcategory: "Library Science",
            description: "Preserve and organize historical documents, records, and artifacts for museums, universities, and government agencies. Protect important cultural heritage for future generations.",
            pathway: nil,
            requiredInterests: ["education", "science_research"],
            estimatedSalary: SalaryRange(min: 42000, max: 72000),
            educationLevel: .masters,
            icon: "archivebox.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Museum Educator",
            category: "education",
            subcategory: "Library Science",
            description: "Design and lead educational programs at museums, science centers, and cultural institutions. Connect visitors of all ages with history, art, and science.",
            pathway: nil,
            requiredInterests: ["education", "creative_arts"],
            estimatedSalary: SalaryRange(min: 38000, max: 62000),
            educationLevel: .bachelors,
            icon: "paintpalette.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Research Librarian",
            category: "education",
            subcategory: "Library Science",
            description: "Assist researchers, students, and faculty in locating and evaluating information sources. Specialize in database management and academic knowledge discovery.",
            pathway: nil,
            requiredInterests: ["education", "science_research"],
            estimatedSalary: SalaryRange(min: 48000, max: 80000),
            educationLevel: .masters,
            icon: "magnifyingglass",
            color: "#E67E22"
        ),
    ]
}
