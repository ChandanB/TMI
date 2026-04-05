//
//  EnvironmentCareers.swift
//  TMI
//
//  Career data for Environment category (20 careers)
//

import Foundation

enum EnvironmentCareers {
    static let all: [CareerPath] = [

        // MARK: - Conservation (5)

        CareerPath(
            title: "Environmental Scientist",
            category: "environment",
            subcategory: "Conservation",
            description: "Study how human activity and natural processes affect the environment. Collect field samples, analyze data, and recommend solutions to protect ecosystems.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 50000, max: 90000),
            educationLevel: .bachelors,
            icon: "globe.americas.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Ecologist",
            category: "environment",
            subcategory: "Conservation",
            description: "Research how plants, animals, and organisms interact with each other and their environments. Help identify threats to biodiversity and design strategies to restore natural balance.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 48000, max: 88000),
            educationLevel: .masters,
            icon: "leaf.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Wildlife Biologist",
            category: "environment",
            subcategory: "Conservation",
            description: "Study wild animals and their habitats to support conservation efforts and manage wildlife populations. Work in the field monitoring species and protecting natural areas.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 45000, max: 85000),
            educationLevel: .bachelors,
            icon: "pawprint.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Conservation Officer",
            category: "environment",
            subcategory: "Conservation",
            description: "Enforce environmental laws, protect natural resources, and educate the public about conservation. Patrol forests, wetlands, and coastlines to preserve wildlife and habitats.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "law_government"],
            estimatedSalary: SalaryRange(min: 45000, max: 80000),
            educationLevel: .bachelors,
            icon: "shield.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Habitat Restoration Specialist",
            category: "environment",
            subcategory: "Conservation",
            description: "Plan and carry out projects that restore damaged ecosystems, such as replanting native vegetation and removing invasive species. Help ecosystems recover and thrive.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 45000, max: 80000),
            educationLevel: .bachelors,
            icon: "tree.fill",
            color: "#1ABC9C"
        ),

        // MARK: - Sustainability (5)

        CareerPath(
            title: "Sustainability Consultant",
            category: "environment",
            subcategory: "Sustainability",
            description: "Advise companies and governments on reducing their environmental impact and operating more sustainably. Develop strategies covering energy, waste, water, and supply chains.",
            pathway: nil,
            requiredInterests: ["science_research", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 110000),
            educationLevel: .bachelors,
            icon: "arrow.3.trianglepath",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Carbon Analyst",
            category: "environment",
            subcategory: "Sustainability",
            description: "Measure and track greenhouse gas emissions for organizations to help them meet carbon reduction goals. Analyze data and produce reports that guide climate strategy.",
            pathway: nil,
            requiredInterests: ["science_research", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 58000, max: 100000),
            educationLevel: .bachelors,
            icon: "chart.bar.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "ESG Analyst",
            category: "environment",
            subcategory: "Sustainability",
            description: "Evaluate companies on their environmental, social, and governance practices for investors and stakeholders. Help drive responsible business practices through research and reporting.",
            pathway: nil,
            requiredInterests: ["science_research", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 62000, max: 110000),
            educationLevel: .bachelors,
            icon: "chart.line.uptrend.xyaxis",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Green Building Consultant",
            category: "environment",
            subcategory: "Sustainability",
            description: "Guide architects, developers, and builders in creating energy-efficient, environmentally friendly structures. Work toward certifications like LEED and net-zero buildings.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 60000, max: 105000),
            educationLevel: .bachelors,
            icon: "building.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Waste Management Specialist",
            category: "environment",
            subcategory: "Sustainability",
            description: "Design and manage systems for collecting, recycling, and safely disposing of waste. Help communities reduce landfill use and recover valuable materials from discarded items.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 48000, max: 88000),
            educationLevel: .bachelors,
            icon: "trash.fill",
            color: "#1ABC9C"
        ),

        // MARK: - Climate Science (5)

        CareerPath(
            title: "Climate Scientist",
            category: "environment",
            subcategory: "Climate Science",
            description: "Study Earth's climate system using data, models, and field observations to understand climate change and predict future conditions. Inform policy and public understanding.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 60000, max: 110000),
            educationLevel: .doctorate,
            icon: "thermometer.sun.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Meteorologist",
            category: "environment",
            subcategory: "Climate Science",
            description: "Analyze atmospheric conditions to forecast weather and study weather patterns. Work in broadcasting, aviation, agriculture, and emergency management to keep communities safe.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 50000, max: 100000),
            educationLevel: .bachelors,
            icon: "cloud.sun.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Oceanographer",
            category: "environment",
            subcategory: "Climate Science",
            description: "Explore the physical, chemical, and biological properties of the world's oceans. Study ocean currents, marine ecosystems, and the ocean's role in regulating Earth's climate.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 55000, max: 100000),
            educationLevel: .masters,
            icon: "drop.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Hydrologist",
            category: "environment",
            subcategory: "Climate Science",
            description: "Study the movement and distribution of water in the environment, from rainfall to rivers and groundwater. Help manage water resources and predict floods and droughts.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 58000, max: 100000),
            educationLevel: .bachelors,
            icon: "wind",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Air Quality Specialist",
            category: "environment",
            subcategory: "Climate Science",
            description: "Monitor and analyze air pollutants to protect public health and ensure compliance with environmental regulations. Develop strategies to reduce emissions and improve air quality.",
            pathway: nil,
            requiredInterests: ["science_research", "law_government"],
            estimatedSalary: SalaryRange(min: 52000, max: 90000),
            educationLevel: .bachelors,
            icon: "aqi.medium",
            color: "#1ABC9C"
        ),

        // MARK: - Renewable Energy (5)

        CareerPath(
            title: "Renewable Energy Technician",
            category: "environment",
            subcategory: "Renewable Energy",
            description: "Install, maintain, and repair renewable energy systems such as solar panels and wind turbines. Keep clean energy infrastructure running safely and efficiently.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 45000, max: 80000),
            educationLevel: .vocational,
            icon: "bolt.circle.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Solar Panel Installer",
            category: "environment",
            subcategory: "Renewable Energy",
            description: "Install solar photovoltaic systems on homes, businesses, and utility-scale projects. Help families and communities reduce energy bills and switch to clean power.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 40000, max: 72000),
            educationLevel: .vocational,
            icon: "sun.max.fill",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Wind Turbine Technician",
            category: "environment",
            subcategory: "Renewable Energy",
            description: "Maintain and repair wind turbines to maximize their power output and service life. Work on tower systems, blades, and electrical components in the field.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 48000, max: 80000),
            educationLevel: .vocational,
            icon: "wind",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Energy Auditor",
            category: "environment",
            subcategory: "Renewable Energy",
            description: "Assess the energy use of homes and buildings to identify inefficiencies and recommend improvements. Help clients save money and reduce their environmental footprint.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 45000, max: 80000),
            educationLevel: .certification,
            icon: "checklist",
            color: "#1ABC9C"
        ),

        CareerPath(
            title: "Environmental Educator",
            category: "environment",
            subcategory: "Renewable Energy",
            description: "Teach students, community members, and organizations about environmental issues and sustainable living. Foster a sense of stewardship and inspire action to protect the planet.",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "education"],
            estimatedSalary: SalaryRange(min: 38000, max: 65000),
            educationLevel: .bachelors,
            icon: "leaf.arrow.circlepath",
            color: "#1ABC9C"
        ),
    ]
}
