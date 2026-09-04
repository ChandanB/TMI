import Foundation

@MainActor
protocol CareerCatalogProviding {
    /// The canonical catalog, deduplicated and in a stable order.
    func careers() -> [CareerRecord]
}

/// Maps the catalog compiled into the app onto canonical records.
///
/// This is the one place the legacy `CareerPath` shape is read. Everything
/// downstream sees `CareerRecord`, which is what lets the duplicate career
/// models retire without touching every caller again.
@MainActor
struct BundledCareerCatalog: CareerCatalogProviding {
    private let source: [CareerPath]

    init(source: [CareerPath] = CareerCatalog.allCareers) {
        self.source = source
    }

    func careers() -> [CareerRecord] {
        var byID: [String: CareerRecord] = [:]
        for path in source.sorted(by: { $0.title < $1.title }) {
            let record = Self.record(from: path)
            // Two entries that normalize alike are the same career. Keeping the
            // first in a stable order means a duplicate cannot change what the
            // catalog contains depending on file order.
            if byID[record.id] == nil {
                byID[record.id] = record
            }
        }
        return byID.values.sorted { $0.id < $1.id }
    }

    static func record(from path: CareerPath) -> CareerRecord {
        CareerRecord(
            id: CareerRecord.canonicalID(category: path.category, title: path.title),
            title: path.title,
            category: path.category,
            subcategory: path.subcategory.isEmpty ? nil : path.subcategory,
            summary: path.description,
            // Legacy `requiredInterests` holds interest cluster names, and
            // `category` is documented as mapping to a cluster name too.
            interestIDs: path.requiredInterests.sorted(),
            clusterIDs: [path.category],
            educationLevel: educationLevel(from: path.educationLevel),
            // The bundled catalog states salary with no source and no date, so
            // no figure carries over. A number shown to a student about their
            // own future has to say where it came from.
            salary: nil,
            outlook: nil
        )
    }

    static func educationLevel(from legacy: EducationLevel) -> CareerEducationLevel {
        switch legacy {
        case .highSchool: .highSchool
        case .someCollege: .associates
        case .bachelors: .bachelors
        case .masters: .masters
        case .doctorate: .doctorate
        case .vocational, .certification: .certificate
        case .varies: .varies
        }
    }
}

/// Reads the canonical catalog and matches against it.
@MainActor
struct CareerRepository {
    private let catalog: CareerCatalogProviding

    init(catalog: CareerCatalogProviding = BundledCareerCatalog()) {
        self.catalog = catalog
    }

    func careers() -> [CareerRecord] {
        catalog.careers()
    }

    func career(id: String) -> CareerRecord? {
        catalog.careers().first { $0.id == id }
    }

    /// Derived on every call, never stored — see `CareerRelationship`.
    func matches(
        approvedInterests: [StudentInterest],
        clusters: [InterestClusterScore]
    ) -> [CareerMatch] {
        CareerMatcher.match(
            careers: catalog.careers(),
            approvedInterests: approvedInterests,
            clusters: clusters
        )
    }
}
