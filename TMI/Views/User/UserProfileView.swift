//
//  UserProfileStateModel.swift
//  TMI
//
//  Created by Chandan Brown on 9/16/24.
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Observation
import PhotosUI
import SDWebImageSwiftUI
import SwiftUI
import WebKit


// MARK: - State Model

@Observable
final class UserProfileStateModel: BaseStateModel<UserProfileData, IdentifiableError> {
    /// True while a profile save is in flight.
    var isSaving = false

    // MARK: - Dependencies
    private let firebaseManager: FirebaseManager

    // MARK: - Photo State
    var organization: String = ""
    var photoURL: String?
    var selectedPhotoItem: PhotosPickerItem?
    var selectedPhotoData: Data?
    var isUploadingPhoto = false

    // MARK: - Initialization

    init(firebaseManager: FirebaseManager = FirebaseManager.shared) {
        self.firebaseManager = firebaseManager
        super.init()

        // Initialize UI state
        ui.set("isChangingEmail", value: false)
    }

    // MARK: - Data Fetching

    @MainActor
    override func fetch() async {
        print("[UserProfileStateModel] Starting fetch")
        updateState(.loading)

        guard let user = Auth.auth().currentUser else {
            print("[UserProfileStateModel] No authenticated user found")
            let error = ErrorHandlingHelper.handleError(
                FirebaseError.authError("Not logged in"),
                userFriendlyMessage: "Not logged in"
            )
            updateState(.error(error))
            return
        }

        print("[UserProfileStateModel] Found authenticated user: \(user.uid)")

        // Initialize profile data with Auth data
        var profileData = UserProfileData(displayName: user.displayName ?? "User")
        profileData.email = user.email ?? ""
        profileData.displayName = user.displayName ?? "User"
        profileData.isEmailVerified = user.isEmailVerified

        do {
            // Load user profile from Firestore
            print("[UserProfileStateModel] Attempting to load Firestore profile")
            if let userData = try await firebaseManager.getCurrentUserProfile() {
                print("[UserProfileStateModel] Found Firestore profile data: \(userData)")
                profileData.displayName = userData["displayName"] as? String ?? profileData.displayName
                organization = userData["organization"] as? String ?? ""
                photoURL = userData["photoURL"] as? String

                print("[UserProfileStateModel] Successfully loaded profile for: \(profileData.displayName)")
                updateState(.loaded(profileData))
            } else {
                print("[UserProfileStateModel] No Firestore profile found, using Auth data only")
                // Use Auth data if no Firestore profile exists
                updateState(.loaded(profileData))
            }
        } catch {
            print("[UserProfileStateModel] Error loading profile: \(error)")

            // If Firestore fails, still show the user profile with Auth data
            print("[UserProfileStateModel] Falling back to Auth data due to Firestore error")
            updateState(.loaded(profileData))

            // Show a warning but don't fail completely
            ui.alertMessage = "Some profile features may be limited due to a connection issue"
            ui.isShowingAlert = true
        }
    }

    @MainActor
    override func refresh() async {
        resetState()
        await fetch()
    }

    // MARK: - Profile Update Methods

    @MainActor
    func updateProfile() async {
        guard let profileData = state.value else {
            let error = ErrorHandlingHelper.handleError(
                FirebaseError.missingData("No profile data to update"),
                userFriendlyMessage: "No profile data to update"
            )
            updateState(.error(error))
            return
        }

        // Keep the form (and the person's edits) on screen while saving; a
        // full-screen spinner used to replace it and an error discarded edits.
        isSaving = true
        defer { isSaving = false }

        do {
            // Update displayName in Auth
            if let user = Auth.auth().currentUser {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = profileData.displayName
                try await changeRequest.commitChanges()
            }

            // Update profile in Firestore (including organization)
            try await firebaseManager.updateUserProfile(data: [
                "displayName": profileData.displayName,
                "organization": organization
            ])

            ui.alertMessage = "Your profile is up to date."
            ui.isShowingAlert = true
        } catch {
            _ = ErrorHandlingHelper.handleError(error, userFriendlyMessage: "Failed to update profile")
            ui.alertMessage = "Your profile couldn’t be saved. Your changes are still here; check your connection and try again."
            ui.isShowingAlert = true
        }
    }

