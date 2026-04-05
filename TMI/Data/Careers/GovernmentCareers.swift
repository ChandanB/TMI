//
//  GovernmentCareers.swift
//  TMI
//
//  Career data for Government & Public Service careers
//

import Foundation

enum GovernmentCareers {
    static let all: [CareerPath] = [

        // MARK: - Public Administration

        CareerPath(
            title: "City Manager",
            category: "government",
            subcategory: "Public Administration",
            description: "City managers oversee the day-to-day operations of a city or town, managing departments and implementing policies set by elected officials. They work to make communities better places to live, work, and grow.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 75000, max: 180000),
            educationLevel: .masters,
            icon: "building.2.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Public Administrator",
            category: "government",
            subcategory: "Public Administration",
            description: "Public administrators manage government programs and services that affect everyday life, from roads and schools to healthcare and housing. This career combines leadership, problem-solving, and a passion for serving the community.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 55000, max: 120000),
            educationLevel: .masters,
            icon: "person.2.badge.gearshape.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Government Affairs Director",
            category: "government",
            subcategory: "Public Administration",
            description: "Government affairs directors represent organizations before government bodies, helping shape laws and regulations that affect their industry. They build relationships with lawmakers and communicate complex issues in clear, compelling ways.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 90000, max: 200000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Lobbyist",
            category: "government",
            subcategory: "Public Administration",
            description: "Lobbyists advocate for specific organizations or causes by meeting with lawmakers and influencing legislation. They research policy issues, write reports, and use persuasive communication to advance their clients' interests.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 70000, max: 175000),
            educationLevel: .bachelors,
            icon: "person.fill.questionmark",
            color: "#34495E"
        ),

        CareerPath(
            title: "Government Auditor",
            category: "government",
            subcategory: "Public Administration",
            description: "Government auditors examine how public funds are spent to ensure money is used properly and efficiently. They help prevent waste, fraud, and abuse in government programs, making sure taxpayer dollars go where they are supposed to.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55000, max: 130000),
            educationLevel: .bachelors,
            icon: "doc.text.magnifyingglass",
            color: "#34495E"
        ),

        // MARK: - Policy & Diplomacy

        CareerPath(
            title: "Political Scientist",
            category: "government",
            subcategory: "Policy & Diplomacy",
            description: "Political scientists study how governments work, how people vote, and why countries make the decisions they do. They conduct research and analyze data to understand political behavior and help leaders make better decisions.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 65000, max: 150000),
            educationLevel: .doctorate,
            icon: "globe.americas.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Diplomat",
            category: "government",
            subcategory: "Policy & Diplomacy",
            description: "Diplomats represent their country abroad, working to build peaceful relationships between nations through negotiation and cooperation. They live and work overseas, participating in international meetings and helping citizens traveling abroad.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 60000, max: 160000),
            educationLevel: .bachelors,
            icon: "globe",
            color: "#34495E"
        ),

        CareerPath(
            title: "Foreign Service Officer",
            category: "government",
            subcategory: "Policy & Diplomacy",
            description: "Foreign service officers work at U.S. embassies and consulates around the world to advance American interests and assist U.S. citizens abroad. They handle everything from issuing visas to reporting on political events in other countries.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 55000, max: 140000),
            educationLevel: .bachelors,
            icon: "flag.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Policy Analyst",
            category: "government",
            subcategory: "Policy & Diplomacy",
            description: "Policy analysts research complex social, economic, and political issues to help governments and organizations make informed decisions. They gather data, evaluate programs, and write detailed reports that recommend solutions to public problems.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 55000, max: 120000),
            educationLevel: .masters,
            icon: "chart.bar.doc.horizontal.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Legislative Aide",
            category: "government",
            subcategory: "Policy & Diplomacy",
            description: "Legislative aides support elected officials by researching issues, writing speeches, and helping communicate with constituents. It is a great entry-level career for those interested in how laws are made and how government works.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 38000, max: 75000),
            educationLevel: .bachelors,
            icon: "doc.richtext.fill",
            color: "#34495E"
        ),

        // MARK: - Intelligence & Security

        CareerPath(
            title: "Intelligence Analyst",
            category: "government",
            subcategory: "Intelligence & Security",
            description: "Intelligence analysts gather and interpret information from many sources to identify threats and help protect national security. They work for agencies like the CIA or NSA, using critical thinking and technology to uncover hidden patterns.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 65000, max: 145000),
            educationLevel: .bachelors,
            icon: "shield.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "FBI Agent",
            category: "government",
            subcategory: "Intelligence & Security",
            description: "FBI agents investigate federal crimes such as terrorism, cybercrime, and organized crime to keep communities safe. They conduct surveillance, interview witnesses, and build cases that are presented in federal court.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 65000, max: 155000),
            educationLevel: .bachelors,
            icon: "person.badge.shield.checkmark.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Customs Officer",
            category: "government",
            subcategory: "Intelligence & Security",
            description: "Customs officers inspect people and goods entering the country to enforce trade laws and prevent smuggling. They work at airports, seaports, and border crossings, using sharp attention to detail to keep the country safe.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 45000, max: 95000),
            educationLevel: .someCollege,
            icon: "checkmark.seal.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "TSA Agent",
            category: "government",
            subcategory: "Intelligence & Security",
            description: "TSA agents screen passengers and baggage at airports to prevent dangerous items from getting on aircraft. They use specialized equipment and training to identify threats while helping millions of travelers reach their destinations safely.",
            pathway: nil,
            requiredInterests: ["law_government"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .highSchool,
            icon: "airplane.arrival",
            color: "#34495E"
        ),

        CareerPath(
            title: "Border Patrol Agent",
            category: "government",
            subcategory: "Intelligence & Security",
            description: "Border patrol agents monitor and secure the nation's borders to prevent illegal crossings and stop the smuggling of drugs or other dangerous materials. They work outdoors in challenging terrain and are trained in law enforcement techniques.",
            pathway: nil,
            requiredInterests: ["law_government"],
            estimatedSalary: SalaryRange(min: 50000, max: 100000),
            educationLevel: .someCollege,
            icon: "binoculars.fill",
            color: "#34495E"
        ),

        // MARK: - Public Service

        CareerPath(
            title: "Mayor",
            category: "government",
            subcategory: "Public Service",
            description: "Mayors are the elected leaders of cities and towns, making key decisions about public services, budgets, and community development. They work closely with residents, businesses, and other government officials to improve life in their communities.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 250000),
            educationLevel: .varies,
            icon: "building.2.crop.circle.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "City Council Member",
            category: "government",
            subcategory: "Public Service",
            description: "City council members are elected representatives who vote on local laws, budgets, and policies that affect their neighborhoods. They attend public meetings, hear from residents, and work to solve problems in their communities.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 20000, max: 100000),
            educationLevel: .varies,
            icon: "person.3.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Public Health Administrator",
            category: "government",
            subcategory: "Public Service",
            description: "Public health administrators lead programs and departments that protect and improve the health of communities. They manage staff, oversee budgets, and develop strategies to address health challenges like disease prevention and wellness education.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 65000, max: 145000),
            educationLevel: .masters,
            icon: "cross.case.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Emergency Management Director",
            category: "government",
            subcategory: "Public Service",
            description: "Emergency management directors plan and coordinate responses to natural disasters, terrorist attacks, and other crises. They work with local governments, emergency services, and the public to prepare communities and manage recovery after disasters.",
            pathway: nil,
            requiredInterests: ["law_government", "technology"],
            estimatedSalary: SalaryRange(min: 60000, max: 140000),
            educationLevel: .bachelors,
            icon: "exclamationmark.triangle.fill",
            color: "#34495E"
        ),

        CareerPath(
            title: "Census Worker",
            category: "government",
            subcategory: "Public Service",
            description: "Census workers collect important population data that helps governments plan schools, roads, and services for communities. They interview residents, verify information, and ensure that every person is counted accurately.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 30000, max: 60000),
            educationLevel: .highSchool,
            icon: "person.crop.rectangle.stack.fill",
            color: "#34495E"
        )
    ]
}
