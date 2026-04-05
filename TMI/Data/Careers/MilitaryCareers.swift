//
//  MilitaryCareers.swift
//  TMI
//
//  Career data for the Military category (15 careers)
//

import Foundation

enum MilitaryCareers {
    static let all: [CareerPath] = [

        // MARK: - Service Branches

        CareerPath(
            title: "Army Officer",
            category: "military",
            subcategory: "Service Branches",
            description: "Army officers lead soldiers in a wide range of missions, from combat operations to humanitarian aid, and are responsible for the welfare, training, and performance of their unit. They develop leadership and management skills that transfer to many careers after service.",
            pathway: nil,
            requiredInterests: ["law_government", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 42_000, max: 120_000),
            educationLevel: .bachelors,
            icon: "flag.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Navy Officer",
            category: "military",
            subcategory: "Service Branches",
            description: "Navy officers command ships, submarines, and aircraft squadrons while managing crews that operate complex weapons and navigation systems across the world's oceans. They receive training in leadership, engineering, and strategy.",
            pathway: nil,
            requiredInterests: ["law_government", "engineering_building"],
            estimatedSalary: SalaryRange(min: 42_000, max: 125_000),
            educationLevel: .bachelors,
            icon: "water.waves",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Air Force Pilot",
            category: "military",
            subcategory: "Service Branches",
            description: "Air Force pilots fly high-performance jet aircraft on missions ranging from air combat and reconnaissance to cargo transport and search-and-rescue. They undergo years of rigorous training and must maintain peak physical and mental performance.",
            pathway: nil,
            requiredInterests: ["law_government", "technology", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 48_000, max: 140_000),
            educationLevel: .bachelors,
            icon: "airplane",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Marine Corps Officer",
            category: "military",
            subcategory: "Service Branches",
            description: "Marine Corps officers lead highly trained infantry and specialized units in some of the most demanding combat and crisis-response missions in the military. The Marine Corps is known for its intense physical standards and warrior ethos.",
            pathway: nil,
            requiredInterests: ["law_government", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 42_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "shield.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Coast Guard Officer",
            category: "military",
            subcategory: "Service Branches",
            description: "Coast Guard officers protect the nation's waterways by conducting search and rescue operations, enforcing maritime law, and preventing drug smuggling and illegal immigration at sea. They combine law enforcement with humanitarian service.",
            pathway: nil,
            requiredInterests: ["law_government", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 42_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "lifepreserver.fill",
            color: "#2C3E50"
        ),

        // MARK: - Defense Civilian

        CareerPath(
            title: "Military Medic",
            category: "military",
            subcategory: "Defense Civilian",
            description: "Military medics provide emergency medical care to soldiers on the battlefield and in garrison, treating injuries under conditions that civilian paramedics rarely face. Many go on to careers as nurses, physician assistants, or paramedics after service.",
            pathway: nil,
            requiredInterests: ["law_government", "health_wellness"],
            estimatedSalary: SalaryRange(min: 35_000, max: 75_000),
            educationLevel: .someCollege,
            icon: "cross.case.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Military Engineer",
            category: "military",
            subcategory: "Defense Civilian",
            description: "Military engineers design and build bridges, roads, and fortifications in combat zones, and also clear obstacles and explosive hazards to support troop movements. Their skills in civil and combat engineering are critical to military operations.",
            pathway: nil,
            requiredInterests: ["law_government", "engineering_building"],
            estimatedSalary: SalaryRange(min: 50_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "hammer.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Cyber Operations Specialist",
            category: "military",
            subcategory: "Defense Civilian",
            description: "Cyber operations specialists in the military defend military networks from enemy hackers and conduct offensive cyber operations against adversaries in the digital domain. They are among the most technically skilled members of the armed forces.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 55_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "bolt.shield.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Defense Contractor",
            category: "military",
            subcategory: "Defense Civilian",
            description: "Defense contractors are civilians who work for private companies that build weapons systems, vehicles, aircraft, and technology used by the military. They apply engineering, manufacturing, and business expertise to national defense projects.",
            pathway: nil,
            requiredInterests: ["law_government", "engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 65_000, max: 160_000),
            educationLevel: .bachelors,
            icon: "wrench.and.screwdriver.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Weapons Systems Analyst",
            category: "military",
            subcategory: "Defense Civilian",
            description: "Weapons systems analysts evaluate the design, performance, and effectiveness of military weapons and equipment to help the government make decisions about what to develop and purchase. They combine technical knowledge with strategic analysis.",
            pathway: nil,
            requiredInterests: ["law_government", "engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 70_000, max: 145_000),
            educationLevel: .bachelors,
            icon: "scope",
            color: "#2C3E50"
        ),

        // MARK: - Intelligence

        CareerPath(
            title: "Intelligence Officer",
            category: "military",
            subcategory: "Intelligence",
            description: "Intelligence officers collect, analyze, and interpret information about potential threats and adversaries to help military commanders and policymakers make informed decisions. They are skilled in research, foreign languages, and strategic analysis.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 55_000, max: 125_000),
            educationLevel: .bachelors,
            icon: "magnifyingglass.circle.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Cryptanalyst",
            category: "military",
            subcategory: "Intelligence",
            description: "Cryptanalysts work to decode encrypted messages and communications from adversaries, using advanced mathematics and computer science to break codes and protect secure information. Their work is essential to signals intelligence and cybersecurity.",
            pathway: nil,
            requiredInterests: ["law_government", "technology", "science_research"],
            estimatedSalary: SalaryRange(min: 70_000, max: 145_000),
            educationLevel: .bachelors,
            icon: "lock.open.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Drone Operator",
            category: "military",
            subcategory: "Intelligence",
            description: "Drone operators, also called unmanned aerial vehicle (UAV) pilots, fly remotely piloted aircraft used for surveillance, reconnaissance, and combat missions. They monitor live video feeds, coordinate with ground forces, and make real-time decisions.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 40_000, max: 95_000),
            educationLevel: .someCollege,
            icon: "airplane.circle.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Military Police",
            category: "military",
            subcategory: "Intelligence",
            description: "Military police officers enforce laws and regulations on military installations, manage prisoners of war, and support combat operations by providing security and area control. They receive training similar to civilian law enforcement with an added military dimension.",
            pathway: nil,
            requiredInterests: ["law_government", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 35_000, max: 75_000),
            educationLevel: .someCollege,
            icon: "shield.lefthalf.filled",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Military Chaplain",
            category: "military",
            subcategory: "Intelligence",
            description: "Military chaplains provide spiritual care, counseling, and religious services to service members and their families, offering support during deployment, combat, and personal crises. They serve all faiths and are non-combatants committed to the well-being of troops.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 42_000, max: 100_000),
            educationLevel: .masters,
            icon: "person.fill.checkmark",
            color: "#2C3E50"
        )
    ]
}