    @MainActor
    func uploadProfilePhoto() async {
        guard let photoData = selectedPhotoData else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            let storageRef = Storage.storage().reference().child("users/\(uid)/profile.jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await storageRef.putDataAsync(photoData, metadata: metadata)
            let url = try await storageRef.downloadURL()
            photoURL = url.absoluteString

            let userRef = Firestore.firestore().collection("users").document(uid)
            try await userRef.updateData(["photoURL": url.absoluteString])
        } catch {
            let handledError = ErrorHandlingHelper.handleError(error, userFriendlyMessage: "Failed to upload photo")
            ui.alertMessage = handledError.message
            ui.isShowingAlert = true
        }
    }

    @MainActor
    func updateEmail() async {
        guard let profileData = state.value else {
            let error = ErrorHandlingHelper.handleError(
                FirebaseError.missingData("No profile data available"),
                userFriendlyMessage: "No profile data available"
            )
            updateState(.error(error))
            return
        }

        guard !profileData.newEmail.isEmpty, !profileData.currentPassword.isEmpty else {
            let error = ErrorHandlingHelper.handleError(
                FirebaseError.missingData("Please fill in all fields"),
                userFriendlyMessage: "Please fill in all fields"
            )
            updateState(.error(error))
            return
        }

        updateState(.loading)

        do {
            // Re-authenticate user first (required for sensitive operations)
            try await firebaseManager.reauthenticate(with: profileData.currentPassword)

            // Update email in Auth and Firestore
            try await firebaseManager.updateEmail(to: profileData.newEmail)

            // Update local state
            var updatedProfile = profileData
            updatedProfile.email = profileData.newEmail
            updatedProfile.newEmail = ""
            updatedProfile.currentPassword = ""

            updateState(.loaded(updatedProfile))

            // Close email change sheet
            ui.set("isChangingEmail", value: false)

            // Show success message
            ui.alertMessage = "Email updated successfully"
            ui.isShowingAlert = true
        } catch {
            let handledError = ErrorHandlingHelper.handleError(error, userFriendlyMessage: "Failed to update email")
            updateState(.error(handledError))
        }
    }

    @MainActor
    func sendVerificationEmail() async {
        updateState(.loading)

        do {
            try await firebaseManager.verifyEmail()

            // Show success message
            ui.alertMessage = "Verification email sent"
            ui.isShowingAlert = true

            // Refresh to get updated verification status
            await fetch()
        } catch {
            let handledError = ErrorHandlingHelper.handleError(error, userFriendlyMessage: "Failed to send verification email")
            updateState(.error(handledError))
        }
    }

    @MainActor
    func signOut() {
        do {
            try firebaseManager.signOut()
        } catch {
            let handledError = ErrorHandlingHelper.handleError(error, userFriendlyMessage: "Failed to sign out")
            updateState(.error(handledError))
        }
    }

    // MARK: - Form Field Update Methods

    @MainActor func updateDisplayName(_ newValue: String) {
        guard var profileData = state.value else { return }
        profileData.displayName = newValue
        updateState(.loaded(profileData))
    }

    @MainActor func updateNewEmail(_ newValue: String) {
        guard var profileData = state.value else { return }
        profileData.newEmail = newValue
        updateState(.loaded(profileData))
    }

    @MainActor func updateCurrentPassword(_ newValue: String) {
        guard var profileData = state.value else { return }
        profileData.currentPassword = newValue
        updateState(.loaded(profileData))
    }

    // MARK: - UI State Accessors

    var isChangingEmail: Bool {
        get { return ui.get("isChangingEmail") ?? false }
        set { ui.set("isChangingEmail", value: newValue) }
    }
}

//
//  UserProfileView.swift
//  TMI
//
//  Created by Chandan Brown on 9/16/24.
//

