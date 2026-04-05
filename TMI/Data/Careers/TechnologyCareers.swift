//
//  TechnologyCareers.swift
//  TMI
//
//  Career data for the Technology category (35 careers)
//

import Foundation

enum TechnologyCareers {
    static let all: [CareerPath] = [

        // MARK: - Software Development

        CareerPath(
            title: "Frontend Developer",
            category: "technology",
            subcategory: "Software Development",
            description: "Frontend developers build the parts of websites and apps that users see and interact with, writing code that turns designs into real, working interfaces. They use languages like HTML, CSS, and JavaScript to create fast, accessible, and visually appealing experiences.",
            pathway: nil,
            requiredInterests: ["technology", "creative_arts"],
            estimatedSalary: SalaryRange(min: 65_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "chevron.left.forwardslash.chevron.right",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Backend Developer",
            category: "technology",
            subcategory: "Software Development",
            description: "Backend developers build the behind-the-scenes systems that power apps and websites, handling databases, servers, and the logic that processes data. They write code that makes sure information is stored safely and delivered quickly to users.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 70_000, max: 140_000),
            educationLevel: .bachelors,
            icon: "server.rack",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Full-Stack Developer",
            category: "technology",
            subcategory: "Software Development",
            description: "Full-stack developers work on both the front and back ends of software, building everything from user interfaces to databases and server logic. Their broad skill set lets them understand and contribute to every layer of an application.",
            pathway: nil,
            requiredInterests: ["technology", "creative_arts"],
            estimatedSalary: SalaryRange(min: 75_000, max: 150_000),
            educationLevel: .bachelors,
            icon: "chevron.left.forwardslash.chevron.right",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Mobile Developer",
            category: "technology",
            subcategory: "Software Development",
            description: "Mobile developers create applications for smartphones and tablets, building apps for iOS and Android platforms that millions of people use every day. They focus on touch interfaces, device features like cameras and GPS, and making apps feel fast and intuitive.",
            pathway: nil,
            requiredInterests: ["technology", "creative_arts"],
            estimatedSalary: SalaryRange(min: 75_000, max: 145_000),
            educationLevel: .bachelors,
            icon: "iphone",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Embedded Systems Developer",
            category: "technology",
            subcategory: "Software Development",
            description: "Embedded systems developers write software that runs on hardware devices like medical equipment, cars, and smart appliances rather than on traditional computers. They work very close to the hardware, optimizing code for devices with limited memory and processing power.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 80_000, max: 150_000),
            educationLevel: .bachelors,
            icon: "cpu.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Blockchain Developer",
            category: "technology",
            subcategory: "Software Development",
            description: "Blockchain developers build decentralized applications and smart contracts that run on distributed ledger networks like Ethereum. They work on cryptocurrency platforms, digital ownership systems, and transparent record-keeping solutions.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 90_000, max: 170_000),
            educationLevel: .bachelors,
            icon: "link.circle.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "QA Engineer",
            category: "technology",
            subcategory: "Software Development",
            description: "Quality assurance engineers test software to find bugs and ensure that apps work correctly before they reach users. They write automated tests, design test cases, and work closely with developers to catch problems early in the development process.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 60_000, max: 120_000),
            educationLevel: .bachelors,
            icon: "checkmark.shield.fill",
            color: "#3498DB"
        ),

        // MARK: - IT & Infrastructure

        CareerPath(
            title: "Database Administrator",
            category: "technology",
            subcategory: "IT & Infrastructure",
            description: "Database administrators organize, secure, and maintain the databases that store a company's most important information, from customer records to financial data. They ensure data is backed up, quickly accessible, and protected from corruption or unauthorized access.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 70_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "cylinder.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Systems Administrator",
            category: "technology",
            subcategory: "IT & Infrastructure",
            description: "Systems administrators install, configure, and maintain the computers and servers that keep an organization's technology running smoothly. They handle software updates, user accounts, security patches, and troubleshooting to minimize downtime.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "desktopcomputer",
            color: "#3498DB"
        ),

        CareerPath(
            title: "IT Support Specialist",
            category: "technology",
            subcategory: "IT & Infrastructure",
            description: "IT support specialists help employees and customers solve technical problems with computers, software, and devices, serving as the first line of help for technology issues. They diagnose hardware failures, reset systems, and guide users through troubleshooting steps.",
            pathway: nil,
            requiredInterests: ["technology"],
            estimatedSalary: SalaryRange(min: 40_000, max: 75_000),
            educationLevel: .someCollege,
            icon: "questionmark.circle.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Network Administrator",
            category: "technology",
            subcategory: "IT & Infrastructure",
            description: "Network administrators design and manage the computer networks that connect devices within an organization, ensuring reliable and secure communication. They configure routers, switches, and firewalls, and monitor traffic to prevent outages or breaches.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 65_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "network",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Help Desk Technician",
            category: "technology",
            subcategory: "IT & Infrastructure",
            description: "Help desk technicians provide front-line technical support to users experiencing problems with hardware, software, or network connectivity. They log support tickets, walk users through solutions, and escalate complex issues to senior IT staff.",
            pathway: nil,
            requiredInterests: ["technology"],
            estimatedSalary: SalaryRange(min: 35_000, max: 65_000),
            educationLevel: .certification,
            icon: "person.fill.questionmark",
            color: "#3498DB"
        ),

        CareerPath(
            title: "IT Manager",
            category: "technology",
            subcategory: "IT & Infrastructure",
            description: "IT managers lead teams of technology professionals, overseeing an organization's entire technology strategy, infrastructure, and budget. They translate business needs into technology solutions and ensure the IT department delivers reliable services to the whole organization.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 90_000, max: 160_000),
            educationLevel: .bachelors,
            icon: "person.3.fill",
            color: "#3498DB"
        ),

        // MARK: - Cybersecurity

        CareerPath(
            title: "Cybersecurity Analyst",
            category: "technology",
            subcategory: "Cybersecurity",
            description: "Cybersecurity analysts monitor computer networks for suspicious activity and respond to security incidents that could expose sensitive data. They investigate alerts, analyze threats, and recommend improvements to keep organizations safe from hackers.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 70_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "lock.shield.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Penetration Tester",
            category: "technology",
            subcategory: "Cybersecurity",
            description: "Penetration testers are ethical hackers hired by organizations to deliberately try to break into their systems and find vulnerabilities before real attackers do. They write detailed reports on what they discovered and recommend fixes to strengthen security.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 80_000, max: 150_000),
            educationLevel: .bachelors,
            icon: "bolt.shield.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Security Engineer",
            category: "technology",
            subcategory: "Cybersecurity",
            description: "Security engineers design and build the protective systems that defend an organization's software and infrastructure from cyberattacks. They create firewalls, encryption systems, and secure coding practices that make it much harder for attackers to succeed.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 95_000, max: 165_000),
            educationLevel: .bachelors,
            icon: "shield.lefthalf.filled",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Chief Information Security Officer",
            category: "technology",
            subcategory: "Cybersecurity",
            description: "The Chief Information Security Officer (CISO) is the executive responsible for an entire organization's cybersecurity strategy, policies, and team. They report to top leadership, manage large security budgets, and make high-stakes decisions about protecting the company from digital threats.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 150_000, max: 300_000),
            educationLevel: .masters,
            icon: "lock.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Security Consultant",
            category: "technology",
            subcategory: "Cybersecurity",
            description: "Security consultants are independent experts who advise businesses on how to improve their cybersecurity posture, often working with multiple clients across different industries. They assess current defenses, identify gaps, and create customized plans to reduce risk.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 85_000, max: 160_000),
            educationLevel: .bachelors,
            icon: "person.badge.shield.checkmark.fill",
            color: "#3498DB"
        ),

        // MARK: - AI & Data Science

        CareerPath(
            title: "AI Engineer",
            category: "technology",
            subcategory: "AI & Data Science",
            description: "AI engineers build and deploy artificial intelligence systems that can learn from data, recognize patterns, and make decisions without being explicitly programmed for every situation. They work on projects ranging from chatbots to self-driving car software.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 110_000, max: 200_000),
            educationLevel: .masters,
            icon: "brain.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Machine Learning Engineer",
            category: "technology",
            subcategory: "AI & Data Science",
            description: "Machine learning engineers design and train computer models that can improve their own performance by analyzing large amounts of data. Their work powers recommendation engines, fraud detection, image recognition, and many other intelligent features in modern apps.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 105_000, max: 195_000),
            educationLevel: .masters,
            icon: "cpu.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "NLP Specialist",
            category: "technology",
            subcategory: "AI & Data Science",
            description: "Natural Language Processing specialists build AI systems that understand and generate human language, powering technologies like voice assistants, translation tools, and sentiment analysis. They combine linguistics and machine learning to help computers communicate more naturally.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 100_000, max: 185_000),
            educationLevel: .masters,
            icon: "text.bubble.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Data Engineer",
            category: "technology",
            subcategory: "AI & Data Science",
            description: "Data engineers build the pipelines and infrastructure that collect, store, and process large amounts of data so that analysts and scientists can use it effectively. They design systems that move data reliably from many sources into organized storage at high speed.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 90_000, max: 160_000),
            educationLevel: .bachelors,
            icon: "arrow.triangle.branch",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Data Architect",
            category: "technology",
            subcategory: "AI & Data Science",
            description: "Data architects design the overall structure of how an organization's data is stored, organized, and accessed across different systems. They create the blueprints that ensure data flows smoothly and securely from collection to analysis.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 110_000, max: 185_000),
            educationLevel: .masters,
            icon: "square.3.layers.3d.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Business Intelligence Analyst",
            category: "technology",
            subcategory: "AI & Data Science",
            description: "Business intelligence analysts turn large sets of company data into charts, dashboards, and reports that help leaders make smarter decisions. They combine technical data skills with business knowledge to answer questions like which products are selling best or where costs can be cut.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 70_000, max: 125_000),
            educationLevel: .bachelors,
            icon: "chart.bar.fill",
            color: "#3498DB"
        ),

        // MARK: - Product & Design

        CareerPath(
            title: "UX Designer",
            category: "technology",
            subcategory: "Product & Design",
            description: "UX designers plan and design digital experiences that are easy, enjoyable, and accessible for users, focusing on how every screen and interaction feels. They research user behavior, create wireframes, and collaborate with developers to bring intuitive products to life.",
            pathway: nil,
            requiredInterests: ["technology", "creative_arts"],
            estimatedSalary: SalaryRange(min: 70_000, max: 135_000),
            educationLevel: .bachelors,
            icon: "pencil.and.ruler.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "UX Researcher",
            category: "technology",
            subcategory: "Product & Design",
            description: "UX researchers study how real people use software products through interviews, surveys, and usability testing to uncover pain points and opportunities for improvement. Their findings guide design and development decisions so that products better meet users' actual needs.",
            pathway: nil,
            requiredInterests: ["technology", "science_research"],
            estimatedSalary: SalaryRange(min: 75_000, max: 140_000),
            educationLevel: .bachelors,
            icon: "magnifyingglass.circle.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Product Manager",
            category: "technology",
            subcategory: "Product & Design",
            description: "Product managers define the vision and strategy for a software product, deciding what features to build and when, balancing user needs with business goals and technical constraints. They work across design, engineering, and marketing teams to bring products from idea to launch.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 95_000, max: 175_000),
            educationLevel: .bachelors,
            icon: "map.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Technical Product Manager",
            category: "technology",
            subcategory: "Product & Design",
            description: "Technical product managers combine the strategic thinking of a product manager with deep engineering knowledge, making them especially effective at leading products with complex technical requirements. They can speak the language of developers while still keeping the focus on user value and business outcomes.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 110_000, max: 190_000),
            educationLevel: .bachelors,
            icon: "gearshape.2.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Technical Writer",
            category: "technology",
            subcategory: "Product & Design",
            description: "Technical writers create clear documentation—like user guides, API references, and help articles—that explains how software and technology products work. They translate complex technical information into plain language that both beginners and experts can understand and use.",
            pathway: nil,
            requiredInterests: ["technology", "creative_arts"],
            estimatedSalary: SalaryRange(min: 60_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "doc.text.fill",
            color: "#3498DB"
        ),

        // MARK: - DevOps & Cloud

        CareerPath(
            title: "DevOps Engineer",
            category: "technology",
            subcategory: "DevOps & Cloud",
            description: "DevOps engineers bridge software development and IT operations, automating the processes that build, test, and deploy code so that new features can be released quickly and reliably. They manage continuous integration pipelines and work to eliminate manual steps that slow teams down.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 95_000, max: 165_000),
            educationLevel: .bachelors,
            icon: "arrow.triangle.2.circlepath.circle.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Cloud Architect",
            category: "technology",
            subcategory: "DevOps & Cloud",
            description: "Cloud architects design the entire cloud computing environment for an organization, choosing services from providers like AWS or Azure and structuring them for performance, cost efficiency, and security. They create the blueprints that other engineers follow to build and maintain cloud systems.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 130_000, max: 220_000),
            educationLevel: .bachelors,
            icon: "cloud.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Site Reliability Engineer",
            category: "technology",
            subcategory: "DevOps & Cloud",
            description: "Site reliability engineers apply software engineering principles to keep large-scale systems running smoothly and prevent outages that could affect thousands or millions of users. They build monitoring tools, automate responses to incidents, and set standards for system reliability.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 110_000, max: 195_000),
            educationLevel: .bachelors,
            icon: "waveform.path.ecg",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Platform Engineer",
            category: "technology",
            subcategory: "DevOps & Cloud",
            description: "Platform engineers build and maintain the internal developer tools and infrastructure platforms that other engineering teams use to build, test, and deploy their own software. Their work makes the entire engineering organization more productive by standardizing how software is built and run.",
            pathway: nil,
            requiredInterests: ["technology", "engineering_building"],
            estimatedSalary: SalaryRange(min: 100_000, max: 175_000),
            educationLevel: .bachelors,
            icon: "square.stack.3d.up.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Release Manager",
            category: "technology",
            subcategory: "DevOps & Cloud",
            description: "Release managers coordinate the planning, scheduling, and deployment of software releases to ensure new features and fixes reach users smoothly and without disruption. They track dependencies between teams, manage release calendars, and oversee the final approval process before code goes live.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 85_000, max: 145_000),
            educationLevel: .bachelors,
            icon: "shippingbox.fill",
            color: "#3498DB"
        ),

        CareerPath(
            title: "Solutions Architect",
            category: "technology",
            subcategory: "DevOps & Cloud",
            description: "Solutions architects design comprehensive technology systems that solve specific business problems, often working with clients to understand their needs and then designing systems using cloud services, software, and infrastructure. They serve as the technical authority on major projects from initial concept through to implementation.",
            pathway: nil,
            requiredInterests: ["technology", "business_entrepreneurship", "engineering_building"],
            estimatedSalary: SalaryRange(min: 120_000, max: 210_000),
            educationLevel: .bachelors,
            icon: "building.2.fill",
            color: "#3498DB"
        )
    ]
}
