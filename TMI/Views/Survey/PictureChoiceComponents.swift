import AVFoundation
import SwiftUI

/// Resolves a survey option's `imageReference` to something drawable:
/// `sf:<symbol>` → SF Symbol; a bundled asset name → that asset; anything else
/// (for example a Storage path not yet cached) → a neutral photo symbol, so a
/// picture question never collapses into text.
struct SurveyOptionImage: View {
    let reference: String?
    let label: String

    var body: some View {
        Group {
            if let symbol = symbolName {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .padding(TMISpacing.md)
                    .foregroundStyle(TMIColors.accent)
            } else if let reference, Self.hasAsset(named: reference) {
                Image(reference)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: Self.fallbackSymbol(for: reference))
                    .resizable()
                    .scaledToFit()
                    .padding(TMISpacing.lg)
                    .foregroundStyle(TMIColors.accent.opacity(0.8))
            }
        }
        .accessibilityHidden(true)
    }

    private var symbolName: String? {
        guard let reference, reference.hasPrefix("sf:") else { return nil }
        return String(reference.dropFirst(3))
    }

    private static func hasAsset(named name: String) -> Bool {
#if canImport(UIKit)
        UIImage(named: name) != nil
#else
        NSImage(named: name) != nil
#endif
    }

    /// A few friendly defaults for well-known fixture references.
    static func fallbackSymbol(for reference: String?) -> String {
        let key = reference?.split(separator: "/").last.map(String.init) ?? ""
        switch key {
        case "forest", "nature", "outdoors": return "tree.fill"
        case "city": return "building.2.fill"
        case "music": return "music.note"
        case "art": return "paintpalette.fill"
        case "animals": return "pawprint.fill"
        case "blocks", "building": return "square.stack.3d.up.fill"
        case "books", "stories": return "book.fill"
        case "vehicles", "trucks": return "car.fill"
        case "water", "sand": return "drop.fill"
        case "pretend": return "theatermasks.fill"
        default: return "photo"
        }
    }
}

/// Reads prompts aloud for children who can't read yet. Owned by the view
/// that shows the prompt; no global state.
@MainActor
@Observable
final class PromptNarrator {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

struct ReadAloudButton: View {
    let text: String
    let narrator: PromptNarrator

    var body: some View {
        Button {
            narrator.speak(text)
        } label: {
            Label("Read aloud", systemImage: "speaker.wave.2.fill")
                .font(.headline)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.tmiSecondary)
        .accessibilityHint("Reads the question out loud")
        .accessibilityIdentifier("studentSurvey.readAloud")
    }
}

/// Large picture tiles for image-choice questions: two per row, 88-point-plus
/// targets, the label under the picture, and a clear selected state that does
/// not rely on color alone.
struct PictureChoiceGrid: View {
    let options: [SurveyOption]
    let isSelected: (String) -> Bool
    let onChoose: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: TMISpacing.md)],
            spacing: TMISpacing.md
        ) {
            ForEach(options, id: \.id) { option in
                let selected = isSelected(option.id)
                Button {
                    onChoose(option.id)
                } label: {
                    VStack(spacing: TMISpacing.sm) {
                        SurveyOptionImage(reference: option.imageReference, label: option.label)
                            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 140)
                        HStack(spacing: TMISpacing.xs) {
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .accessibilityHidden(true)
                            }
                            Text(option.label)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .foregroundStyle(selected ? TMIColors.infoText : TMIColors.textPrimary)
                    .padding(TMISpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 176)
                    .background(selected ? TMIColors.infoSurface : TMIColors.surface,
                                in: RoundedRectangle(cornerRadius: TMIRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: TMIRadius.lg)
                            .stroke(selected ? TMIColors.accent : TMIColors.interactiveBorder,
                                    lineWidth: selected ? 4 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("studentSurvey.option.\(option.id)")
            }
        }
    }
}
