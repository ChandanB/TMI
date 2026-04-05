//
//  CareerCategory.swift
//  TMI
//
//  Type-safe career categories with display metadata
//

import Foundation

enum CareerCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case agriculture = "agriculture"
    case architecture = "architecture"
    case artsEntertainment = "arts_entertainment"
    case business = "business"
    case communications = "communications"
    case education = "education"
    case engineering = "engineering"
    case environment = "environment"
    case government = "government"
    case healthcare = "healthcare"
    case hospitality = "hospitality"
    case law = "law"
    case manufacturing = "manufacturing"
    case military = "military"
    case science = "science"
    case socialServices = "social_services"
    case sports = "sports"
    case technology = "technology"
    case trades = "trades"
    case transportation = "transportation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .agriculture: return "Agriculture & Natural Resources"
        case .architecture: return "Architecture & Design"
        case .artsEntertainment: return "Arts & Entertainment"
        case .business: return "Business & Finance"
        case .communications: return "Communications & Media"
        case .education: return "Education & Training"
        case .engineering: return "Engineering"
        case .environment: return "Environment & Sustainability"
        case .government: return "Government & Public Administration"
        case .healthcare: return "Healthcare & Medicine"
        case .hospitality: return "Hospitality & Tourism"
        case .law: return "Law & Criminal Justice"
        case .manufacturing: return "Manufacturing & Production"
        case .military: return "Military & Defense"
        case .science: return "Science & Research"
        case .socialServices: return "Social & Community Services"
        case .sports: return "Sports & Recreation"
        case .technology: return "Technology & Computing"
        case .trades: return "Skilled Trades"
        case .transportation: return "Transportation & Logistics"
        }
    }

    var icon: String {
        switch self {
        case .agriculture: return "leaf.fill"
        case .architecture: return "building.columns.fill"
        case .artsEntertainment: return "paintpalette.fill"
        case .business: return "briefcase.fill"
        case .communications: return "megaphone.fill"
        case .education: return "book.fill"
        case .engineering: return "gearshape.2.fill"
        case .environment: return "globe.americas.fill"
        case .government: return "building.2.fill"
        case .healthcare: return "cross.case.fill"
        case .hospitality: return "fork.knife"
        case .law: return "scale.3d"
        case .manufacturing: return "hammer.fill"
        case .military: return "shield.fill"
        case .science: return "atom"
        case .socialServices: return "hands.sparkles.fill"
        case .sports: return "sportscourt.fill"
        case .technology: return "desktopcomputer"
        case .trades: return "wrench.and.screwdriver.fill"
        case .transportation: return "airplane"
        }
    }

    var color: String {
        switch self {
        case .agriculture: return "#27AE60"
        case .architecture: return "#8E44AD"
        case .artsEntertainment: return "#E74C3C"
        case .business: return "#2ECC71"
        case .communications: return "#9B59B6"
        case .education: return "#E67E22"
        case .engineering: return "#2C3E50"
        case .environment: return "#1ABC9C"
        case .government: return "#34495E"
        case .healthcare: return "#16A085"
        case .hospitality: return "#D35400"
        case .law: return "#7F8C8D"
        case .manufacturing: return "#95A5A6"
        case .military: return "#2C3E50"
        case .science: return "#2980B9"
        case .socialServices: return "#1ABC9C"
        case .sports: return "#F39C12"
        case .technology: return "#3498DB"
        case .trades: return "#E67E22"
        case .transportation: return "#5D6D7E"
        }
    }

    var growthPotential: String {
        switch self {
        case .technology: return "High - technology careers are growing rapidly with strong demand"
        case .healthcare: return "High - healthcare is an expanding field with aging population"
        case .business: return "Moderate to High - diverse opportunities across all industries"
        case .artsEntertainment: return "Moderate - creative fields can be competitive but rewarding"
        case .education: return "Stable - consistent demand for educators"
        case .socialServices: return "Moderate - growing awareness of mental health and social needs"
        case .sports: return "Moderate - competitive field with diverse industry opportunities"
        case .communications: return "High - digital media and content creation is booming"
        case .engineering: return "High - strong demand across civil, mechanical, and software"
        case .science: return "Moderate to High - research and innovation drive growth"
        case .law: return "Moderate - steady demand for legal professionals"
        case .government: return "Stable - consistent need for public servants"
        case .agriculture: return "Stable - essential industry with growing tech integration"
        case .architecture: return "Moderate - tied to construction and development cycles"
        case .environment: return "High - climate concerns driving rapid expansion"
        case .hospitality: return "Moderate - rebounding strongly with travel and events"
        case .manufacturing: return "Moderate - automation creating new skilled roles"
        case .military: return "Stable - consistent need for defense personnel"
        case .trades: return "High - skilled trades face significant worker shortages"
        case .transportation: return "Moderate to High - logistics and delivery demand growing"
        }
    }

    var industryOutlook: String {
        switch self {
        case .technology: return "Excellent long-term outlook with continuous innovation"
        case .healthcare: return "Strong outlook due to aging demographics and health focus"
        case .business: return "Stable with opportunities in emerging markets"
        case .artsEntertainment: return "Evolving with digital transformation and new platforms"
        case .education: return "Stable with ongoing need for qualified educators"
        case .socialServices: return "Growing demand for social support services"
        case .sports: return "Steady with opportunities in coaching, training, and analytics"
        case .communications: return "Rapidly growing with podcast and streaming boom"
        case .engineering: return "Strong demand driven by infrastructure and technology needs"
        case .science: return "Growing investment in research and development"
        case .law: return "Steady demand with evolution toward technology-assisted practice"
        case .government: return "Stable employment with good benefits and job security"
        case .agriculture: return "Evolving with precision agriculture and sustainability focus"
        case .architecture: return "Tied to economic cycles but growing with green building"
        case .environment: return "Rapidly expanding due to climate policy and corporate sustainability"
        case .hospitality: return "Strong rebound with experience-driven consumer spending"
        case .manufacturing: return "Transforming with automation, creating higher-skilled positions"
        case .military: return "Consistent with growing technology integration"
        case .trades: return "Excellent outlook due to retiring workforce and housing demand"
        case .transportation: return "Growing with e-commerce and supply chain complexity"
        }
    }

    var outlookAndGrowth: (String, Double) {
        switch self {
        case .technology: return ("Excellent long-term outlook with continuous innovation and strong demand.", 0.22)
        case .healthcare: return ("Strong outlook due to aging demographics and expanding healthcare needs.", 0.16)
        case .business: return ("Stable with opportunities in emerging markets and digital commerce.", 0.10)
        case .artsEntertainment: return ("Evolving with digital transformation and new content platforms.", 0.08)
        case .education: return ("Stable with ongoing need for qualified educators.", 0.05)
        case .socialServices: return ("Growing demand for social support and mental health services.", 0.12)
        case .sports: return ("Steady with opportunities in coaching, training, and sports analytics.", 0.07)
        case .communications: return ("Rapidly growing with the podcast and streaming content boom.", 0.18)
        case .engineering: return ("Strong demand driven by infrastructure and technology investment.", 0.14)
        case .science: return ("Growing investment in research across all disciplines.", 0.11)
        case .law: return ("Steady demand with increasing specialization opportunities.", 0.06)
        case .government: return ("Stable employment with consistent public sector demand.", 0.04)
        case .agriculture: return ("Essential industry evolving with technology and sustainability.", 0.05)
        case .architecture: return ("Moderate growth tied to construction and green building trends.", 0.07)
        case .environment: return ("Rapidly expanding due to climate awareness and policy.", 0.15)
        case .hospitality: return ("Strong rebound driven by experience-focused consumer spending.", 0.09)
        case .manufacturing: return ("Transforming with automation creating higher-skilled positions.", 0.06)
        case .military: return ("Consistent need with growing technology integration.", 0.03)
        case .trades: return ("Excellent outlook due to skilled worker shortages and housing demand.", 0.13)
        case .transportation: return ("Growing with e-commerce logistics and infrastructure investment.", 0.10)
        }
    }

    var baseSkills: [String] {
        switch self {
        case .technology: return ["Problem Solving", "Programming", "Critical Thinking", "Collaboration"]
        case .healthcare: return ["Patient Care", "Communication", "Empathy", "Medical Knowledge"]
        case .business: return ["Strategic Planning", "Leadership", "Communication", "Analytics"]
        case .artsEntertainment: return ["Creativity", "Visual Communication", "Attention to Detail", "Design Thinking"]
        case .education: return ["Communication", "Patience", "Curriculum Development", "Adaptability"]
        case .socialServices: return ["Empathy", "Active Listening", "Case Management", "Advocacy"]
        case .sports: return ["Physical Fitness", "Teamwork", "Coaching", "Performance Analysis"]
        case .communications: return ["Storytelling", "Audio Production", "Content Creation", "Audience Engagement"]
        case .engineering: return ["Mathematics", "Problem Solving", "Technical Design", "Project Management"]
        case .science: return ["Research", "Data Analysis", "Critical Thinking", "Scientific Writing"]
        case .law: return ["Legal Research", "Critical Thinking", "Negotiation", "Writing"]
        case .government: return ["Public Policy", "Communication", "Leadership", "Analysis"]
        case .agriculture: return ["Biology", "Land Management", "Problem Solving", "Physical Stamina"]
        case .architecture: return ["Design", "Spatial Reasoning", "CAD Software", "Project Management"]
        case .environment: return ["Environmental Science", "Data Analysis", "Research", "Policy Knowledge"]
        case .hospitality: return ["Customer Service", "Communication", "Organization", "Multitasking"]
        case .manufacturing: return ["Technical Skills", "Quality Control", "Safety Awareness", "Problem Solving"]
        case .military: return ["Discipline", "Leadership", "Physical Fitness", "Strategic Thinking"]
        case .trades: return ["Manual Dexterity", "Problem Solving", "Safety Knowledge", "Physical Stamina"]
        case .transportation: return ["Navigation", "Safety Awareness", "Time Management", "Communication"]
        }
    }

    var suggestedTMIModules: [TMIPlanModel] {
        var modules: [TMIPlanModel] = [.chaseYourSpace, .acknowledgeInterests]
        switch self {
        case .technology, .engineering, .science, .manufacturing, .architecture:
            modules.append(.alignYourMind)
        case .business, .education, .government, .law:
            modules.append(.directAndCorrect)
        case .socialServices, .healthcare, .environment:
            modules.append(.meekToProtector)
        case .sports, .military, .trades:
            modules.append(.alignYourMind)
        case .artsEntertainment, .communications:
            modules.append(.alignYourMind)
        case .agriculture, .hospitality, .transportation:
            break
        }
        if self == .business {
            modules.append(.bullyToBoss)
        }
        return modules
    }
}
