import Foundation
import Testing

@Suite("Firestore persistence contracts")
struct FirestorePersistenceContractTests {
    @Test("Model writes use offline-capable local enqueue")
    func modelWritesUseLocalEnqueue() throws {
        let source = try sourceFile(at: "TMI/Services/FirestoreConstants.swift")

        #expect(!source.contains("withCheckedThrowingContinuation"))
        #expect(!source.contains("CheckedContinuation"))
        #expect(!source.contains("setData(data, merge: merge) {"))
        #expect(!source.contains("reference.setData(data) {"))
        #expect(source.contains("func enqueueDataLocally"))
        #expect(source.contains("setData(data, merge: merge, completion: nil)"))
        #expect(source.contains("enqueueDataLocally(data, merge: merge)"))
        #expect(source.contains("reference.enqueueDataLocally(data, merge: false)"))
        #expect(source.contains("offline-capable local enqueue"))
        #expect(source.contains("confirmed-write contract"))
    }

    @Test("Document decoding preserves canonical Firestore identity")
    func documentDecodingPreservesIdentity() throws {
        let source = try sourceFile(at: "TMI/Services/FirestoreConstants.swift")

        #expect(source.contains("nonisolated extension DocumentSnapshot"))
        #expect(source.contains("func decodedModel<Value: Decodable>"))
        #expect(source.contains("assigningDocumentIDTo keyPath"))
        #expect(source.contains("value[keyPath: keyPath] = documentID"))
    }

    @Test("Observable preview dependencies are injected explicitly")
    func previewsInjectObservableDependencies() throws {
        let mainTabSource = try sourceFile(at: "TMI/Views/MainTabView.swift")
        let studentDetailSource = try sourceFile(
            at: "TMI/Views/Students/StudentDetailView.swift"
        )

        #expect(
            mainTabSource.components(
                separatedBy: ".environment(DeepLinkRouter())"
            ).count - 1 == 2
        )
        #expect(
            studentDetailSource.contains(
                ".environment(ScheduleMeetingCoordinator())"
            )
        )
    }

    private func sourceFile(at relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appending(path: relativePath),
            encoding: .utf8
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
