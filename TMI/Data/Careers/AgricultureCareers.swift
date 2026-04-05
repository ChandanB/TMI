//
//  AgricultureCareers.swift
//  TMI
//
//  Career data for the Agriculture category (25 careers)
//

import Foundation

enum AgricultureCareers {
    static let all: [CareerPath] = [

        // MARK: - Farming & Ranching

        CareerPath(
            title: "Farm Manager",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Farm managers oversee the day-to-day operations of a farm, including planting schedules, equipment maintenance, and hiring workers. They make decisions about crops, budgets, and sustainability practices to keep the farm productive and profitable.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 48_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "tractor.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Rancher",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Ranchers raise livestock such as cattle, sheep, or pigs for meat, dairy, or fiber products. They manage pastures, animal health, feeding programs, and the business side of running a working ranch.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40_000, max: 85_000),
            educationLevel: .someCollege,
            icon: "hare.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Agricultural Engineer",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Agricultural engineers design machinery, equipment, and systems that help farms run more efficiently and sustainably. They solve problems related to water use, soil conservation, and food processing using engineering principles.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 62_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "wrench.and.screwdriver.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Crop Scientist",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Crop scientists study plants and develop ways to improve their growth, yield, and resistance to disease or harsh weather. Their research helps farmers produce more food while using fewer resources.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 58_000, max: 105_000),
            educationLevel: .masters,
            icon: "leaf.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Irrigation Specialist",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Irrigation specialists design and maintain water delivery systems that keep crops healthy while conserving water. They use technology and soil science to make sure fields get exactly the right amount of water at the right time.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "engineering_building"],
            estimatedSalary: SalaryRange(min: 45_000, max: 80_000),
            educationLevel: .bachelors,
            icon: "drop.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Organic Farmer",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Organic farmers grow crops and raise animals without using synthetic pesticides or fertilizers, focusing on natural methods that protect the environment. They manage soil health, natural pest control, and often sell directly to local markets or consumers.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 35_000, max: 75_000),
            educationLevel: .someCollege,
            icon: "leaf.circle.fill",
            color: "#27AE60"
        ),

        // MARK: - Animal Care

        CareerPath(
            title: "Veterinarian",
            category: "agriculture",
            subcategory: "Animal Care",
            description: "Veterinarians are doctors for animals who diagnose and treat illnesses, perform surgeries, and help prevent the spread of disease. They may work with household pets, farm animals, wildlife, or in research settings.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 80_000, max: 160_000),
            educationLevel: .doctorate,
            icon: "pawprint.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Veterinary Technician",
            category: "agriculture",
            subcategory: "Animal Care",
            description: "Veterinary technicians assist veterinarians by performing lab tests, taking X-rays, administering medications, and caring for animals during recovery. They are a key part of the animal healthcare team.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "health_wellness"],
            estimatedSalary: SalaryRange(min: 35_000, max: 60_000),
            educationLevel: .someCollege,
            icon: "cross.case.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Animal Trainer",
            category: "agriculture",
            subcategory: "Animal Care",
            description: "Animal trainers work with animals to teach them specific behaviors using positive reinforcement techniques. They train pets, service animals, horses, marine mammals, and animals used in film or entertainment.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 30_000, max: 65_000),
            educationLevel: .certification,
            icon: "pawprint.circle.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Zoologist",
            category: "agriculture",
            subcategory: "Animal Care",
            description: "Zoologists study animals and their behavior, physiology, and how they interact with their environment. They conduct field research, analyze data, and often work to protect endangered species.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .masters,
            icon: "bird.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Marine Biologist",
            category: "agriculture",
            subcategory: "Animal Care",
            description: "Marine biologists study ocean life, from tiny plankton to massive whales, to understand how sea ecosystems work. They conduct underwater research, collect samples, and work to protect marine environments.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 50_000, max: 100_000),
            educationLevel: .masters,
            icon: "fish.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Wildlife Rehabilitator",
            category: "agriculture",
            subcategory: "Animal Care",
            description: "Wildlife rehabilitators care for injured or orphaned wild animals with the goal of releasing them back into their natural habitat. They work with veterinarians and volunteers to provide medical care and prepare animals for life in the wild.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "health_wellness"],
            estimatedSalary: SalaryRange(min: 28_000, max: 55_000),
            educationLevel: .certification,
            icon: "bird.circle.fill",
            color: "#27AE60"
        ),

        // MARK: - Forestry & Conservation

        CareerPath(
            title: "Forester",
            category: "agriculture",
            subcategory: "Forestry & Conservation",
            description: "Foresters manage and protect forest lands, balancing the needs of wildlife, the environment, and human activities like logging or recreation. They assess forest health, develop management plans, and respond to threats like wildfires or disease.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 52_000, max: 90_000),
            educationLevel: .bachelors,
            icon: "tree.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Park Ranger",
            category: "agriculture",
            subcategory: "Forestry & Conservation",
            description: "Park rangers protect national and state parks by enforcing regulations, educating visitors, conducting search and rescue operations, and managing wildlife and natural resources. They often serve as the public face of conservation efforts.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "law_government"],
            estimatedSalary: SalaryRange(min: 40_000, max: 75_000),
            educationLevel: .bachelors,
            icon: "shield.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Conservation Scientist",
            category: "agriculture",
            subcategory: "Forestry & Conservation",
            description: "Conservation scientists work with landowners, governments, and nonprofits to manage and improve natural resources like soil, water, and forests. They develop strategies to protect ecosystems while still allowing land to be used productively.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research", "law_government"],
            estimatedSalary: SalaryRange(min: 55_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "globe.americas.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Arborist",
            category: "agriculture",
            subcategory: "Forestry & Conservation",
            description: "Arborists are tree care professionals who diagnose diseases, prune branches, remove hazardous trees, and plant new trees in urban and rural settings. They combine knowledge of biology with physical skills to keep trees healthy and communities safe.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "engineering_building"],
            estimatedSalary: SalaryRange(min: 38_000, max: 70_000),
            educationLevel: .certification,
            icon: "tree.circle.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Fish and Game Warden",
            category: "agriculture",
            subcategory: "Forestry & Conservation",
            description: "Fish and game wardens enforce wildlife laws and regulations to protect natural resources and ensure fair and safe hunting and fishing. They patrol outdoor areas, investigate violations, and educate the public about conservation.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "law_government"],
            estimatedSalary: SalaryRange(min: 45_000, max: 80_000),
            educationLevel: .bachelors,
            icon: "fish.circle.fill",
            color: "#27AE60"
        ),

        // MARK: - Horticulture

        CareerPath(
            title: "Landscape Designer",
            category: "agriculture",
            subcategory: "Horticulture",
            description: "Landscape designers create outdoor spaces—from gardens to parks to corporate campuses—that are both beautiful and functional. They select plants, design layouts, and consider elements like drainage and environmental impact.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "creative_arts"],
            estimatedSalary: SalaryRange(min: 48_000, max: 90_000),
            educationLevel: .bachelors,
            icon: "paintbrush.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Horticulturist",
            category: "agriculture",
            subcategory: "Horticulture",
            description: "Horticulturists are plant scientists who study how to grow fruits, vegetables, flowers, and ornamental plants more effectively. They work in research, consulting, or hands-on production to improve plant quality and yields.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 45_000, max: 80_000),
            educationLevel: .bachelors,
            icon: "leaf.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Greenhouse Manager",
            category: "agriculture",
            subcategory: "Horticulture",
            description: "Greenhouse managers oversee the growing of plants indoors in controlled environments, managing temperature, lighting, watering, and pest control. They combine plant knowledge with business skills to run efficient growing operations.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 42_000, max: 75_000),
            educationLevel: .bachelors,
            icon: "sun.max.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Florist",
            category: "agriculture",
            subcategory: "Horticulture",
            description: "Florists design and arrange flowers and plants for weddings, events, funerals, and everyday purchases. They combine artistic creativity with knowledge of plant care to create beautiful and lasting floral arrangements.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "creative_arts"],
            estimatedSalary: SalaryRange(min: 28_000, max: 55_000),
            educationLevel: .vocational,
            icon: "camera.macro",
            color: "#27AE60"
        ),

        // MARK: - Food Science

        CareerPath(
            title: "Food Scientist",
            category: "agriculture",
            subcategory: "Food Science",
            description: "Food scientists research and develop new food products, improve existing ones, and ensure that food is safe for people to eat. They study the chemistry, biology, and engineering of food to create healthier and better-tasting options.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 58_000, max: 105_000),
            educationLevel: .bachelors,
            icon: "flask.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Agricultural Inspector",
            category: "agriculture",
            subcategory: "Food Science",
            description: "Agricultural inspectors examine farms, food processing facilities, and agricultural products to make sure they meet safety and quality standards. They protect public health by enforcing regulations on everything from pesticide use to food labeling.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "law_government"],
            estimatedSalary: SalaryRange(min: 40_000, max: 72_000),
            educationLevel: .bachelors,
            icon: "checkmark.seal.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Soil Scientist",
            category: "agriculture",
            subcategory: "Food Science",
            description: "Soil scientists study the composition, structure, and health of soil to help farmers grow better crops and protect the environment. Their work supports agriculture, construction, and environmental conservation by understanding what lies beneath our feet.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 55_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "mountain.2.fill",
            color: "#27AE60"
        ),

        CareerPath(
            title: "Aquaculture Farmer",
            category: "agriculture",
            subcategory: "Food Science",
            description: "Aquaculture farmers raise fish, shellfish, and aquatic plants in controlled water environments as a sustainable source of food. They manage water quality, feeding, and breeding to produce healthy seafood for consumers.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 38_000, max: 75_000),
            educationLevel: .bachelors,
            icon: "fish.fill",
            color: "#27AE60"
        )
    ]
}
