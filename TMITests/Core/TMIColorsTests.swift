import Foundation
import SwiftUI
import Testing
@testable import TMI

@Suite("Golden Hour design tokens")
struct TMIColorsTests {
    @Test("Foundation colors use the approved sRGB values in light and dark")
    func foundationColors() {
        assertColor(TMIColors.background, light: 0xF6F5F2, dark: 0x11100F)
        assertColor(TMIColors.surface, light: 0xFFFFFF, dark: 0x1A1917)
        assertColor(TMIColors.textPrimary, light: 0x1C1917, dark: 0xF5F2EE)
        assertColor(TMIColors.textSecondary, light: 0x5C5650, dark: 0xADA69F)
        assertColor(TMIColors.textTertiary, light: 0x78716B, dark: 0x8A837C)
        assertColor(TMIColors.interactiveBorder, light: 0x8F8881, dark: 0x6F6862)
        assertColor(TMIColors.brand, light: 0xF5A524, dark: 0xF5AE35)
        assertColor(TMIColors.onBrand, light: 0x1C1917, dark: 0x1C1917)
        assertColor(TMIColors.accent, light: 0xA35F00, dark: 0xF7B84A)
        assertColor(TMIColors.onAccent, light: 0xFFFFFF, dark: 0x1C1917)
    }

    @Test("Status text colors meet WCAG AA on their light surfaces")
    func semanticColors() {
        let pairs: [(surface: Color, text: Color, surfaceHex: UInt32, textHex: UInt32)] = [
            (TMIColors.successSurface, TMIColors.successText, 0xE3F4E8, 0x11703A),
            (TMIColors.warningSurface, TMIColors.warningText, 0xFDEBDF, 0xB93C0B),
            (TMIColors.errorSurface, TMIColors.errorText, 0xFDE7E4, 0xB42318),
            (TMIColors.infoSurface, TMIColors.infoText, 0xE6EDFD, 0x1D4ED8),
        ]

        for pair in pairs {
            assertColor(pair.surface, light: pair.surfaceHex)
            assertColor(pair.text, light: pair.textHex)
            #expect(contrastRatio(pair.textHex, pair.surfaceHex) >= 4.5)
        }
    }

    @Test("Core foreground combinations meet WCAG AA in both appearances")
    func coreContrast() {
        // Light
        #expect(contrastRatio(0x1C1917, 0xF6F5F2) >= 4.5)
        #expect(contrastRatio(0x5C5650, 0xFFFFFF) >= 4.5)
        #expect(contrastRatio(0x78716B, 0xFFFFFF) >= 4.5)
        #expect(contrastRatio(0xA35F00, 0xFFFFFF) >= 4.5)
        #expect(contrastRatio(0xA35F00, 0xF6F5F2) >= 4.5)
        #expect(contrastRatio(0x1C1917, 0xF5A524) >= 4.5)
        #expect(contrastRatio(0xFFFFFF, 0xA35F00) >= 4.5)
        #expect(contrastRatio(0x8F8881, 0xFFFFFF) >= 3)
        #expect(contrastRatio(0xC77C07, 0xFFFFFF) >= 3)
        // Dark
        #expect(contrastRatio(0xF5F2EE, 0x11100F) >= 4.5)
        #expect(contrastRatio(0xADA69F, 0x1A1917) >= 4.5)
        #expect(contrastRatio(0x8A837C, 0x1A1917) >= 4.5)
        #expect(contrastRatio(0xF7B84A, 0x1A1917) >= 4.5)
        #expect(contrastRatio(0x1C1917, 0xF5AE35) >= 4.5)
        #expect(contrastRatio(0x1C1917, 0xF7B84A) >= 4.5)
        #expect(contrastRatio(0x6F6862, 0x1A1917) >= 3)
    }

    @Test("Legacy color aliases resolve through the Golden Hour palette")
    func legacyAliases() {
        assertSameColor(.tmiPrimary, TMIColors.accent)
        assertSameColor(.tmiSecondary, TMIColors.accent)
        assertSameColor(TMIColors.aubergine, TMIColors.accent)
        assertSameColor(TMIColors.teal, TMIColors.accent)
        assertSameColor(.tmiBackground, TMIColors.background)
        assertSameColor(.tmiTextPrimary, TMIColors.textPrimary)
        assertSameColor(.tmiTextSecondary, TMIColors.textSecondary)
        assertSameColor(.tmiTextTertiary, TMIColors.textTertiary)
        assertSameColor(.tmiBorder, TMIColors.border)
    }

    @Test("The application follows the system appearance and tints with amber ink")
    func adaptiveApplication() throws {
        let root = repositoryRoot
        let appSource = try String(
            contentsOf: root.appending(path: "TMI/App/TMIApp.swift"),
            encoding: .utf8
        )
        let settingsSource = try String(
            contentsOf: root.appending(path: "TMI/Views/Settings/SettingsView.swift"),
            encoding: .utf8
        )

        #expect(!appSource.contains(".preferredColorScheme(.light)"))
        #expect(appSource.contains(".tint(TMIColors.accent)"))
        #expect(!settingsSource.contains("darkModeEnabled"))
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
        light: UInt32,
        dark: UInt32? = nil,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        var lightEnvironment = EnvironmentValues()
        lightEnvironment.colorScheme = .light
        assertResolved(color.resolve(in: lightEnvironment), equals: light, sourceLocation: sourceLocation)

        if let dark {
            var darkEnvironment = EnvironmentValues()
            darkEnvironment.colorScheme = .dark
            assertResolved(color.resolve(in: darkEnvironment), equals: dark, sourceLocation: sourceLocation)
        }
    }

    private func assertResolved(
        _ actual: Color.Resolved,
        equals hex: UInt32,
        sourceLocation: Testing.SourceLocation
    ) {
        let expected = rgbComponents(hex)
        #expect(abs(Double(actual.red) - expected.red) < 0.002, sourceLocation: sourceLocation)
        #expect(abs(Double(actual.green) - expected.green) < 0.002, sourceLocation: sourceLocation)
        #expect(abs(Double(actual.blue) - expected.blue) < 0.002, sourceLocation: sourceLocation)
        #expect(abs(Double(actual.opacity) - 1) < 0.002, sourceLocation: sourceLocation)
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
