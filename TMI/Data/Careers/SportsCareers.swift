//
//  SportsCareers.swift
//  TMI
//
//  Career data for the Sports category (25 careers)
//

import Foundation

enum SportsCareers {
    static let all: [CareerPath] = [

        // MARK: - Coaching & Training

        CareerPath(
            title: "Head Coach",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Head coaches lead athletic teams by developing game strategies, running practices, and guiding athletes to perform at their best while fostering teamwork and sportsmanship. They are responsible for the overall direction and culture of their program at the high school, college, or professional level.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "education"],
            estimatedSalary: SalaryRange(min: 45_000, max: 500_000),
            educationLevel: .bachelors,
            icon: "trophy.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Assistant Coach",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Assistant coaches support head coaches by running position-specific drills, providing individualized player feedback, and helping scout opponents to prepare game plans. They play a crucial mentoring role in an athlete's development and often specialize in one aspect of the sport.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "education"],
            estimatedSalary: SalaryRange(min: 35_000, max: 200_000),
            educationLevel: .bachelors,
            icon: "sportscourt.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Strength and Conditioning Coach",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Strength and conditioning coaches design and supervise exercise programs that improve athletes' power, speed, endurance, and injury resistance. They use sports science principles to prepare athletes physically for the demands of their sport throughout the season.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 48_000, max: 120_000),
            educationLevel: .bachelors,
            icon: "dumbbell.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Sports Psychologist",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Sports psychologists help athletes build mental toughness, manage performance anxiety, and develop the focus and confidence needed to compete at their best. They work with individuals or teams using techniques like visualization, goal-setting, and mindfulness.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 65_000, max: 130_000),
            educationLevel: .doctorate,
            icon: "brain.head.profile.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Swim Coach",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Swim coaches train competitive swimmers to improve their technique, speed, and endurance through structured workouts and technical instruction. They develop seasonal training plans and help athletes peak at the right time for competitions.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "education"],
            estimatedSalary: SalaryRange(min: 32_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "figure.pool.swim",
            color: "#F39C12"
        ),

        // MARK: - Sports Management

        CareerPath(
            title: "Sports Agent",
            category: "sports",
            subcategory: "Sports Management",
            description: "Sports agents negotiate contracts, endorsement deals, and other business opportunities on behalf of professional athletes to maximize their earning potential and career opportunities. They serve as trusted advisors and advocates for their clients both on and off the field.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55_000, max: 250_000),
            educationLevel: .bachelors,
            icon: "briefcase.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Sports Marketing Manager",
            category: "sports",
            subcategory: "Sports Management",
            description: "Sports marketing managers promote teams, athletes, events, and sports brands through campaigns, sponsorships, digital media, and fan engagement strategies. They work to grow audiences, sell tickets, and build the commercial value of sports properties.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "megaphone.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Team General Manager",
            category: "sports",
            subcategory: "Sports Management",
            description: "Team general managers oversee all aspects of a professional sports franchise, including player personnel decisions, contract negotiations, and building a competitive roster. They collaborate with coaches and ownership to develop a long-term vision for the organization.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 80_000, max: 500_000),
            educationLevel: .masters,
            icon: "building.2.crop.circle.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Stadium Operations Manager",
            category: "sports",
            subcategory: "Sports Management",
            description: "Stadium operations managers oversee the day-to-day functioning of sports venues, ensuring facilities are safe, clean, and ready for events including games, concerts, and community functions. They manage maintenance crews, coordinate vendors, and handle logistics for thousands of fans.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55_000, max: 105_000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Sports Broadcaster",
            category: "sports",
            subcategory: "Sports Management",
            description: "Sports broadcasters provide play-by-play commentary, analysis, and storytelling for live and recorded sports events on television, radio, or digital platforms. They combine deep knowledge of sports with strong communication skills to bring games to life for audiences at home.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "audio_media"],
            estimatedSalary: SalaryRange(min: 40_000, max: 200_000),
            educationLevel: .bachelors,
            icon: "mic.fill",
            color: "#F39C12"
        ),

        // MARK: - Fitness & Wellness

        CareerPath(
            title: "Personal Trainer",
            category: "sports",
            subcategory: "Fitness & Wellness",
            description: "Personal trainers design customized workout programs and provide one-on-one coaching to help clients reach fitness goals like losing weight, building strength, or recovering from injury. They track progress, adjust plans, and motivate clients to stay consistent.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 35_000, max: 85_000),
            educationLevel: .certification,
            icon: "figure.strengthtraining.traditional",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Group Fitness Instructor",
            category: "sports",
            subcategory: "Fitness & Wellness",
            description: "Group fitness instructors lead energetic exercise classes like spin, HIIT, Zumba, or boot camp for groups of participants in gyms, studios, or community centers. They create fun, safe, and effective workout experiences while motivating participants of all fitness levels.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 28_000, max: 65_000),
            educationLevel: .certification,
            icon: "figure.run",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Yoga Instructor",
            category: "sports",
            subcategory: "Fitness & Wellness",
            description: "Yoga instructors guide students through postures, breathing exercises, and mindfulness practices that improve flexibility, reduce stress, and promote overall well-being. They teach in studios, gyms, schools, or online and adapt their instruction to students of all ages and abilities.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 30_000, max: 72_000),
            educationLevel: .certification,
            icon: "figure.yoga",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Pilates Instructor",
            category: "sports",
            subcategory: "Fitness & Wellness",
            description: "Pilates instructors teach a system of controlled movements designed to strengthen the core, improve posture, and increase body awareness using mats, reformers, and specialized equipment. They work in studios, physical therapy clinics, and gyms with clients ranging from athletes to seniors.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 35_000, max: 78_000),
            educationLevel: .certification,
            icon: "figure.mind.and.body",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Dance Instructor",
            category: "sports",
            subcategory: "Fitness & Wellness",
            description: "Dance instructors teach a wide range of dance styles—from ballet and hip-hop to ballroom and contemporary—to students of all ages in dance studios, schools, or community programs. They combine technical instruction with artistry to help students develop physical coordination, confidence, and creative expression.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "creative_arts"],
            estimatedSalary: SalaryRange(min: 28_000, max: 68_000),
            educationLevel: .certification,
            icon: "figure.dance",
            color: "#F39C12"
        ),

        // MARK: - Recreation

        CareerPath(
            title: "Recreation Coordinator",
            category: "sports",
            subcategory: "Recreation",
            description: "Recreation coordinators plan, organize, and manage sports leagues, fitness classes, and community events for parks and recreation departments, schools, or community centers. They create programming that brings people together and promotes active, healthy lifestyles.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "education"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "calendar.badge.plus",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Lifeguard",
            category: "sports",
            subcategory: "Recreation",
            description: "Lifeguards monitor swimming areas at pools, beaches, and water parks to prevent drowning and respond quickly to emergencies with rescue and first aid skills. They enforce safety rules, educate the public, and are often a first line of response in aquatic emergencies.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 24_000, max: 45_000),
            educationLevel: .certification,
            icon: "figure.open.water.swim",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Outdoor Adventure Guide",
            category: "sports",
            subcategory: "Recreation",
            description: "Outdoor adventure guides lead groups on activities like hiking, kayaking, rock climbing, and white-water rafting while ensuring participant safety and creating memorable experiences in nature. They combine technical expertise with leadership and communication skills to inspire a love of the outdoors.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 30_000, max: 65_000),
            educationLevel: .certification,
            icon: "mountain.2.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Camp Director",
            category: "sports",
            subcategory: "Recreation",
            description: "Camp directors manage the overall operations of summer camps or year-round youth programs, overseeing staff, budgets, and activities that provide safe and enriching experiences for young participants. They are responsible for creating a positive camp culture and ensuring every camper feels welcome and engaged.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "education"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .bachelors,
            icon: "tent.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Park Recreation Specialist",
            category: "sports",
            subcategory: "Recreation",
            description: "Park recreation specialists develop and run programs at parks—from sports leagues and fitness classes to nature education and cultural events—to serve diverse community members of all ages. They work to make public parks vibrant hubs for health, play, and community connection.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .bachelors,
            icon: "tree.circle.fill",
            color: "#F39C12"
        ),

        // MARK: - Esports

        CareerPath(
            title: "Esports Coach",
            category: "sports",
            subcategory: "Esports",
            description: "Esports coaches analyze gameplay footage, develop strategies, and train competitive gaming teams to improve coordination, decision-making, and mechanical skill. They work with high school, college, and professional teams in games like League of Legends, Valorant, and Rocket League.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "technology"],
            estimatedSalary: SalaryRange(min: 35_000, max: 90_000),
            educationLevel: .someCollege,
            icon: "gamecontroller.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Esports Team Manager",
            category: "sports",
            subcategory: "Esports",
            description: "Esports team managers handle the business and logistics side of competitive gaming organizations, including scheduling, travel, contracts, and player relations. They bridge the gap between the coaching staff, players, and the organization's front office.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "person.3.sequence.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Professional Gamer",
            category: "sports",
            subcategory: "Esports",
            description: "Professional gamers compete in organized esports tournaments and leagues, earning prize money and salaries by mastering competitive video games at the highest level. They train for many hours each day to refine their skills and work as part of a team to develop winning strategies.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "technology"],
            estimatedSalary: SalaryRange(min: 25_000, max: 500_000),
            educationLevel: .highSchool,
            icon: "gamecontroller.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Game Commentator",
            category: "sports",
            subcategory: "Esports",
            description: "Game commentators—also called casters—provide live play-by-play and color commentary for esports events, helping audiences understand the action and adding excitement to competitions streamed online and in arenas. They combine expert game knowledge with broadcasting skills to entertain global audiences.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "audio_media"],
            estimatedSalary: SalaryRange(min: 35_000, max: 120_000),
            educationLevel: .someCollege,
            icon: "mic.badge.plus",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Esports Event Organizer",
            category: "sports",
            subcategory: "Esports",
            description: "Esports event organizers plan and execute gaming tournaments and competitions—from local LAN events to massive stadium productions—managing logistics, production crews, sponsors, and participant experiences. They ensure everything runs smoothly so players can compete and fans can enjoy the show.",
            pathway: nil,
            requiredInterests: ["sports_athletics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 42_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "trophy.circle.fill",
            color: "#F39C12"
        ),

        // MARK: - Legacy Migrated

        CareerPath(
            title: "Coach",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Train athletes and teams to reach their full potential.",
            pathway: CareerPathways.coachPathway,
            requiredInterests: ["sports_athletics"],
            estimatedSalary: SalaryRange(min: 35000, max: 90000),
            educationLevel: .bachelors,
            icon: "sportscourt.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Athletic Trainer",
            category: "sports",
            subcategory: "Coaching & Training",
            description: "Prevent and treat sports injuries for athletes.",
            pathway: CareerPathways.athleticTrainerPathway,
            requiredInterests: ["sports_athletics", "health_wellness"],
            estimatedSalary: SalaryRange(min: 45000, max: 75000),
            educationLevel: .masters,
            icon: "bandage.fill",
            color: "#F39C12"
        ),

        CareerPath(
            title: "Sports Analyst",
            category: "sports",
            subcategory: "Sports Analytics & Media",
            description: "Analyze sports data and provide insights for teams and media.",
            pathway: CareerPathways.sportsAnalystPathway,
            requiredInterests: ["sports_athletics", "technology"],
            estimatedSalary: SalaryRange(min: 40000, max: 95000),
            educationLevel: .bachelors,
            icon: "chart.xyaxis.line",
            color: "#F39C12"
        ),

        CareerPath(
            title: "PE Teacher",
            category: "sports",
            subcategory: "Sports Education",
            description: "Teach physical education and promote healthy lifestyles in schools.",
            pathway: CareerPathways.peTeacherPathway,
            requiredInterests: ["sports_athletics", "education"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .bachelors,
            icon: "figure.run",
            color: "#F39C12"
        )
    ]
}
