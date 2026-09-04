import Foundation
import Testing
@testable import TMI

@Suite("Career catalog identity")
@MainActor
struct CareerIdentityTests {
    @Test("A career keeps its identifier across rebuilds")
    func identifierIsStableAcrossRebuilds() {
        // The catalog is rebuilt on every launch. A random id would mean a
        // saved or plan-linked career stopped resolving after a restart.
        let first = CareerPath(
            title: "Frontend Developer",
            category: "technology",
            description: "Builds interfaces.",
            requiredInterests: ["technology"],
            icon: "chevron.left.forwardslash.chevron.right",
            color: "#3498DB"
        )
        let second = CareerPath(
            title: "Frontend Developer",
            category: "technology",
            description: "A different description entirely.",
            requiredInterests: ["creative_arts"],
            icon: "star",
            color: "#000000"
        )

        #expect(first.id == second.id)
    }

    @Test("Identity ignores case, spacing and punctuation but not the words")
    func identityNormalizes() {
        let canonical = CareerPath.stableID(category: "technology", title: "Frontend Developer")

        #expect(CareerPath.stableID(category: "Technology", title: "frontend developer") == canonical)
        #expect(CareerPath.stableID(category: "technology", title: "Frontend  Developer") == canonical)
        #expect(CareerPath.stableID(category: "technology", title: "Front-end Developer") != canonical)
        #expect(CareerPath.stableID(category: "healthcare", title: "Frontend Developer") != canonical)
    }

    @Test("An explicit identifier is never overwritten")
    func explicitIdentifierWins() {
        let assigned = UUID()
        let career = CareerPath(
            id: assigned,
            title: "Frontend Developer",
            category: "technology",
            description: "Builds interfaces.",
            requiredInterests: ["technology"],
            icon: "star",
            color: "#000000"
        )

        #expect(career.id == assigned)
    }

    @Test("Every career in the shipped catalog has a distinct identity")
    func shippedCatalogHasNoCollisions() {
        // A collision means two entries are the same career under different
        // descriptions, which the consolidation in Release 2 has to resolve
        // rather than silently keep both.
        var seen: [UUID: [String]] = [:]
        for career in CareerCatalog.allCareers {
            seen[career.id, default: []].append("\(career.category)/\(career.title)")
        }
        let collisions = seen.filter { $0.value.count > 1 }

        #expect(CareerCatalog.allCareers.count > 0)
        #expect(
            collisions.isEmpty,
            "Careers sharing one identity: \(collisions.values.map { $0.sorted().joined(separator: " == ") }.sorted())"
        )
    }
}