struct UserProfileView: View {
    @State private var stateModel = UserProfileStateModel()
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingDeleteAccount = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.studentContext) private var studentContext
    @Environment(AppRouter.self) private var router
    @State private var showingSignOutConfirmation = false
    /// The Change Email sheet keeps showing this while a save is in flight
    /// (the live state is `.loading`, which used to blank the sheet).
    @State private var lastLoadedProfile: UserProfileData?
    @State private var showingSignOutFailure = false

    var body: some View {
        ZStack {
            TMIColors.background
                .ignoresSafeArea()

            Group {
                switch stateModel.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded(let profileData):
                    userProfileForm(
                        profileData,
                        stateModel: stateModel,
                        dismiss: dismiss,
                        showingPrivacyPolicy: $showingPrivacyPolicy,
                        showingTermsOfService: $showingTermsOfService,
                        showingDeleteAccount: $showingDeleteAccount,
                        roleDisplayName: authStateModel.currentMembership?.role.displayName,
                        onSignOut: { showingSignOutConfirmation = true }
                    )

                case .error(let error):
                    VStack(spacing: 16) {
                        Text("Error loading profile")
                            .font(.headline)
                            .foregroundColor(Color.tmiTextPrimary)

                        Text(error.message)
                            .foregroundStyle(TMIColors.errorText)
                            .multilineTextAlignment(.center)

                        TMIButton(
                            text: "Try Again",
                            style: .primary,
                            action: {
                                Task {
                                    await stateModel.refresh()
                                }
                            }
                        )
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if case .loaded = stateModel.state {
                    if stateModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await stateModel.updateProfile() }
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityIdentifier("profile.save")
                    }
                }
            }
        }
        // The title no longer guesses from the message text ("Failed to upload
        // photo" used to appear under "Success").
        .onChange(of: stateModel.isChangingEmail) { _, isChanging in
            if isChanging { lastLoadedProfile = stateModel.state.value }
        }
        .alert("Profile", isPresented: binding(stateModel, \.ui.isShowingAlert)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stateModel.ui.alertMessage)
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive, action: attemptSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Couldn’t Sign Out", isPresented: $showingSignOutFailure) {
            Button("Retry", action: attemptSignOut)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your account is still signed in. Check your connection and try again.")
        }
        .sheet(
            isPresented: Binding(
                get: { stateModel.isChangingEmail },
                set: { stateModel.isChangingEmail = $0 }
            )
        ) {
            if let profileData = stateModel.state.value ?? lastLoadedProfile {
                ChangeEmailView(stateModel: stateModel, profileData: profileData)
                    .tmiSheetStyle()
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            NavigationStack {
                LegalDocumentView(fileName: "privacy-policy")
                    .navigationTitle("Privacy Policy")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPrivacyPolicy = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingTermsOfService) {
            NavigationStack {
                LegalDocumentView(fileName: "terms-of-service")
                    .navigationTitle("Terms of Service")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingTermsOfService = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingDeleteAccount) {
            DeleteAccountView()
                .tmiSheetStyle()
        }
        .onAppear {
            // Only fetch if we haven't loaded data yet
            if case .idle = stateModel.state {
                Task {
                    await stateModel.fetch()
                }
            }
        }
    }

    /// Signs out through AuthStateModel (invalidating the trusted session),
    /// exactly like the shell — the old path called Firebase directly.
    @MainActor
    private func attemptSignOut() {
        guard authStateModel.signOut() else {
            showingSignOutFailure = true
            return
        }
        studentContext.clearContext()
        router.reset()
    }
}

@ViewBuilder
private func userProfileForm(
    _ profileData: UserProfileData,
    stateModel: UserProfileStateModel,
    dismiss: DismissAction,
    showingPrivacyPolicy: Binding<Bool>,
    showingTermsOfService: Binding<Bool>,
    showingDeleteAccount: Binding<Bool>,
    roleDisplayName: String?,
    onSignOut: @escaping () -> Void
) -> some View {
    Form {
        Section {
            HStack(spacing: TMISpacing.md) {
                profilePhoto(stateModel: stateModel, name: profileData.displayName)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileData.displayName.isEmpty ? "Your profile" : profileData.displayName)
                        .font(.tmiEditorial(.title2))
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(roleDisplayName ?? "Access unavailable")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                    let photoLabel = stateModel.isUploadingPhoto ? "Uploading…" : "Change Photo"
                    PhotosPicker(selection: Bindable(stateModel).selectedPhotoItem, matching: .images) {
                        Label(photoLabel, systemImage: "camera")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(stateModel.isUploadingPhoto)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, TMISpacing.xs)
            .onChange(of: stateModel.selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        stateModel.selectedPhotoData = data
                        await stateModel.uploadProfilePhoto()
                    }
                }
            }
        }

        Section("Profile") {
            LabeledContent("Email") {
                Text(profileData.email)
                    .foregroundStyle(TMIColors.textSecondary)
                    .textSelection(.enabled)
            }
            LabeledContent("Name") {
                TextField("Display name", text: Binding(
                    get: { profileData.displayName },
                    set: { newValue in Task { @MainActor in stateModel.updateDisplayName(newValue) } }
                ))
                .textContentType(.name)
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Organization") {
                TextField("School or district", text: Binding(
                    get: { stateModel.organization },
                    set: { stateModel.organization = $0 }
                ))
                .textContentType(.organizationName)
                .multilineTextAlignment(.trailing)
            }
        }
        .disabled(stateModel.isSaving)

        Section("Account") {
            Button {
                stateModel.isChangingEmail = true
            } label: {
                profileRowLabel("Change Email", symbol: "envelope", tone: .info)
            }
            NavigationLink {
                ChangePasswordView()
            } label: {
                profileRowLabel("Change Password", symbol: "lock", tone: .brand)
            }
        }

        Section("Legal") {
            Button {
                showingPrivacyPolicy.wrappedValue = true
            } label: {
                profileRowLabel("Privacy Policy", symbol: "hand.raised", tone: .neutral)
            }
            Button {
                showingTermsOfService.wrappedValue = true
            } label: {
                profileRowLabel("Terms of Service", symbol: "doc.text", tone: .neutral)
            }
        }

        Section {
            Button(role: .destructive, action: onSignOut) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button(role: .destructive) {
                showingDeleteAccount.wrappedValue = true
            } label: {
                Label("Delete Account…", systemImage: "person.crop.circle.badge.minus")
            }
            .accessibilityHint("Permanently delete your account and personal data")
        } footer: {
            Text("Deleting your account removes your personal data. District records stay with the district.")
        }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
}

