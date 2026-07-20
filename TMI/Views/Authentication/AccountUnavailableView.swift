//
//  AccountUnavailableView.swift
//  TMI
//
//  Keeps unsupported account types out of privileged app roots while allowing
//  the current Firebase session to be ended safely.
//

import SwiftUI

struct AccountUnavailableView: View {
    let title: String
    let description: String
    let signOutAction: @MainActor () -> Bool

    @State private var isShowingSignOutError = false

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.circle")
        } description: {
            Text(description)
        } actions: {
            Button("Sign Out", action: attemptSignOut)
                .buttonStyle(.borderedProminent)
        }
        .alert("Couldn’t Sign Out", isPresented: $isShowingSignOutError) {
            Button("Retry", action: attemptSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your account is still signed in. Check your connection and try again.")
        }
    }

    @MainActor
    private func attemptSignOut() {
        isShowingSignOutError = !signOutAction()
    }
}

#Preview {
    AccountUnavailableView(
        title: "Account Unavailable",
        description: "This account type is not available in this version of TMI.",
        signOutAction: { false }
    )
}
