//
//  ManufacturingCareers.swift
//  TMI
//
//  Career data for the Manufacturing category (20 careers)
//

import Foundation

enum ManufacturingCareers {
    static let all: [CareerPath] = [

        // MARK: - Production

        CareerPath(
            title: "Production Manager",
            category: "manufacturing",
            subcategory: "Production",
            description: "Production managers oversee the entire process of manufacturing products, ensuring that goods are made on time, within budget, and to the required quality standards. They coordinate workers, machines, and materials to keep the production floor running efficiently.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 70_000, max: 140_000),
            educationLevel: .bachelors,
            icon: "gearshape.2.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Assembly Line Supervisor",
            category: "manufacturing",
            subcategory: "Production",
            description: "Assembly line supervisors manage teams of workers who put together products step by step on a production line, making sure each station runs safely and meets targets. They train new workers, solve problems, and track production output.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 48_000, max: 85_000),
            educationLevel: .someCollege,
            icon: "arrow.triangle.2.circlepath",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "CNC Machine Operator",
            category: "manufacturing",
            subcategory: "Production",
            description: "CNC (Computer Numerical Control) machine operators program and run computer-guided machines that cut, shape, and drill metal and other materials with extreme precision. They read technical blueprints and adjust settings to produce parts that match exact specifications.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 40_000, max: 75_000),
            educationLevel: .vocational,
            icon: "wrench.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Plant Manager",
            category: "manufacturing",
            subcategory: "Production",
            description: "Plant managers are responsible for the overall operation of a manufacturing facility, overseeing production, safety, personnel, and finances. They set goals, solve large-scale problems, and ensure the plant meets both company and regulatory standards.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 90_000, max: 175_000),
            educationLevel: .bachelors,
            icon: "building.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Manufacturing Technician",
            category: "manufacturing",
            subcategory: "Production",
            description: "Manufacturing technicians support production operations by setting up equipment, troubleshooting mechanical problems, and performing routine maintenance on the machines used to make products. They are the hands-on problem solvers that keep a factory floor functioning.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 38_000, max: 70_000),
            educationLevel: .vocational,
            icon: "hammer.fill",
            color: "#95A5A6"
        ),

        // MARK: - Quality & Safety

        CareerPath(
            title: "Quality Control Inspector",
            category: "manufacturing",
            subcategory: "Quality & Safety",
            description: "Quality control inspectors examine products during and after manufacturing to identify defects and ensure every item meets established standards before it reaches consumers. They use measuring tools, visual checks, and detailed testing procedures.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 38_000, max: 72_000),
            educationLevel: .someCollege,
            icon: "checkmark.circle.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Quality Assurance Manager",
            category: "manufacturing",
            subcategory: "Quality & Safety",
            description: "Quality assurance managers develop and oversee systems that prevent product defects rather than just catching them after the fact. They create testing protocols, analyze data trends, and lead teams dedicated to continuous improvement.",
            pathway: nil,
            requiredInterests: ["engineering_building", "business_entrepreneurship", "science_research"],
            estimatedSalary: SalaryRange(min: 70_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "checkmark.seal.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Safety Manager",
            category: "manufacturing",
            subcategory: "Quality & Safety",
            description: "Safety managers in manufacturing facilities create and enforce programs that protect workers from injuries and illnesses on the job. They conduct safety audits, investigate accidents, and train employees on proper procedures.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 65_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "exclamationmark.shield.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Occupational Health Specialist",
            category: "manufacturing",
            subcategory: "Quality & Safety",
            description: "Occupational health specialists identify and address health risks in the workplace, from exposure to chemicals to repetitive strain injuries. They design wellness programs and work with management to create healthier work environments.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .bachelors,
            icon: "heart.text.clipboard.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Process Engineer",
            category: "manufacturing",
            subcategory: "Quality & Safety",
            description: "Process engineers analyze and improve the methods used to manufacture products, looking for ways to reduce costs, increase speed, and minimize waste. They apply engineering principles to optimize every step of a production process.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 72_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "gearshape.fill",
            color: "#95A5A6"
        ),

        // MARK: - Industrial Design

        CareerPath(
            title: "Industrial Designer",
            category: "manufacturing",
            subcategory: "Industrial Design",
            description: "Industrial designers create the look, feel, and functionality of mass-produced products—from furniture to electronics to medical devices. They combine artistic creativity with engineering thinking to make products that are both beautiful and practical.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 55_000, max: 105_000),
            educationLevel: .bachelors,
            icon: "pencil.and.ruler.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Product Designer",
            category: "manufacturing",
            subcategory: "Industrial Design",
            description: "Product designers focus on user experience and aesthetics to create new consumer goods that people will want to buy and use. They research user needs, sketch concepts, build prototypes, and refine designs through testing.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 60_000, max: 120_000),
            educationLevel: .bachelors,
            icon: "cube.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Packaging Designer",
            category: "manufacturing",
            subcategory: "Industrial Design",
            description: "Packaging designers create the boxes, containers, and wrapping that protect products and attract customers on store shelves. They balance visual design, material choices, structural integrity, and sustainability in every project.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 50_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "shippingbox.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "CAD Technician",
            category: "manufacturing",
            subcategory: "Industrial Design",
            description: "CAD (Computer-Aided Design) technicians use specialized software to create detailed 2D drawings and 3D models of parts and assemblies used in manufacturing. Their precise digital blueprints guide machinists and engineers throughout the production process.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 45_000, max: 80_000),
            educationLevel: .vocational,
            icon: "ruler.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "3D Printing Specialist",
            category: "manufacturing",
            subcategory: "Industrial Design",
            description: "3D printing specialists operate and maintain additive manufacturing equipment to produce physical prototypes and end-use parts layer by layer from digital designs. They work across industries from aerospace to healthcare, bringing digital ideas into physical reality.",
            pathway: nil,
            requiredInterests: ["engineering_building", "technology"],
            estimatedSalary: SalaryRange(min: 45_000, max: 90_000),
            educationLevel: .someCollege,
            icon: "printer.fill",
            color: "#95A5A6"
        ),

        // MARK: - Materials & Textiles

        CareerPath(
            title: "Textile Designer",
            category: "manufacturing",
            subcategory: "Materials & Textiles",
            description: "Textile designers create patterns, colors, and textures for fabrics used in clothing, furniture, and home goods. They combine artistic creativity with knowledge of weaving, dyeing, and fiber technology to develop materials that are both visually appealing and functional.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 42_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "paintpalette.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Materials Scientist",
            category: "manufacturing",
            subcategory: "Materials & Textiles",
            description: "Materials scientists study the properties of metals, ceramics, plastics, and other substances to develop new materials or improve existing ones for use in manufacturing. Their discoveries drive innovation in industries from electronics to construction.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 65_000, max: 130_000),
            educationLevel: .masters,
            icon: "atom",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Plastics Technician",
            category: "manufacturing",
            subcategory: "Materials & Textiles",
            description: "Plastics technicians set up, operate, and maintain molding and forming machines that shape plastic into products like containers, car parts, and medical devices. They test finished items and troubleshoot production issues to maintain quality.",
            pathway: nil,
            requiredInterests: ["engineering_building", "science_research"],
            estimatedSalary: SalaryRange(min: 38_000, max: 68_000),
            educationLevel: .vocational,
            icon: "cube.transparent.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Metal Fabricator",
            category: "manufacturing",
            subcategory: "Materials & Textiles",
            description: "Metal fabricators cut, bend, and assemble metal components to create structures and products ranging from steel beams to custom machine parts. They work with blueprints and use tools like welders, plasma cutters, and press brakes.",
            pathway: nil,
            requiredInterests: ["engineering_building"],
            estimatedSalary: SalaryRange(min: 40_000, max: 75_000),
            educationLevel: .vocational,
            icon: "hammer.fill",
            color: "#95A5A6"
        ),

        CareerPath(
            title: "Woodworker",
            category: "manufacturing",
            subcategory: "Materials & Textiles",
            description: "Woodworkers craft furniture, cabinets, and other wood products using both hand tools and power machinery, combining technical skill with artistic sensibility. They may work in large production shops or as independent craftspeople creating custom pieces.",
            pathway: nil,
            requiredInterests: ["engineering_building", "creative_arts"],
            estimatedSalary: SalaryRange(min: 32_000, max: 65_000),
            educationLevel: .vocational,
            icon: "tree.fill",
            color: "#95A5A6"
        )
    ]
}
