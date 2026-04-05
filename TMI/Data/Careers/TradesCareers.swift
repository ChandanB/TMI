//
//  TradesCareers.swift
//  TMI
//
//  Career data for the Trades category (30 careers)
//

import Foundation

enum TradesCareers {
    static let all: [CareerPath] = [

        // MARK: - Construction

        CareerPath(
            title: "General Contractor",
            category: "trades",
            subcategory: "Construction",
            description: "General contractors manage entire construction projects from start to finish, hiring and coordinating subcontractors, ordering materials, and making sure work is completed on schedule and within budget. They are the central point of communication between property owners, architects, and all the tradespeople on a job site.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 65_000, max: 140_000),
            educationLevel: .vocational,
            icon: "building.2.crop.circle.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Carpenter",
            category: "trades",
            subcategory: "Construction",
            description: "Carpenters cut, shape, and install wood and other materials to construct the frameworks, floors, walls, and roofs of buildings, as well as furniture and fixtures. They read blueprints, use precision hand and power tools, and apply both math and creativity to bring structures to life.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 45_000, max: 90_000),
            educationLevel: .vocational,
            icon: "hammer.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Roofer",
            category: "trades",
            subcategory: "Construction",
            description: "Roofers install, repair, and replace roofs on homes and commercial buildings using materials like shingles, metal, and rubber membranes to protect structures from weather. They assess roof conditions, work at heights, and choose the right materials for long-lasting, weatherproof results.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .vocational,
            icon: "house.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Mason",
            category: "trades",
            subcategory: "Construction",
            description: "Masons build structures using bricks, concrete blocks, stone, and other masonry materials, creating walls, chimneys, fireplaces, and decorative features that are both structurally strong and visually appealing. They mix mortar, lay materials precisely, and use tools to shape and finish surfaces.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 48_000, max: 90_000),
            educationLevel: .vocational,
            icon: "square.3.layers.3d.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Ironworker",
            category: "trades",
            subcategory: "Construction",
            description: "Ironworkers erect and install the steel frameworks and reinforcing bars that form the skeleton of skyscrapers, bridges, and large structures. They work at significant heights, connecting heavy steel beams and columns with precision to ensure that major structures stand safely for decades.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 55_000, max: 105_000),
            educationLevel: .vocational,
            icon: "wrench.and.screwdriver.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Concrete Finisher",
            category: "trades",
            subcategory: "Construction",
            description: "Concrete finishers smooth, level, and texture freshly poured concrete surfaces for floors, sidewalks, roads, and other structures, ensuring they are durable and meet precise specifications. They work with floating tools, trowels, and power equipment to create surfaces that are safe, level, and long-lasting.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 42_000, max: 80_000),
            educationLevel: .vocational,
            icon: "rectangle.fill",
            color: "#E67E22"
        ),

        // MARK: - Electrical

        CareerPath(
            title: "Electrician",
            category: "trades",
            subcategory: "Electrical",
            description: "Electricians install, maintain, and repair the wiring, outlets, panels, and electrical systems that power homes, businesses, and industrial facilities. They read electrical blueprints, troubleshoot problems, and ensure all work meets safety codes and standards.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 55_000, max: 105_000),
            educationLevel: .vocational,
            icon: "bolt.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Electrical Lineworker",
            category: "trades",
            subcategory: "Electrical",
            description: "Electrical lineworkers install and maintain the power lines, transformers, and utility infrastructure that deliver electricity from power plants to homes and businesses. They often work at great heights on utility poles and towers, and are called in to restore power after storms or outages.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 65_000, max: 120_000),
            educationLevel: .vocational,
            icon: "bolt.horizontal.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Alarm Installer",
            category: "trades",
            subcategory: "Electrical",
            description: "Alarm installers set up security systems, fire alarms, and surveillance cameras in homes and businesses to protect people and property. They run wiring, mount sensors and cameras, program control panels, and show clients how to use their new systems.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 38_000, max: 72_000),
            educationLevel: .vocational,
            icon: "bell.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Solar Panel Technician",
            category: "trades",
            subcategory: "Electrical",
            description: "Solar panel technicians install, maintain, and repair photovoltaic systems on rooftops and solar farms that convert sunlight into electricity. They connect panels to inverters and the electrical grid, test system performance, and troubleshoot issues to maximize energy production.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .certification,
            icon: "sun.max.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Low-Voltage Technician",
            category: "trades",
            subcategory: "Electrical",
            description: "Low-voltage technicians install and maintain systems that run on low-power electrical signals, such as internet networks, telephone wiring, audio-visual equipment, and smart building controls. They work in offices, schools, hospitals, and homes wiring the technology infrastructure that modern buildings depend on.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 40_000, max: 78_000),
            educationLevel: .certification,
            icon: "antenna.radiowaves.left.and.right",
            color: "#E67E22"
        ),

        // MARK: - Plumbing & Pipefitting

        CareerPath(
            title: "Plumber",
            category: "trades",
            subcategory: "Plumbing & Pipefitting",
            description: "Plumbers install and repair the pipes, fixtures, and systems that carry water, gas, and waste through homes and buildings, ensuring safe and reliable water supply and drainage. They read blueprints, cut and join pipes, and troubleshoot leaks or blockages.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 55_000, max: 105_000),
            educationLevel: .vocational,
            icon: "drop.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Pipefitter",
            category: "trades",
            subcategory: "Plumbing & Pipefitting",
            description: "Pipefitters install and maintain high-pressure piping systems found in industrial plants, oil refineries, and manufacturing facilities that carry steam, chemicals, or gases. They work with specialized materials and techniques to ensure pipes can withstand extreme pressures and temperatures safely.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .vocational,
            icon: "minus.plus.batteryblock.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Steamfitter",
            category: "trades",
            subcategory: "Plumbing & Pipefitting",
            description: "Steamfitters install and maintain the pipe systems that carry steam and hot water for heating large buildings like hospitals, universities, and industrial plants. Their work requires precise knowledge of pipe sizing, pressure ratings, and welding techniques to keep steam systems safe and efficient.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 62_000, max: 115_000),
            educationLevel: .vocational,
            icon: "flame.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Sprinkler Fitter",
            category: "trades",
            subcategory: "Plumbing & Pipefitting",
            description: "Sprinkler fitters design and install fire suppression sprinkler systems in buildings to automatically control or extinguish fires and protect lives and property. They calculate water flow requirements, route piping through structures, and test systems to meet fire safety codes.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .vocational,
            icon: "drop.triangle.fill",
            color: "#E67E22"
        ),

        // MARK: - HVAC & Mechanical

        CareerPath(
            title: "HVAC Technician",
            category: "trades",
            subcategory: "HVAC & Mechanical",
            description: "HVAC technicians install, repair, and maintain heating, ventilation, and air conditioning systems that keep homes and buildings comfortable year-round. They work with refrigerants, electrical controls, and ductwork, diagnosing problems and ensuring systems run efficiently.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 50_000, max: 95_000),
            educationLevel: .vocational,
            icon: "thermometer.medium",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Refrigeration Mechanic",
            category: "trades",
            subcategory: "HVAC & Mechanical",
            description: "Refrigeration mechanics install and maintain commercial refrigeration systems used in grocery stores, restaurants, warehouses, and food processing plants to keep perishable goods at safe temperatures. They troubleshoot cooling failures, handle refrigerants safely, and perform preventive maintenance to avoid costly breakdowns.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 52_000, max: 95_000),
            educationLevel: .vocational,
            icon: "snowflake",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Boiler Operator",
            category: "trades",
            subcategory: "HVAC & Mechanical",
            description: "Boiler operators run and maintain large boiler systems that generate steam or hot water to heat buildings or power industrial processes. They monitor pressure gauges, adjust controls, perform safety checks, and respond quickly to any malfunctions to prevent dangerous situations.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 50_000, max: 90_000),
            educationLevel: .certification,
            icon: "gauge.medium",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Elevator Mechanic",
            category: "trades",
            subcategory: "HVAC & Mechanical",
            description: "Elevator mechanics install, maintain, and repair elevators, escalators, and moving walkways in buildings, ensuring these systems run safely and meet strict inspection standards. They work with electrical systems, hydraulics, and mechanical components to keep people moving safely between floors.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 80_000, max: 145_000),
            educationLevel: .vocational,
            icon: "arrow.up.arrow.down.circle.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Industrial Mechanic",
            category: "trades",
            subcategory: "HVAC & Mechanical",
            description: "Industrial mechanics maintain and repair the heavy machinery and equipment used in manufacturing plants, keeping production lines running and preventing costly shutdowns. They perform scheduled maintenance, diagnose breakdowns, and replace worn parts on conveyor systems, pumps, motors, and other industrial equipment.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .vocational,
            icon: "gearshape.2.fill",
            color: "#E67E22"
        ),

        // MARK: - Automotive

        CareerPath(
            title: "Auto Mechanic",
            category: "trades",
            subcategory: "Automotive",
            description: "Auto mechanics diagnose and repair cars and light trucks, performing everything from routine oil changes and brake jobs to complex engine and transmission repairs. They use computerized diagnostic tools alongside traditional mechanical skills to identify problems and restore vehicles to safe working condition.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .vocational,
            icon: "car.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Diesel Mechanic",
            category: "trades",
            subcategory: "Automotive",
            description: "Diesel mechanics service and repair diesel-powered vehicles including semi-trucks, buses, construction equipment, and farm machinery. They work on complex engines, fuel systems, and heavy-duty transmissions, keeping the vehicles that move goods and complete major projects on the road.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 48_000, max: 90_000),
            educationLevel: .vocational,
            icon: "truck.box.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Auto Body Technician",
            category: "trades",
            subcategory: "Automotive",
            description: "Auto body technicians repair the structural and cosmetic damage to vehicles caused by collisions, restoring cars and trucks to their original shape and appearance. They use specialized tools to straighten frames, replace panels, blend paint, and match colors so repairs are invisible.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 42_000, max: 80_000),
            educationLevel: .vocational,
            icon: "paintbrush.pointed.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Motorcycle Mechanic",
            category: "trades",
            subcategory: "Automotive",
            description: "Motorcycle mechanics inspect, service, and repair all types of motorcycles, scooters, and off-road bikes, from routine tune-ups to complete engine rebuilds. They diagnose electrical issues, adjust suspensions, and work on specialized powertrain components unique to two-wheeled vehicles.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 35_000, max: 70_000),
            educationLevel: .vocational,
            icon: "bicycle",
            color: "#E67E22"
        ),

        // MARK: - Other Trades

        CareerPath(
            title: "Welder",
            category: "trades",
            subcategory: "Other Trades",
            description: "Welders join metal parts together using intense heat and electricity to fabricate or repair structures, vehicles, pipelines, and manufactured goods. They read technical drawings, select appropriate welding techniques, and produce joints that must meet strict strength and quality standards.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 42_000, max: 85_000),
            educationLevel: .vocational,
            icon: "flame.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Machinist",
            category: "trades",
            subcategory: "Other Trades",
            description: "Machinists operate precision machine tools like lathes, mills, and CNC machines to cut metal and other materials into exact shapes and dimensions for parts used in manufacturing, aerospace, and medicine. Their work requires reading detailed engineering blueprints and producing parts accurate to thousandths of an inch.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .vocational,
            icon: "wrench.and.screwdriver.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Locksmith",
            category: "trades",
            subcategory: "Other Trades",
            description: "Locksmiths install, repair, and open locks and security systems in homes, cars, and businesses, helping people who are locked out and improving security for property owners. They cut keys, reprogram electronic locks, and advise customers on the best security solutions for their needs.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 35_000, max: 70_000),
            educationLevel: .vocational,
            icon: "key.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Glazier",
            category: "trades",
            subcategory: "Other Trades",
            description: "Glaziers cut, install, and replace glass for windows, storefronts, skylights, and glass walls in buildings, working with everything from standard panes to massive architectural glass panels. They use specialized equipment to handle fragile materials safely and ensure installations are weathertight and structurally secure.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .vocational,
            icon: "window.casement",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Painter",
            category: "trades",
            subcategory: "Other Trades",
            description: "Painters apply paint, stain, and other finishes to interior and exterior surfaces of buildings, preparing surfaces, selecting materials, and using brushes, rollers, and sprayers to achieve durable, attractive results. Professional painters also apply specialty coatings for fire protection, weatherproofing, and industrial purposes.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 38_000, max: 75_000),
            educationLevel: .vocational,
            icon: "paintbrush.fill",
            color: "#E67E22"
        ),

        CareerPath(
            title: "Tile Setter",
            category: "trades",
            subcategory: "Other Trades",
            description: "Tile setters install ceramic, porcelain, stone, and glass tiles on floors, walls, and countertops in homes, bathrooms, kitchens, and commercial spaces. They prepare surfaces, mix adhesives and grout, cut tiles to fit, and create patterns that are both watertight and visually striking.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .vocational,
            icon: "square.grid.3x3.fill",
            color: "#E67E22"
        )
    ]
}
