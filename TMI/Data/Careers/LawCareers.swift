//
//  LawCareers.swift
//  TMI
//
//  Career data for the Law category (25 careers)
//

import Foundation

enum LawCareers {
    static let all: [CareerPath] = [

        // MARK: - Legal Practice

        CareerPath(
            title: "Lawyer",
            category: "law",
            subcategory: "Legal Practice",
            description: "Lawyers represent clients in legal matters, giving advice on their rights and obligations and arguing their cases in court. They research laws, draft legal documents, and work to achieve the best possible outcome for the people they represent.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 75_000, max: 210_000),
            educationLevel: .doctorate,
            icon: "scale.3d",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Corporate Attorney",
            category: "law",
            subcategory: "Legal Practice",
            description: "Corporate attorneys advise businesses on legal matters such as contracts, mergers, regulations, and employment law to help companies operate within the law. They often work for law firms or directly inside large companies as in-house counsel.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 100_000, max: 250_000),
            educationLevel: .doctorate,
            icon: "building.2.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Criminal Defense Attorney",
            category: "law",
            subcategory: "Legal Practice",
            description: "Criminal defense attorneys represent people accused of crimes, making sure their rights are protected throughout the legal process. They investigate cases, challenge evidence, and argue on behalf of their clients in court.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 65_000, max: 175_000),
            educationLevel: .doctorate,
            icon: "person.badge.shield.checkmark.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Public Defender",
            category: "law",
            subcategory: "Legal Practice",
            description: "Public defenders are government-employed lawyers who represent people accused of crimes who cannot afford to hire a private attorney. They are committed to ensuring every person gets a fair trial regardless of their financial situation.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 52_000, max: 95_000),
            educationLevel: .doctorate,
            icon: "shield.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Prosecutor",
            category: "law",
            subcategory: "Legal Practice",
            description: "Prosecutors are government attorneys who bring criminal charges against people accused of breaking the law and present the case in court on behalf of the public. They work closely with law enforcement to seek justice for crime victims.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 55_000, max: 130_000),
            educationLevel: .doctorate,
            icon: "building.columns.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Immigration Lawyer",
            category: "law",
            subcategory: "Legal Practice",
            description: "Immigration lawyers help individuals and families navigate the complex process of obtaining visas, permanent residency, and citizenship. They advocate for clients facing deportation and work to reunite families separated by borders.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 60_000, max: 160_000),
            educationLevel: .doctorate,
            icon: "globe.americas.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Patent Attorney",
            category: "law",
            subcategory: "Legal Practice",
            description: "Patent attorneys help inventors and companies protect their new inventions and ideas by applying for patents with the government. They need both legal training and a strong understanding of science or technology to evaluate and defend innovations.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship", "science_research"],
            estimatedSalary: SalaryRange(min: 120_000, max: 280_000),
            educationLevel: .doctorate,
            icon: "lightbulb.fill",
            color: "#7F8C8D"
        ),

        // MARK: - Criminal Justice

