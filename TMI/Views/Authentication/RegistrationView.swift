import SwiftUI

/// Compatibility entry point for older navigation code.
///
/// All staff onboarding is owned by `SimplifiedRegistrationView`, which uses
/// the injected invitation-based authentication repository.
struct RegistrationView: View {
    @Binding private var isPresented: Bool
    @Binding private var isOperationActive: Bool

    init(
        isPresented: Binding<Bool>,
        isOperationActive: Binding<Bool>
    ) {
        _isPresented = isPresented
        _isOperationActive = isOperationActive
    }

    var body: some View {
        SimplifiedRegistrationView(
            isPresented: $isPresented,
            isOperationActive: $isOperationActive
        )
    }
}

#Preview {
    RegistrationViewPreview()
}

private struct RegistrationViewPreview: View {
    @State private var isPresented = true
    @State private var isOperationActive = false

    var body: some View {
        RegistrationView(
            isPresented: $isPresented,
            isOperationActive: $isOperationActive
        )
    }
}
