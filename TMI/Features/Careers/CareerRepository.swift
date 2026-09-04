import Foundation
@preconcurrency import FirebaseFirestore

@MainActor
protocol CareerCatalogProviding {
    /// The canonical catalog, deduplicated and in a stable order.
    func careers() async throws -> [CareerRecord]
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

    func careers() async throws -> [CareerRecord] {
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
            outlook: nil,
            aliases: [
                "\(CareerRecord.normalized(path.category))/\(CareerRecord.normalized(path.title))",
                path.title,
                path.id.uuidString.lowercased()
            ]
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

enum CareerCatalogError: LocalizedError {
    case invalidRecord(String)

    var errorDescription: String? {
        switch self { case .invalidRecord(let id): "Career catalog record \(id) is invalid." }
    }
}

@MainActor
struct FirestoreCareerCatalog: CareerCatalogProviding {
    private let firestore: Firestore
    init(firestore: Firestore = Firestore.firestore()) { self.firestore = firestore }

    func careers() async throws -> [CareerRecord] {
        let snapshot = try await self.firestore.collection("catalogs")
            .document("careers").collection("items")
            .whereField("isApproved", isEqualTo: true).getDocuments()
        return try snapshot.documents.map { document in
            let data = document.data()
            guard let title = data["title"] as? String,
                  let category = data["category"] as? String,
                  let summary = data["summary"] as? String,
                  let interestIDs = data["interestIDs"] as? [String],
                  let clusterIDs = data["clusterIDs"] as? [String],
                  let educationRaw = data["educationLevel"] as? String,
                  let education = CareerEducationLevel(rawValue: educationRaw) else {
                throw CareerCatalogError.invalidRecord(document.documentID)
            }
            return CareerRecord(
                id: document.documentID, title: title, category: category,
                subcategory: data["subcategory"] as? String, summary: summary,
                interestIDs: interestIDs, clusterIDs: clusterIDs,
                educationLevel: education, salary: nil, outlook: nil,
                aliases: data["aliases"] as? [String] ?? []
            )
        }.sorted { $0.id < $1.id }
    }
}

/// Reads the canonical catalog and matches against it.
@MainActor
struct CareerRepository {
    private let catalog: CareerCatalogProviding

    init(catalog: CareerCatalogProviding = FirestoreCareerCatalog()) {
        self.catalog = catalog
    }

    func careers() async throws -> [CareerRecord] {
        try await catalog.careers()
    }

    func career(id: String) async throws -> CareerRecord? {
        let normalized = id.lowercased()
        return try await catalog.careers().first {
            $0.id == normalized || $0.aliases.contains { $0.lowercased() == normalized }
        }
    }

    /// Derived on every call, never stored — see `CareerRelationship`.
    func matches(
        approvedInterests: [StudentInterest],
        clusters: [InterestClusterScore]
    ) async throws -> [CareerMatch] {
        CareerMatcher.match(
            careers: try await catalog.careers(),
            approvedInterests: approvedInterests,
            clusters: clusters
        )
    }
}
