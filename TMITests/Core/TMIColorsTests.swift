import Foundation
import SwiftUI
import Testing
@testable import TMI

@Suite("Aubergine and Teal design tokens")
struct TMIColorsTests {
    @Test("Foundation colors use the approved sRGB values")
    func foundationColors() {
        assertColor(TMIColors.background, equals: 0xF7F6FA)
        assertColor(TMIColors.surface, equals: 0xFFFFFF)
        assertColor(TMIColors.textPrimary, equals: 0x1F1A24)
        assertColor(TMIColors.textSecondary, equals: 0x514A57)
        assertColor(TMIColors.border, equals: 0xC7C0CF)
        assertColor(TMIColors.interactiveBorder, equals: 0x8A8191)
        assertColor(TMIColors.aubergine, equals: 0x5B2A5B)
        assertColor(TMIColors.teal, equals: 0x0F766E)
        assertColor(TMIColors.aubergineSoft, equals: 0xEDE1ED)
        assertColor(TMIColors.aubergineForeground, equals: 0xFFFFFF)
        assertColor(TMIColors.tealForeground, equals: 0xFFFFFF)
    }

    @Test("Semantic status colors use accessible surface and text pairs")
    func semanticColors() {
        let pairs: [(surface: Color, text: Color, surfaceHex: UInt32, textHex: UInt32)] = [
            (TMIColors.successSurface, TMIColors.successText, 0xDFF3E7, 0x14532D),
            (TMIColors.warningSurface, TMIColors.warningText, 0xF4E8C8, 0x6B4306),
            (TMIColors.errorSurface, TMIColors.errorText, 0xFCE8E6, 0x8F2118),
            (TMIColors.infoSurface, TMIColors.infoText, 0xDFF1EF, 0x0D5B55),
        ]

        for pair in pairs {
            assertColor(pair.surface, equals: pair.surfaceHex)
            assertColor(pair.text, equals: pair.textHex)
            #expect(contrastRatio(pair.textHex, pair.surfaceHex) >= 4.5)
        }
    }

    @Test("Core foreground combinations meet WCAG AA")
    func coreContrast() {
        #expect(contrastRatio(0x1F1A24, 0xF7F6FA) >= 4.5)
        #expect(contrastRatio(0x514A57, 0xFFFFFF) >= 4.5)
        #expect(contrastRatio(0xFFFFFF, 0x5B2A5B) >= 4.5)
        #expect(contrastRatio(0xFFFFFF, 0x0F766E) >= 4.5)
        #expect(contrastRatio(0x8A8191, 0xFFFFFF) >= 3)
    }

    @Test("Legacy color aliases resolve through the approved semantic palette")
    func legacyAliases() {
        assertSameColor(.tmiPrimary, TMIColors.aubergine)
        assertSameColor(.tmiSecondary, TMIColors.teal)
        assertSameColor(.tmiBackground, TMIColors.background)
        assertSameColor(.tmiTextPrimary, TMIColors.textPrimary)
        assertSameColor(.tmiTextSecondary, TMIColors.textSecondary)
        assertSameColor(.tmiBorder, TMIColors.border)
    }

    @Test("The application is light-only and uses teal as its global action tint")
    func lightOnlyApplication() throws {
        let root = repositoryRoot
        let appSource = try String(
            contentsOf: root.appending(path: "TMI/App/TMIApp.swift"),
            encoding: .utf8
        )
        let settingsSource = try String(
            contentsOf: root.appending(path: "TMI/Views/Settings/SettingsView.swift"),
            encoding: .utf8
        )

        #expect(appSource.contains(".preferredColorScheme(.light)"))
        #expect(appSource.contains(".tint(TMIColors.teal)"))
        #expect(!settingsSource.contains("darkModeEnabled"))
        #expect(!settingsSource.contains("Dark Mode"))
    }

    @Test("Retired warm palette values are absent from production Swift")
    func retiredPaletteIsAbsent() throws {
        let sourceRoot = repositoryRoot.appending(path: "TMI")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )
        )
        var source = ""

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            source += try String(contentsOf: fileURL, encoding: .utf8)
        }

        let retiredHexValues = [
            "#FDF8F3", "#F5EDE3", "#D4930D", "#B87A0A", "#3B6FA0",
            "#F8F3ED", "#F5F0EB", "#E8E2DA", "#D9D2C9", "#F0EBE4",
        ]
        for value in retiredHexValues {
            #expect(!source.contains(value), "Found retired color value: \(value)")
        }
    }

    private func assertColor(
        _ color: Color,
        equals hex: UInt32,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        let actual = color.resolve(in: EnvironmentValues())
        let expected = rgbComponents(hex)

        #expect(abs(Double(actual.red) - expected.red) < 0.000_1, sourceLocation: sourceLocation)
        #expect(abs(Double(actual.green) - expected.green) < 0.000_1, sourceLocation: sourceLocation)
        #expect(abs(Double(actual.blue) - expected.blue) < 0.000_1, sourceLocation: sourceLocation)
        #expect(abs(Double(actual.opacity) - 1) < 0.000_1, sourceLocation: sourceLocation)
    }

    private func assertSameColor(
        _ lhs: Color,
        _ rhs: Color,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        let lhsResolved = lhs.resolve(in: EnvironmentValues())
        let rhsResolved = rhs.resolve(in: EnvironmentValues())

        #expect(lhsResolved == rhsResolved, sourceLocation: sourceLocation)
    }

    private func contrastRatio(_ foreground: UInt32, _ background: UInt32) -> Double {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ hex: UInt32) -> Double {
        let components = rgbComponents(hex)
        let linear = [components.red, components.green, components.blue].map { component in
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
    }

    private func rgbComponents(_ hex: UInt32) -> (red: Double, green: Double, blue: Double) {
        (
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
