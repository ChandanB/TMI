import Foundation
import Testing

@Suite("Simplified Registration View")
struct SimplifiedRegistrationViewTests {
    @Test("Registration sheet avoids oversized fixed minimum frame constraints")
    func avoidsOversizedFixedMinimumFrame() throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TMI/Views/Authentication/SimplifiedRegistrationView.swift")
        let source = try String(contentsOf: sourceFileURL, encoding: .utf8)

        #expect(source.contains(".frame(minWidth: 900, minHeight: 900)") == false)
        #expect(source.contains("NavigationView {") == false)
    }
}
