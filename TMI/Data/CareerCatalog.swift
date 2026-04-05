//
//  CareerCatalog.swift
//  TMI
//
//  Aggregates all career category files into a single catalog
//

import Foundation

struct CareerCatalog {
    static let allCareers: [CareerPath] =
        AgricultureCareers.all +
        ArchitectureCareers.all +
        ArtsEntertainmentCareers.all +
        BusinessCareers.all +
        CommunicationsCareers.all +
        EducationCareers.all +
        EngineeringCareers.all +
        EnvironmentCareers.all +
        GovernmentCareers.all +
        HealthcareCareers.all +
        HospitalityCareers.all +
        LawCareers.all +
        ManufacturingCareers.all +
        MilitaryCareers.all +
        ScienceCareers.all +
        SocialServicesCareers.all +
        SportsCareers.all +
        TechnologyCareers.all +
        TradesCareers.all +
        TransportationCareers.all

    static var careersByCategory: [String: [CareerPath]] {
        Dictionary(grouping: allCareers, by: \.category)
    }

    static func careersGrouped(for category: String) -> [String: [CareerPath]] {
        let categoryCareers = allCareers.filter { $0.category == category }
        return Dictionary(grouping: categoryCareers, by: \.subcategory)
    }

    static func subcategories(for category: String) -> [String] {
        Array(Set(allCareers.filter { $0.category == category }.map { $0.subcategory })).sorted()
    }

    static var count: Int { allCareers.count }
}
