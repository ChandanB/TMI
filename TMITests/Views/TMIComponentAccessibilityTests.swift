import Foundation
import Testing
@testable import TMI

#if canImport(UIKit)
import SwiftUI
#endif

@Suite("TMI component accessibility")
struct TMIComponentAccessibilityTests {
    @Test("Loading buttons keep their name and announce progress")
    func loadingButtonsKeepAccessibleSemantics() throws {
        let source = try source(
            at: "TMI/Views/Components/TMIComponentLibrary.swift"
        )

        #expect(source.contains(".accessibilityLabel(text)"))
        #expect(
            source.contains(
                ".accessibilityValue(isLoading ? \"In progress\" : \"\")"
            )
        )
    }

    @Test("Text fields accept capitalization and staff names request words")
    func staffNameRequestsWordCapitalization() throws {
        let components = try source(
            at: "TMI/Views/Components/TMIComponentLibrary.swift"
        )
        let setup = try source(
            at: "TMI/Views/Authentication/StaffAccessSetupView.swift"
        )

        #expect(
            components.contains(
                "var capitalization: TMITextInputAutocapitalization?"
            )
        )
        #expect(
            components.contains(
                "private var effectiveCapitalization: TMITextInputAutocapitalization?"
            )
        )
        #expect(
            components.contains(
                ".tmiTextInputAutocapitalization(effectiveCapitalization)"
            )
        )
        #expect(setup.contains("capitalization: .words"))
    }

#if canImport(UIKit)
    @Test(
        "Cross-platform capitalization maps to UIKit",
        arguments: [
            (TMITextInputAutocapitalization.never, TextInputAutocapitalization.never),
            (.sentences, .sentences),
            (.words, .words),
            (.characters, .characters),
        ]
    )
    @MainActor
    func capitalizationMapsToUIKit(
        value: TMITextInputAutocapitalization,
        expected: TextInputAutocapitalization
    ) {
        #expect(
            String(reflecting: value.uiKitValue) == String(reflecting: expected)
        )
    }
#endif

    private func source(at relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
