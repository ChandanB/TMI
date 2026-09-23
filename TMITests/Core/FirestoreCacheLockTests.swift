import Foundation
import Testing
@testable import TMI

struct FirestoreCacheLockTests {
    @Test func lockFileMatchesFirestoreLayout() throws {
        let root = URL(filePath: "/tmp/support", directoryHint: .isDirectory)
        let url = try #require(FirestoreCacheLock.lockFileURL(projectID: "tmi-education", applicationSupport: root))
        #expect(url.path(percentEncoded: false) == "/tmp/support/firestore/__FIRAPP_DEFAULT/tmi-education/main/LOCK")
    }

    @Test func missingLockFileIsFree() {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        #expect(FirestoreCacheLock.holder(of: url) == nil)
    }

    @Test func unlockedFileIsFree() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "LOCK-\(UUID().uuidString)")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FirestoreCacheLock.holder(of: url) == nil)
    }
}
