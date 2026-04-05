//
//  EngineeringCareers.swift
//  TMI
//
//  Career data for Engineering category (30 careers)
//

import Foundation

enum EngineeringCareers {
    static let all: [CareerPath] = [

        // MARK: - Civil & Structural (5)

        CareerPath(
            title: "Civil Engineer",
            category: "engineering",
            subcategory: "Civil & Structural",
            description: "Design and oversee construction of roads, bridges, buildings, and water systems. Help plan the infrastructure that keeps cities and communities running.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 65000, max: 115000),
            educationLevel: .bachelors,
            icon: "building.2.crop.circle.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Structural Engineer",
            category: "engineering",
            subcategory: "Civil & Structural",
            description: "Analyze and design the load-bearing elements of buildings, bridges, and other structures. Ensure that structures are safe, stable, and capable of withstanding natural forces.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 70000, max: 120000),
            educationLevel: .bachelors,
            icon: "wrench.and.screwdriver.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Transportation Engineer",
            category: "engineering",
            subcategory: "Civil & Structural",
            description: "Plan and design transportation systems including highways, railways, airports, and transit networks. Improve the safety and efficiency of how people and goods move.",
            pathway: nil,
            requiredInterests: ["engineering_building", "transportation_logistics"],
            estimatedSalary: SalaryRange(min: 65000, max: 110000),
            educationLevel: .bachelors,
            icon: "road.lanes",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Geotechnical Engineer",
            category: "engineering",
            subcategory: "Civil & Structural",
            description: "Study soil and rock mechanics to advise on the safety of construction sites and foundations. Investigate underground conditions for major infrastructure projects.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 68000, max: 115000),
            educationLevel: .bachelors,
            icon: "mountain.2.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Surveyor",
            category: "engineering",
            subcategory: "Civil & Structural",
            description: "Measure and map the Earth's surface to establish boundaries, support construction, and create accurate geographic records. Use GPS and advanced instruments in the field.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 55000, max: 95000),
            educationLevel: .bachelors,
            icon: "scope",
            color: "#2C3E50"
        ),

        // MARK: - Mechanical (5)

        CareerPath(
            title: "Mechanical Engineer",
            category: "engineering",
            subcategory: "Mechanical",
            description: "Design and test mechanical devices, from tiny machine parts to large industrial systems. Apply physics and materials science to solve real engineering problems.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 70000, max: 125000),
            educationLevel: .bachelors,
            icon: "gearshape.2.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Robotics Engineer",
            category: "engineering",
            subcategory: "Mechanical",
            description: "Design, build, and program robots for manufacturing, medicine, exploration, and more. Combine mechanical engineering with electronics and computer science.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 80000, max: 145000),
            educationLevel: .bachelors,
            icon: "cpu.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "HVAC Engineer",
            category: "engineering",
            subcategory: "Mechanical",
            description: "Design heating, ventilation, and air conditioning systems for buildings of all sizes. Ensure indoor environments are comfortable, healthy, and energy efficient.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 55000, max: 100000),
            educationLevel: .bachelors,
            icon: "thermometer.medium",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Automotive Engineer",
            category: "engineering",
            subcategory: "Mechanical",
            description: "Design and develop vehicles and automotive systems, from engines and safety features to electric drivetrains. Shape the future of personal transportation.",
            pathway: nil,
            requiredInterests: ["engineering_building", "transportation_logistics"],
            estimatedSalary: SalaryRange(min: 72000, max: 130000),
            educationLevel: .bachelors,
            icon: "car.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Manufacturing Engineer",
            category: "engineering",
            subcategory: "Mechanical",
            description: "Optimize production processes and factory systems to create products efficiently and safely. Bridge the gap between product design and large-scale manufacturing.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 65000, max: 110000),
            educationLevel: .bachelors,
            icon: "wrench.fill",
            color: "#2C3E50"
        ),

        // MARK: - Electrical & Electronic (5)

        CareerPath(
            title: "Electrical Engineer",
            category: "engineering",
            subcategory: "Electrical & Electronic",
            description: "Design and develop electrical systems for buildings, power grids, and electronic devices. Ensure safe and efficient use of electricity across industries.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 72000, max: 130000),
            educationLevel: .bachelors,
            icon: "bolt.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Electronics Engineer",
            category: "engineering",
            subcategory: "Electrical & Electronic",
            description: "Design circuits, microchips, and electronic devices used in consumer products, medical equipment, and communication systems. Turn ideas into working hardware.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 70000, max: 125000),
            educationLevel: .bachelors,
            icon: "memorychip",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Power Systems Engineer",
            category: "engineering",
            subcategory: "Electrical & Electronic",
            description: "Design and maintain systems that generate and distribute electrical power, including substations and smart grids. Keep the lights on for homes and businesses.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 75000, max: 130000),
            educationLevel: .bachelors,
            icon: "powerplug.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Telecommunications Engineer",
            category: "engineering",
            subcategory: "Electrical & Electronic",
            description: "Design and maintain the networks that power phone calls, the internet, and wireless communications. Connect people and devices across the globe.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 70000, max: 120000),
            educationLevel: .bachelors,
            icon: "antenna.radiowaves.left.and.right",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Control Systems Engineer",
            category: "engineering",
            subcategory: "Electrical & Electronic",
            description: "Design automated systems that regulate machines, industrial processes, and robotics. Use sensors, feedback, and programming to keep complex systems running smoothly.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 75000, max: 130000),
            educationLevel: .bachelors,
            icon: "slider.horizontal.3",
            color: "#2C3E50"
        ),

        // MARK: - Chemical & Biomedical (5)

        CareerPath(
            title: "Chemical Engineer",
            category: "engineering",
            subcategory: "Chemical & Biomedical",
            description: "Design processes to manufacture chemicals, fuels, food, medicines, and materials. Apply chemistry and physics to solve production challenges at industrial scale.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 75000, max: 135000),
            educationLevel: .bachelors,
            icon: "flask.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Biomedical Engineer",
            category: "engineering",
            subcategory: "Chemical & Biomedical",
            description: "Develop medical devices, prosthetics, and diagnostic equipment that improve patient care. Combine engineering principles with medical and biological sciences.",
            pathway: nil,
            requiredInterests: ["engineering_building", "health_wellness"],
            estimatedSalary: SalaryRange(min: 70000, max: 125000),
            educationLevel: .bachelors,
            icon: "heart.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Pharmaceutical Engineer",
            category: "engineering",
            subcategory: "Chemical & Biomedical",
            description: "Design and optimize the manufacturing processes used to produce medications and vaccines at scale. Ensure drug products meet strict safety and quality standards.",
            pathway: nil,
            requiredInterests: ["engineering_building", "health_wellness"],
            estimatedSalary: SalaryRange(min: 72000, max: 130000),
            educationLevel: .bachelors,
            icon: "pills.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Materials Engineer",
            category: "engineering",
            subcategory: "Chemical & Biomedical",
            description: "Research and develop new materials like metals, ceramics, polymers, and composites for use in technology, construction, and manufacturing. Create the building blocks of innovation.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 68000, max: 120000),
            educationLevel: .bachelors,
            icon: "cube.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Process Engineer",
            category: "engineering",
            subcategory: "Chemical & Biomedical",
            description: "Improve industrial production methods to increase efficiency, reduce costs, and minimize waste. Analyze and refine every step of a manufacturing or chemical process.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 68000, max: 115000),
            educationLevel: .bachelors,
            icon: "gearshape.fill",
            color: "#2C3E50"
        ),

        // MARK: - Aerospace (4)

        CareerPath(
            title: "Aerospace Engineer",
            category: "engineering",
            subcategory: "Aerospace",
            description: "Design and test aircraft, spacecraft, and propulsion systems. Work on everything from commercial jets to satellites and deep-space exploration vehicles.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 80000, max: 150000),
            educationLevel: .bachelors,
            icon: "airplane",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Avionics Engineer",
            category: "engineering",
            subcategory: "Aerospace",
            description: "Design the electronic systems used in aircraft, including navigation, communication, and flight control systems. Keep pilots informed and aircraft flying safely.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 80000, max: 145000),
            educationLevel: .bachelors,
            icon: "airplane.circle.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Spacecraft Engineer",
            category: "engineering",
            subcategory: "Aerospace",
            description: "Design satellites, space probes, and crewed spacecraft that operate in the extreme environment of outer space. Turn science fiction into reality.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 85000, max: 160000),
            educationLevel: .masters,
            icon: "sparkles",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Flight Test Engineer",
            category: "engineering",
            subcategory: "Aerospace",
            description: "Plan and conduct tests on aircraft and spacecraft to verify performance and safety before certification. Collect data and work with pilots to push the limits of flight.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 85000, max: 150000),
            educationLevel: .bachelors,
            icon: "waveform.path",
            color: "#2C3E50"
        ),

        // MARK: - Computer & Systems (6)

        CareerPath(
            title: "Computer Hardware Engineer",
            category: "engineering",
            subcategory: "Computer & Systems",
            description: "Research, design, and test computer processors, circuit boards, memory devices, and other hardware components. Shape the physical machines that run our digital world.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 90000, max: 170000),
            educationLevel: .bachelors,
            icon: "cpu",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Network Engineer",
            category: "engineering",
            subcategory: "Computer & Systems",
            description: "Design, build, and maintain the computer networks that power businesses and the internet. Ensure fast, secure, and reliable data communication.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 75000, max: 135000),
            educationLevel: .bachelors,
            icon: "network",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Systems Engineer",
            category: "engineering",
            subcategory: "Computer & Systems",
            description: "Oversee the design and integration of complex engineering systems made up of many parts. Ensure all components work together to achieve a system's goals.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 80000, max: 145000),
            educationLevel: .bachelors,
            icon: "gearshape.2",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Nuclear Engineer",
            category: "engineering",
            subcategory: "Computer & Systems",
            description: "Develop and maintain systems that use nuclear energy for power generation, medicine, and research. Work to make nuclear technology safer and more efficient.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 85000, max: 150000),
            educationLevel: .bachelors,
            icon: "atom",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Marine Engineer",
            category: "engineering",
            subcategory: "Computer & Systems",
            description: "Design and maintain the mechanical systems of ships, submarines, and offshore platforms. Keep vessels and marine equipment operating safely at sea.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 70000, max: 125000),
            educationLevel: .bachelors,
            icon: "ferry.fill",
            color: "#2C3E50"
        ),

        CareerPath(
            title: "Industrial Engineer",
            category: "engineering",
            subcategory: "Computer & Systems",
            description: "Eliminate waste and improve efficiency in production systems, supply chains, and workplaces. Use data and engineering principles to help organizations perform better.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 68000, max: 120000),
            educationLevel: .bachelors,
            icon: "chart.line.uptrend.xyaxis",
            color: "#2C3E50"
        ),
    ]
}
