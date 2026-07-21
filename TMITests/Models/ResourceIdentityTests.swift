import Foundation
import Testing
@testable import TMI

@Suite("Resource document identity")
struct ResourceIdentityTests {
    @Test("Document identity is excluded from persisted resource data")
    func encodingExcludesDocumentIdentity() throws {
        let resource = Resource(
            id: "stale-document-id",
            title: "Student support guide",
            description: "A staff resource",
            category: .article,
            url: "https://example.com/resource",
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000),
            tags: ["support"],
            recommendedFor: ["Teachers"],
            isFeatured: true,
            thumbnail: "thumbnail.png",
            scope: .district,
            districtId: "district-1",
            ownerUid: "owner-1"
        )

        let data = try JSONEncoder().encode(resource)
        let payload = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let decoded = try JSONDecoder().decode(Resource.self, from: data)

        #expect(payload["id"] == nil)
        #expect(decoded.id == nil)
        #expect(decoded.title == resource.title)
        #expect(decoded.scope == resource.scope)
        #expect(decoded.districtId == resource.districtId)
    }
}