        CareerPath(
            title: "Police Officer",
            category: "law",
            subcategory: "Criminal Justice",
            description: "Police officers protect communities by enforcing laws, responding to emergencies, investigating crimes, and building relationships with the public. They patrol neighborhoods, assist people in need, and work to keep their communities safe.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 45_000, max: 90_000),
            educationLevel: .someCollege,
            icon: "shield.lefthalf.filled",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Detective",
            category: "law",
            subcategory: "Criminal Justice",
            description: "Detectives investigate serious crimes by gathering evidence, interviewing witnesses, and working to identify and arrest suspects. They use critical thinking, forensic knowledge, and persistence to solve complex cases.",
            pathway: nil,
            requiredInterests: ["law_government", "science_research"],
            estimatedSalary: SalaryRange(min: 55_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "magnifyingglass",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Forensic Scientist",
            category: "law",
            subcategory: "Criminal Justice",
            description: "Forensic scientists analyze physical evidence from crime scenes—such as DNA, fingerprints, and chemical substances—to help investigators and courts understand what happened. Their scientific findings can be the key to solving a case.",
            pathway: nil,
            requiredInterests: ["law_government", "science_research"],
            estimatedSalary: SalaryRange(min: 50_000, max: 100_000),
            educationLevel: .bachelors,
            icon: "flask.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Crime Scene Investigator",
            category: "law",
            subcategory: "Criminal Justice",
            description: "Crime scene investigators collect and document physical evidence at the scenes of crimes to help solve cases and support prosecutions. They carefully photograph, catalog, and preserve evidence like fingerprints, fibers, and biological samples.",
            pathway: nil,
            requiredInterests: ["law_government", "science_research"],
            estimatedSalary: SalaryRange(min: 45_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "camera.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Corrections Officer",
            category: "law",
            subcategory: "Criminal Justice",
            description: "Corrections officers oversee individuals who have been arrested or sentenced to serve time in jails or prisons, maintaining safety and order in these facilities. They also help rehabilitate incarcerated people to prepare them for reentry into society.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 38_000, max: 75_000),
            educationLevel: .highSchool,
            icon: "lock.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Probation Officer",
            category: "law",
            subcategory: "Criminal Justice",
            description: "Probation officers supervise people who have been convicted of crimes but are serving their sentences in the community rather than in prison. They monitor compliance with court-ordered conditions and connect clients with services like job training and counseling.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .bachelors,
            icon: "person.badge.clock.fill",
            color: "#7F8C8D"
        ),

        // MARK: - Compliance & Regulation

        CareerPath(
            title: "Compliance Officer",
            category: "law",
            subcategory: "Compliance & Regulation",
            description: "Compliance officers ensure that companies follow all relevant laws, regulations, and internal policies to avoid legal problems and protect their reputation. They review business practices, train employees, and investigate potential violations.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "checkmark.seal.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Regulatory Analyst",
            category: "law",
            subcategory: "Compliance & Regulation",
            description: "Regulatory analysts study and interpret government rules and regulations to help organizations understand what they are required to do. They research policy changes, prepare reports, and advise on how new rules will affect operations.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "doc.text.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Privacy Officer",
            category: "law",
            subcategory: "Compliance & Regulation",
            description: "Privacy officers protect individuals' personal information by ensuring organizations comply with data privacy laws like HIPAA and GDPR. They develop privacy policies, train staff, and respond to data breaches.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 70_000, max: 150_000),
            educationLevel: .bachelors,
            icon: "lock.shield.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Environmental Lawyer",
            category: "law",
            subcategory: "Compliance & Regulation",
            description: "Environmental lawyers represent clients in cases involving pollution, land use, wildlife protection, and other environmental issues. They work for governments, nonprofits, or corporations to shape and enforce laws that protect natural resources.",
            pathway: nil,
            requiredInterests: ["law_government", "science_research"],
            estimatedSalary: SalaryRange(min: 65_000, max: 160_000),
            educationLevel: .doctorate,
            icon: "leaf.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Family Law Attorney",
            category: "law",
            subcategory: "Compliance & Regulation",
            description: "Family law attorneys handle legal matters that affect families, such as divorce, child custody, adoption, and domestic violence cases. They advocate for their clients during some of the most emotional and personal moments in their lives.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 55_000, max: 145_000),
            educationLevel: .doctorate,
            icon: "house.fill",
            color: "#7F8C8D"
        ),

        // MARK: - Court & Support

        CareerPath(
            title: "Judge",
            category: "law",
            subcategory: "Court & Support",
            description: "Judges oversee court proceedings, ensure that trials are conducted fairly, and make rulings on legal questions based on the law and evidence presented. They may be elected or appointed and serve as neutral decision-makers in the justice system.",
            pathway: nil,
            requiredInterests: ["law_government"],
            estimatedSalary: SalaryRange(min: 80_000, max: 220_000),
            educationLevel: .doctorate,
            icon: "building.columns.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Court Reporter",
            category: "law",
            subcategory: "Court & Support",
            description: "Court reporters create word-for-word transcripts of court proceedings, depositions, and other legal events using specialized stenography equipment. Their official records are essential for appeals and future legal reference.",
            pathway: nil,
            requiredInterests: ["law_government"],
            estimatedSalary: SalaryRange(min: 45_000, max: 90_000),
            educationLevel: .vocational,
            icon: "keyboard.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Paralegal",
            category: "law",
            subcategory: "Court & Support",
            description: "Paralegals assist lawyers by conducting legal research, drafting documents, organizing case files, and communicating with clients. They play a vital support role that allows attorneys to focus on higher-level legal strategy.",
            pathway: nil,
            requiredInterests: ["law_government"],
            estimatedSalary: SalaryRange(min: 40_000, max: 80_000),
            educationLevel: .someCollege,
            icon: "folder.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Legal Secretary",
            category: "law",
            subcategory: "Court & Support",
            description: "Legal secretaries handle the administrative work of a law office, including scheduling, drafting correspondence, filing court documents, and managing client communications. Their organizational skills keep legal teams running smoothly.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 35_000, max: 65_000),
            educationLevel: .someCollege,
            icon: "tray.fill",
            color: "#7F8C8D"
        ),

        // MARK: - Dispute Resolution

        CareerPath(
            title: "Mediator",
            category: "law",
            subcategory: "Dispute Resolution",
            description: "Mediators are neutral professionals who help people in conflict reach a mutually agreeable solution without going to court. They facilitate structured conversations in areas like family disputes, workplace conflicts, and contract disagreements.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 48_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "person.2.fill",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Arbitrator",
            category: "law",
            subcategory: "Dispute Resolution",
            description: "Arbitrators are independent decision-makers who hear both sides of a dispute and issue a binding or non-binding resolution, acting as a private alternative to a courtroom trial. They are often used in business and labor disputes.",
            pathway: nil,
            requiredInterests: ["law_government", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60_000, max: 140_000),
            educationLevel: .bachelors,
            icon: "scale.3d",
            color: "#7F8C8D"
        ),

        CareerPath(
            title: "Legal Aid Worker",
            category: "law",
            subcategory: "Dispute Resolution",
            description: "Legal aid workers provide free or low-cost legal assistance to people who cannot afford a private attorney, helping them access justice in areas like housing, family law, and immigration. They combine legal knowledge with a deep commitment to social equality.",
            pathway: nil,
            requiredInterests: ["law_government", "social_services"],
            estimatedSalary: SalaryRange(min: 38_000, max: 75_000),
            educationLevel: .bachelors,
            icon: "hands.and.sparkles.fill",
            color: "#7F8C8D"
        )
    ]
}
