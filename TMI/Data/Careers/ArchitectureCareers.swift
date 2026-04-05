//
//  ArchitectureCareers.swift
//  TMI
//
//  Career data for the Architecture category (20 careers)
//

import Foundation

enum ArchitectureCareers {
    static let all: [CareerPath] = [

        // MARK: - Building Design

        CareerPath(
            title: "Architect",
            category: "architecture",
            subcategory: "Building Design",
            description: "Architects design buildings and structures, balancing aesthetics, functionality, safety, and environmental impact. They work closely with clients and construction teams from the initial concept all the way through to the finished building.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 70_000, max: 140_000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Residential Architect",
            category: "architecture",
            subcategory: "Building Design",
            description: "Residential architects specialize in designing homes and living spaces that meet the personal needs and tastes of individual clients. They create everything from custom dream homes to entire housing developments.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 65_000, max: 120_000),
            educationLevel: .bachelors,
            icon: "house.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Commercial Architect",
            category: "architecture",
            subcategory: "Building Design",
            description: "Commercial architects design offices, retail spaces, hotels, and other non-residential buildings that serve businesses and the public. They must consider factors like accessibility, foot traffic flow, and local building codes.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 72_000, max: 145_000),
            educationLevel: .bachelors,
            icon: "building.2.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Sustainable Building Designer",
            category: "architecture",
            subcategory: "Building Design",
            description: "Sustainable building designers create structures that use less energy, produce less waste, and work with the natural environment rather than against it. They incorporate solar panels, green roofs, and recycled materials into innovative building designs.",
            pathway: nil,
            requiredInterests: ["engineering_building", "agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 68_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "leaf.circle.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Restoration Architect",
            category: "architecture",
            subcategory: "Building Design",
            description: "Restoration architects preserve and repair historic buildings, carefully researching original designs and materials to bring aging structures back to their former glory. Their work protects cultural heritage while giving old buildings a new life.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts", "law_government"],
            estimatedSalary: SalaryRange(min: 62_000, max: 115_000),
            educationLevel: .masters,
            icon: "building.columns.circle.fill",
            color: "#8E44AD"
        ),

        // MARK: - Urban Planning

        CareerPath(
            title: "Urban Planner",
            category: "architecture",
            subcategory: "Urban Planning",
            description: "Urban planners develop plans for how cities and towns should grow and use their land, balancing housing, transportation, parks, and businesses. They work with governments and communities to create livable, equitable, and sustainable places.",
            pathway: nil,
            requiredInterests: ["engineering_building", "law_government"],
            estimatedSalary: SalaryRange(min: 58_000, max: 105_000),
            educationLevel: .masters,
            icon: "map.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "City Manager",
            category: "architecture",
            subcategory: "Urban Planning",
            description: "City managers oversee the day-to-day operations of a city's government, managing departments like police, fire, public works, and parks. They implement policies set by elected officials and ensure city services run efficiently.",
            pathway: nil,
            requiredInterests: ["engineering_building", "law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 85_000, max: 175_000),
            educationLevel: .masters,
            icon: "building.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Regional Planner",
            category: "architecture",
            subcategory: "Urban Planning",
            description: "Regional planners focus on land use and development across larger geographic areas that span multiple cities or counties. They coordinate housing, transportation, and environmental protection at a regional scale to address issues no single city can solve alone.",
            pathway: nil,
            requiredInterests: ["engineering_building", "law_government", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 60_000, max: 105_000),
            educationLevel: .masters,
            icon: "map.circle.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Transportation Planner",
            category: "architecture",
            subcategory: "Urban Planning",
            description: "Transportation planners design road networks, public transit systems, bike lanes, and pedestrian paths that help people move around cities efficiently and safely. They analyze traffic data and community needs to create better ways to get from place to place.",
            pathway: nil,
            requiredInterests: ["engineering_building", "law_government"],
            estimatedSalary: SalaryRange(min: 62_000, max: 110_000),
            educationLevel: .masters,
            icon: "car.2.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Zoning Specialist",
            category: "architecture",
            subcategory: "Urban Planning",
            description: "Zoning specialists enforce and interpret land-use regulations that determine what can be built where in a community. They review building permit applications, advise property owners on regulations, and help governments update their zoning codes.",
            pathway: nil,
            requiredInterests: ["engineering_building", "law_government"],
            estimatedSalary: SalaryRange(min: 50_000, max: 90_000),
            educationLevel: .bachelors,
            icon: "doc.text.fill",
            color: "#8E44AD"
        ),

        // MARK: - Landscape Architecture

        CareerPath(
            title: "Landscape Architect",
            category: "architecture",
            subcategory: "Landscape Architecture",
            description: "Landscape architects design outdoor spaces—such as parks, plazas, campuses, and waterfronts—that are beautiful, functional, and environmentally sound. They combine artistic vision with knowledge of plants, soil, and ecology.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 60_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "tree.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Garden Designer",
            category: "architecture",
            subcategory: "Landscape Architecture",
            description: "Garden designers create personalized outdoor spaces for homes, businesses, and public areas, selecting plants and hardscape features to reflect a client's style and complement the surrounding environment. Their work transforms ordinary yards into beautiful, livable outdoor rooms.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .someCollege,
            icon: "camera.macro",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Environmental Planner",
            category: "architecture",
            subcategory: "Landscape Architecture",
            description: "Environmental planners assess how development projects will impact the natural environment and recommend strategies to reduce that impact. They help governments and developers meet environmental regulations while still achieving their building goals.",
            pathway: nil,
            requiredInterests: ["engineering_building", "agriculture_nature", "law_government"],
            estimatedSalary: SalaryRange(min: 58_000, max: 100_000),
            educationLevel: .masters,
            icon: "globe.americas.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Green Infrastructure Designer",
            category: "architecture",
            subcategory: "Landscape Architecture",
            description: "Green infrastructure designers create nature-based solutions for urban challenges, like using rain gardens to manage stormwater or planting tree canopies to cool city streets. Their work blends engineering with ecology to make cities more resilient.",
            pathway: nil,
            requiredInterests: ["engineering_building", "agriculture_nature", "science_research"],
            estimatedSalary: SalaryRange(min: 58_000, max: 105_000),
            educationLevel: .bachelors,
            icon: "leaf.fill",
            color: "#8E44AD"
        ),

        // MARK: - Interior & Exhibition

        CareerPath(
            title: "Interior Designer",
            category: "architecture",
            subcategory: "Interior & Exhibition",
            description: "Interior designers plan and create functional, safe, and beautiful indoor spaces for homes, offices, restaurants, and other buildings. They select colors, furniture, lighting, and materials to shape how a space looks and feels.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 48_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "sofa.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Set Designer",
            category: "architecture",
            subcategory: "Interior & Exhibition",
            description: "Set designers create the physical environments seen in films, TV shows, theater productions, and commercials. They work closely with directors to build worlds that support the story, designing and constructing everything from living rooms to alien planets.",
            pathway: nil,
            requiredInterests: ["creative_arts", "engineering_building"],
            estimatedSalary: SalaryRange(min: 45_000, max: 100_000),
            educationLevel: .bachelors,
            icon: "theatermasks.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Exhibition Designer",
            category: "architecture",
            subcategory: "Interior & Exhibition",
            description: "Exhibition designers create the layouts and visual displays for museums, galleries, trade shows, and public events. They plan how visitors move through a space and how information and objects are presented in an engaging and accessible way.",
            pathway: nil,
            requiredInterests: ["creative_arts", "engineering_building"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "photo.artframe",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Lighting Designer",
            category: "architecture",
            subcategory: "Interior & Exhibition",
            description: "Lighting designers plan how artificial and natural light will be used in buildings, events, and performances to create the desired mood and functionality. They work on everything from architectural lighting in office buildings to dramatic stage lighting for concerts.",
            pathway: nil,
            requiredInterests: ["creative_arts", "engineering_building"],
            estimatedSalary: SalaryRange(min: 48_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "lamp.desk.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Kitchen and Bath Designer",
            category: "architecture",
            subcategory: "Interior & Exhibition",
            description: "Kitchen and bath designers specialize in planning and redesigning two of the most important—and technically complex—rooms in a home. They balance aesthetics with function, helping clients choose cabinets, countertops, fixtures, and layouts that fit their lifestyle.",
            pathway: nil,
            requiredInterests: ["creative_arts", "engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .certification,
            icon: "house.and.flag.fill",
            color: "#8E44AD"
        ),

        CareerPath(
            title: "Furniture Designer",
            category: "architecture",
            subcategory: "Interior & Exhibition",
            description: "Furniture designers create original pieces that are both functional and visually appealing, working with wood, metal, fabric, and other materials. They sketch concepts, build prototypes, and consider ergonomics to design pieces that fit how people actually live and work.",
            pathway: nil,
            requiredInterests: ["creative_arts", "engineering_building"],
            estimatedSalary: SalaryRange(min: 40_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "paintbrush.pointed.fill",
            color: "#8E44AD"
        )
    ]
}