private func profileRowLabel(_ title: String, symbol: String, tone: TMITone) -> some View {
    HStack(spacing: TMISpacing.ms) {
        TMIIconTile(symbol, tone: tone, size: 28)
        Text(title)
            .foregroundStyle(TMIColors.textPrimary)
    }
}

/// The picked photo shows immediately (it used to wait behind the old URL
/// until upload finished); otherwise the saved photo, then initials.
@ViewBuilder
private func profilePhoto(stateModel: UserProfileStateModel, name: String) -> some View {
    let size: CGFloat = 72
    if let photoData = stateModel.selectedPhotoData, let image = UIImage(data: photoData) {
#if os(macOS)
        Image(nsImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
#else
        Image(uiImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
#endif
    } else if let photoURLString = stateModel.photoURL, let url = URL(string: photoURLString) {
        WebImage(url: url)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    } else {
        TMIAvatar(
            initials: name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined(),
            size: size
        )
    }
}

struct ChangeEmailView: View {
    let stateModel: UserProfileStateModel
    let profileData: UserProfileData
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !profileData.newEmail.isEmpty && !profileData.currentPassword.isEmpty && !stateModel.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Current", value: profileData.email)
                    TextField("New email", text: Binding(
                        get: { profileData.newEmail },
                        set: { stateModel.updateNewEmail($0) }
                    ))
                    .textContentType(.emailAddress)
#if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()
                } footer: {
                    Text("We’ll send a verification link to the new address.")
                }

                Section {
                    SecureField("Current password", text: Binding(
                        get: { profileData.currentPassword },
                        set: { stateModel.updateCurrentPassword($0) }
                    ))
                    .textContentType(.password)
                    .submitLabel(.done)
                    .onSubmit {
                        if canSave { Task { await stateModel.updateEmail() } }
                    }
                } footer: {
                    Text("Confirm it’s you before changing where your account signs in.")
                }
            }
            .formStyle(.grouped)
            .disabled(stateModel.isLoading)
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if stateModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await stateModel.updateEmail() }
                        }
                        .disabled(!canSave)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tmiMacSheetFrame(minWidth: 440, minHeight: 320)
    }
}

// MARK: - Legal Document View

struct LegalDocumentView: View {
    let fileName: String

    var body: some View {
        LegalDocumentWebView(fileName: fileName)
    }
}

#if os(macOS)
private struct LegalDocumentWebView: NSViewRepresentable {
    let fileName: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }
}
#else
private struct LegalDocumentWebView: UIViewRepresentable {
    let fileName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }
}
#endif

#Preview {
    UserProfileView()
}
