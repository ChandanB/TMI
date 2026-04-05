//
//  BusinessCareers.swift
//  TMI
//
//  Career data for the Business & Finance category
//

import Foundation

enum BusinessCareers {
    static let all: [CareerPath] = [

        // MARK: - Finance

        CareerPath(
            title: "Accountant",
            category: "business",
            subcategory: "Finance",
            description: "Prepare and examine financial records to ensure accuracy and compliance with laws. Accountants help individuals and organizations manage their money wisely.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50000, max: 100000),
            educationLevel: .bachelors,
            icon: "dollarsign.circle.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Auditor",
            category: "business",
            subcategory: "Finance",
            description: "Independently review financial statements and internal controls to detect errors or fraud. Auditors provide organizations with confidence that their finances are accurate.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "law_government"],
            estimatedSalary: SalaryRange(min: 55000, max: 110000),
            educationLevel: .bachelors,
            icon: "checkmark.shield.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Investment Banker",
            category: "business",
            subcategory: "Finance",
            description: "Help companies raise money by issuing stocks or bonds and advise on mergers and acquisitions. Investment bankers work in fast-paced financial environments.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 80000, max: 300000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Insurance Agent",
            category: "business",
            subcategory: "Finance",
            description: "Sell insurance policies to individuals and businesses to protect them from financial loss. Insurance agents assess client needs and match them with appropriate coverage.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 110000),
            educationLevel: .someCollege,
            icon: "umbrella.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Stockbroker",
            category: "business",
            subcategory: "Finance",
            description: "Buy and sell stocks, bonds, and other securities on behalf of clients to help them grow their wealth. Stockbrokers analyze market trends and provide investment advice.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55000, max: 200000),
            educationLevel: .bachelors,
            icon: "chart.line.uptrend.xyaxis",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Tax Consultant",
            category: "business",
            subcategory: "Finance",
            description: "Advise individuals and businesses on tax strategy, preparation, and compliance with tax laws. Tax consultants help clients minimize taxes legally and avoid costly mistakes.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "law_government"],
            estimatedSalary: SalaryRange(min: 50000, max: 120000),
            educationLevel: .bachelors,
            icon: "doc.text.magnifyingglass",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Actuary",
            category: "business",
            subcategory: "Finance",
            description: "Use mathematics and statistics to assess financial risk for insurance companies and businesses. Actuaries analyze data to predict future events and their financial impacts.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "science_research"],
            estimatedSalary: SalaryRange(min: 70000, max: 160000),
            educationLevel: .bachelors,
            icon: "function",
            color: "#2ECC71"
        ),

        // MARK: - Management

        CareerPath(
            title: "CEO",
            category: "business",
            subcategory: "Management",
            description: "Lead an organization at the highest level, setting vision, strategy, and culture. CEOs are responsible for the overall success of a company.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 100000, max: 1000000),
            educationLevel: .bachelors,
            icon: "person.crop.circle.badge.checkmark",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Operations Manager",
            category: "business",
            subcategory: "Management",
            description: "Oversee the day-to-day activities of a business to ensure efficient and effective operations. Operations managers solve problems and improve processes across departments.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "gearshape.2.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Supply Chain Manager",
            category: "business",
            subcategory: "Management",
            description: "Manage the flow of goods, materials, and information from suppliers to customers. Supply chain managers optimize logistics to reduce costs and meet demand.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "transportation_logistics"],
            estimatedSalary: SalaryRange(min: 65000, max: 130000),
            educationLevel: .bachelors,
            icon: "arrow.triangle.2.circlepath",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Product Manager",
            category: "business",
            subcategory: "Management",
            description: "Guide the development and launch of products from concept to market. Product managers work across engineering, design, and business teams to build things customers love.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "technology"],
            estimatedSalary: SalaryRange(min: 75000, max: 160000),
            educationLevel: .bachelors,
            icon: "square.grid.2x2.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Project Manager",
            category: "business",
            subcategory: "Management",
            description: "Plan, execute, and close projects on time and within budget across industries. Project managers coordinate teams, track progress, and manage risks.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "chart.bar.doc.horizontal.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Management Consultant",
            category: "business",
            subcategory: "Management",
            description: "Advise organizations on how to improve performance, solve problems, and implement change. Management consultants bring outside expertise to tackle complex business challenges.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "technology"],
            estimatedSalary: SalaryRange(min: 75000, max: 200000),
            educationLevel: .bachelors,
            icon: "lightbulb.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Office Manager",
            category: "business",
            subcategory: "Management",
            description: "Keep workplace operations running smoothly by managing schedules, supplies, and staff coordination. Office managers are the organizational backbone of any workplace.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .someCollege,
            icon: "building.fill",
            color: "#2ECC71"
        ),

        // MARK: - Marketing & Sales

        CareerPath(
            title: "Sales Manager",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Lead a sales team and develop strategies to meet revenue targets. Sales managers coach their team, track performance, and build relationships with key clients.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 140000),
            educationLevel: .bachelors,
            icon: "cart.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Advertising Manager",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Plan and oversee advertising campaigns across media channels to promote products and services. Advertising managers work with creative teams and track campaign performance.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "creative_arts"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "megaphone.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Market Research Analyst",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Study market trends and consumer behavior to help businesses make smart decisions. Market research analysts use data and surveys to understand what customers want.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "science_research"],
            estimatedSalary: SalaryRange(min: 50000, max: 100000),
            educationLevel: .bachelors,
            icon: "chart.bar.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Brand Manager",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Develop and maintain a company's brand identity to build recognition and customer loyalty. Brand managers shape how a company is perceived in the marketplace.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "creative_arts"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "star.circle.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "E-commerce Manager",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Oversee online retail operations including product listings, website performance, and digital marketing. E-commerce managers blend business strategy with technology to drive online sales.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "technology"],
            estimatedSalary: SalaryRange(min: 55000, max: 120000),
            educationLevel: .bachelors,
            icon: "bag.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Retail Manager",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Manage store operations, staff, and sales performance to deliver great customer experiences. Retail managers lead teams and ensure stores meet business goals.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 85000),
            educationLevel: .someCollege,
            icon: "storefront.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Buyer",
            category: "business",
            subcategory: "Marketing & Sales",
            description: "Select and purchase products for retailers, wholesalers, or manufacturers. Buyers analyze trends, negotiate prices, and decide which items to stock for customers.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50000, max: 105000),
            educationLevel: .bachelors,
            icon: "tag.fill",
            color: "#2ECC71"
        ),

        // MARK: - Human Resources

        CareerPath(
            title: "HR Manager",
            category: "business",
            subcategory: "Human Resources",
            description: "Oversee recruiting, employee relations, benefits, and workplace culture for an organization. HR managers ensure people thrive and the company follows employment laws.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "social_services"],
            estimatedSalary: SalaryRange(min: 60000, max: 125000),
            educationLevel: .bachelors,
            icon: "person.2.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Recruiter",
            category: "business",
            subcategory: "Human Resources",
            description: "Source, interview, and hire talent for organizations across industries. Recruiters build relationships with candidates and match them with the right roles.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .bachelors,
            icon: "person.badge.plus",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Training Manager",
            category: "business",
            subcategory: "Human Resources",
            description: "Design and deliver training programs that help employees grow their skills and do their jobs better. Training managers assess needs and measure the impact of learning initiatives.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "education"],
            estimatedSalary: SalaryRange(min: 55000, max: 110000),
            educationLevel: .bachelors,
            icon: "graduationcap.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Compensation Analyst",
            category: "business",
            subcategory: "Human Resources",
            description: "Research and design pay and benefits packages to attract and retain talent. Compensation analysts ensure employee salaries are fair and competitive.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "science_research"],
            estimatedSalary: SalaryRange(min: 55000, max: 105000),
            educationLevel: .bachelors,
            icon: "dollarsign.square.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Labor Relations Specialist",
            category: "business",
            subcategory: "Human Resources",
            description: "Manage the relationship between organizations and labor unions, negotiating contracts and resolving disputes. Labor relations specialists ensure fair and lawful workplace practices.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "law_government"],
            estimatedSalary: SalaryRange(min: 60000, max: 115000),
            educationLevel: .bachelors,
            icon: "hand.raised.fill",
            color: "#2ECC71"
        ),

        // MARK: - Real Estate

        CareerPath(
            title: "Real Estate Agent",
            category: "business",
            subcategory: "Real Estate",
            description: "Help buyers, sellers, and renters navigate real estate transactions. Real estate agents guide clients through one of the biggest financial decisions of their lives.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 35000, max: 150000),
            educationLevel: .certification,
            icon: "house.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Property Manager",
            category: "business",
            subcategory: "Real Estate",
            description: "Oversee the operations and maintenance of residential or commercial rental properties. Property managers handle tenant relations, rent collection, and building upkeep.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 90000),
            educationLevel: .someCollege,
            icon: "building.2.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Real Estate Developer",
            category: "business",
            subcategory: "Real Estate",
            description: "Identify, finance, and oversee construction or renovation of properties for sale or lease. Real estate developers shape communities and create long-term value.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "engineering_building"],
            estimatedSalary: SalaryRange(min: 75000, max: 400000),
            educationLevel: .bachelors,
            icon: "hammer.fill",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Appraiser",
            category: "business",
            subcategory: "Real Estate",
            description: "Estimate the market value of real estate properties for sales, taxes, and financing purposes. Appraisers inspect properties and analyze comparable sales data.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "science_research"],
            estimatedSalary: SalaryRange(min: 50000, max: 100000),
            educationLevel: .certification,
            icon: "magnifyingglass.circle.fill",
            color: "#2ECC71"
        ),

        // MARK: - Entrepreneurship

        CareerPath(
            title: "Franchise Owner",
            category: "business",
            subcategory: "Entrepreneurship",
            description: "Own and operate a business using an established brand and business model from a franchise company. Franchise owners benefit from proven systems while running their own operation.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50000, max: 250000),
            educationLevel: .varies,
            icon: "storefront",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Import/Export Specialist",
            category: "business",
            subcategory: "Entrepreneurship",
            description: "Facilitate the buying and selling of goods across international borders. Import/export specialists navigate trade regulations, shipping logistics, and currency exchange.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "transportation_logistics"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .bachelors,
            icon: "globe",
            color: "#2ECC71"
        ),

        CareerPath(
            title: "Event Planner",
            category: "business",
            subcategory: "Entrepreneurship",
            description: "Organize and coordinate events such as weddings, corporate meetings, and festivals. Event planners manage budgets, vendors, and timelines to create memorable experiences.",
            pathway: nil,
            requiredInterests: ["business_entrepreneurship", "hospitality_tourism"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .bachelors,
            icon: "calendar.badge.plus",
            color: "#2ECC71"
        ),

    ]
}
