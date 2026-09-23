#if DEBUG
import FirebaseCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// DEBUG-only developer console. Pushed onto the existing navigation stack
/// (from Settings), so it must not introduce its own `NavigationStack`.
struct DeveloperModeView: View {
    @State private var state: DeveloperModeState

    init(repository: (any DeveloperConsoleRepository)? = nil) {
        let resolved = repository ?? (FirebaseApp.app() == nil
            ? UnconfiguredDeveloperConsoleRepository()
            : FirebaseDeveloperConsoleRepository())
        _state = State(initialValue: DeveloperModeState(repository: resolved))
    }

    var body: some View {
        List {
            DeveloperEnvironmentSection(state: state)

            Section {
                NavigationLink {
                    DeveloperTenantsView(state: state)
                } label: {
                    Label("Organizations & sites", systemImage: "building.2")
                }
                NavigationLink {
                    DeveloperInvitationsView(state: state)
                } label: {
                    Label("Invitation codes", systemImage: "envelope.badge.person.crop")
                }
                NavigationLink {
                    DeveloperMembersView(state: state)
                } label: {
                    Label("Staff access", systemImage: "person.2.badge.key")
                }
            } header: {
                Text("Server console")
            } footer: {
                Text("Operator-only Cloud Functions. The server rejects every request unless this account is a platform operator.")
            }
            .disabled(!state.isOperator)

            Section("On this device") {
                NavigationLink {
                    DeveloperLocalTenantView()
                } label: {
                    Label("Local debug tenant", systemImage: "internaldrive")
                }
                NavigationLink {
                    DeveloperSessionDiagnosticsView()
                } label: {
                    Label("Session diagnostics", systemImage: "stethoscope")
                }
            }
        }
        .navigationTitle("Developer Mode")
        .navigationBarTitleDisplayMode(.inline)
        .tint(TMIColors.accent)
        .task { await state.load() }
        .refreshable { await state.load() }
    }
}

private struct DeveloperEnvironmentSection: View {
    let state: DeveloperModeState

    var body: some View {
        Section("Environment") {
            LabeledContent("Firebase project", value: FirebaseBootstrap.projectID)
            LabeledContent("Backend", value: FirebaseEnvironment.current.target == .emulator
                ? "Local emulator (\(FirebaseEnvironment.current.emulatorHost))"
                : "Live")
            switch state.phase {
            case .idle, .loading:
                HStack {
                    Text("Operator status")
                    Spacer()
                    ProgressView()
                }
            case .ready:
                LabeledContent("Operator status") {
                    DeveloperBadge(
                        text: state.isOperator ? "Operator" : "Not an operator",
                        tone: state.isOperator ? .positive : .warning
                    )
                }
                if state.status?.isEnabled == false {
                    Text("The developer console is disabled on this project (TMI_DEVELOPER_CONSOLE).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !state.isOperator {
                    Text("Grant access from the repo: `npm --prefix functions run operator:grant -- --email <your email> --project \(FirebaseBootstrap.projectID)`, then pull to refresh.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            case .failed(let error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(TMIColors.warningText)
                Button("Retry") { Task { await state.load() } }
            }
            DeveloperEnvironmentPicker()
        }
    }
}

private struct DeveloperEnvironmentPicker: View {
    @State private var environment = FirebaseEnvironment.current
    @State private var needsRelaunch = false

    var body: some View {
        Picker("Use backend", selection: $environment.target) {
            Text("Live project").tag(FirebaseEnvironment.Target.live)
            Text("Local emulators").tag(FirebaseEnvironment.Target.emulator)
        }
        .onChange(of: environment) { _, newValue in
            FirebaseEnvironment.current = newValue
            needsRelaunch = true
        }
        if environment.target == .emulator {
            TextField("Emulator host", text: $environment.emulatorHost)
                .tmiTextInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        if needsRelaunch {
            Text("Relaunch the app to switch backends. Run `firebase emulators:start --project \(FirebaseBootstrap.projectID)` from the repo root first.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Shared pieces

struct DeveloperBadge: View {
    enum Tone {
        case positive, warning, neutral, negative

        var color: Color {
            switch self {
            case .positive: .green
            case .warning: .orange
            case .neutral: .secondary
            case .negative: .red
            }
        }
    }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tone.color)
            .background(tone.color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(tone.color.opacity(0.4)))
    }
}

extension DevInvitationStatus {
    var badgeTone: DeveloperBadge.Tone {
        switch self {
        case .active: .positive
        case .consumed: .neutral
        case .expired: .warning
        case .revoked: .negative
        }
    }
}

/// Presents `actionError` from the state as an alert.
struct DeveloperErrorAlert: ViewModifier {
    @Bindable var state: DeveloperModeState

    func body(content: Content) -> some View {
        content.alert(
            "Request failed",
            isPresented: Binding(
                get: { state.actionError != nil },
                set: { if !$0 { state.actionError = nil } }
            ),
            presenting: state.actionError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

extension View {
    func developerErrorAlert(_ state: DeveloperModeState) -> some View {
        modifier(DeveloperErrorAlert(state: state))
    }
}

enum DeveloperClipboard {
    @MainActor
    static func copy(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
#elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}

enum DeveloperDates {
    static func display(_ iso: String?) -> String {
        guard let iso else { return "—" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
#endif
