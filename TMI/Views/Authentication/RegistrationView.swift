import SwiftUI

/// Compatibility entry point for older navigation code.
///
/// All staff onboarding is owned by `SimplifiedRegistrationView`, which uses
/// the injected invitation-based authentication repository.
struct RegistrationView: View {
    var body: some View {
        SimplifiedRegistrationView()
    }
}

#Preview {
    RegistrationView()
}
