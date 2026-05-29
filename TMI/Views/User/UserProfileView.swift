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
    // MARK: - Dependencies
    private let firebaseManager: FirebaseManager

    // MARK: - Photo State
    var organization: String = ""
    var photoURL: String?
    var selectedPhotoItem: PhotosPickerItem?
    var selectedPhotoData: Data?
    var isUploadingPhoto = false

    // MARK: - Initialization

    init(firebaseManager: FirebaseManager = FIREBASE_MANAGER) {
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
                profileData.role = userData["role"] as? String ?? "student"
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

        updateState(.loading)

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

            // Show success message
            ui.alertMessage = "Profile updated successfully"
            ui.isShowingAlert = true

            // Refresh data to ensure we have the latest
            await fetch()
        } catch {
            let handledError = ErrorHandlingHelper.handleError(error, userFriendlyMessage: "Failed to update profile")
            updateState(.error(handledError))
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Unified Background
            TMIBackgroundView(variant: .base)
                .ignoresSafeArea()

            Group {
                switch stateModel.state {
                case .idle, .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded(let profileData):
                    userProfileForm(
                        profileData,
                        stateModel: stateModel,
                        dismiss: dismiss,
                        showingPrivacyPolicy: $showingPrivacyPolicy,
                        showingTermsOfService: $showingTermsOfService
                    )

                case .error(let error):
                    VStack(spacing: 16) {
                        Text("Error loading profile")
                            .font(.headline)
                            .foregroundColor(Color.tmiTextPrimary)

                        Text(error.message)
                            .foregroundColor(.red)
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
        .foregroundColor(Color.tmiTextPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if case .loaded = stateModel.state {
                    TMIButton(
                        text: "Save",
                        style: .primary,
                        isDisabled: stateModel.isLoading,
                        action: {
                            Task {
                                await stateModel.updateProfile()
                            }
                        }
                    )
                }
            }
        }
        .alert(isPresented: binding(stateModel, \.ui.isShowingAlert)) {
            Alert(
                title: Text(stateModel.ui.alertMessage.contains("Error") ? "Error" : "Success"),
                message: Text(stateModel.ui.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(
            isPresented: Binding(
                get: { stateModel.isChangingEmail },
                set: { stateModel.isChangingEmail = $0 }
            )
        ) {
            if case .loaded(let profileData) = stateModel.state {
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
        .onAppear {
            // Only fetch if we haven't loaded data yet
            if case .idle = stateModel.state {
                Task {
                    await stateModel.fetch()
                }
            }
        }
    }
}

@ViewBuilder
private func userProfileForm(_ profileData: UserProfileData, stateModel: UserProfileStateModel, dismiss: DismissAction, showingPrivacyPolicy: Binding<Bool>, showingTermsOfService: Binding<Bool>) -> some View {
    ScrollView {
        VStack(spacing: 20) {
            // Profile Photo Section
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile Photo")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    HStack(spacing: 16) {
                        if let photoURLString = stateModel.photoURL, let url = URL(string: photoURLString) {
                            WebImage(url: url)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let photoData = stateModel.selectedPhotoData,
                                  let uiImage = UIImage(data: photoData) {
                            #if os(macOS)
                            Image(nsImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            #elseif os(iOS)
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            #endif
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(.secondary)
                        }

                        PhotosPicker(selection: Bindable(stateModel).selectedPhotoItem, matching: .images) {
                            Text("Change Photo")
                        }

                        if stateModel.isUploadingPhoto {
                            ProgressView()
                        }
                    }
                }
            }
            .onChange(of: stateModel.selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        stateModel.selectedPhotoData = data
                        await stateModel.uploadProfilePhoto()
                    }
                }
            }

            // Profile Information Section
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile Information")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    HStack {
                        Text("Email")
                            .foregroundColor(Color.tmiTextPrimary)
                        Spacer()
                        Text(profileData.email)
                            .foregroundColor(Color.tmiTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .foregroundColor(Color.tmiTextPrimary)

                        TMITextField(
                            icon: "person",
                            placeholder: "Display Name",
                            text: Binding(
                                get: { profileData.displayName },
                                set: { newValue in Task { @MainActor in stateModel.updateDisplayName(newValue) } }
                            )
                        )
                    }
                }
            }

            // Role Section (read-only)
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    Text(profileData.role.isEmpty ? "Unknown" : profileData.role)
                        .foregroundStyle(.secondary)
                }
            }

            // Organization Section
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("School / Organization")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    TMITextField(
                        icon: "building.2",
                        placeholder: "Enter your school or organization",
                        text: Binding(
                            get: { stateModel.organization },
                            set: { stateModel.organization = $0 }
                        )
                    )
                }
            }

            // Account Settings Section
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Account Settings")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    TMIButton(
                        text: "Change Email",
                        icon: "envelope",
                        style: .secondary,
                        action: {
                            stateModel.isChangingEmail = true
                        }
                    )

                    NavigationLink(destination: ChangePasswordView()) {
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(Color.tmiPrimary)
                            Text("Change Password")
                                .foregroundColor(Color.tmiTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.tmiTextSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }

            // Legal Section
            TMICard(style: .default) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Legal")
                        .font(.headline)
                        .foregroundColor(Color.tmiTextPrimary)

                    Button {
                        showingPrivacyPolicy.wrappedValue = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(Color.tmiPrimary)
                            Text("Privacy Policy")
                                .foregroundColor(Color.tmiTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.tmiTextSecondary)
                        }
                        .padding(.vertical, 8)
                    }

                    Button {
                        showingTermsOfService.wrappedValue = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(Color.tmiPrimary)
                            Text("Terms of Service")
                                .foregroundColor(Color.tmiTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.tmiTextSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }

            // Sign Out Section
            TMICard(style: .default) {
                TMIButton(
                    text: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    style: .destructive,
                    action: {
                        Task { @MainActor in
                            stateModel.signOut()
                            dismiss()
                        }
                    }
                )
            }
        }
        .padding(20)
    }
}

struct ChangeEmailView: View {
    let stateModel: UserProfileStateModel
    let profileData: UserProfileData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Unified Background
                TMIBackgroundView(variant: .base)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        TMICard(style: .default) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Change Email")
                                    .font(.headline)
                                    .foregroundColor(Color.tmiTextPrimary)

                                TMITextField(
                                    icon: "envelope",
                                    placeholder: "New Email",
                                    text: Binding(
                                        get: { profileData.newEmail },
                                        set: { stateModel.updateNewEmail($0) }
                                    ),
                                    keyboardType: .emailAddress
                                )

                                TMITextField(
                                    icon: "lock",
                                    placeholder: "Current Password",
                                    text: Binding(
                                        get: { profileData.currentPassword },
                                        set: { stateModel.updateCurrentPassword($0) }
                                    ),
                                    isSecure: true
                                )

                                Text("You'll need to verify your new email after changing it.")
                                    .font(.caption)
                                    .foregroundColor(Color.tmiTextSecondary)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(20)
                }

                if stateModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.4))
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(Color.tmiTextPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.tmiTextPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    TMIButton(
                        text: "Save",
                        style: .primary,
                        isDisabled: profileData.newEmail.isEmpty || profileData.currentPassword.isEmpty
                        || stateModel.isLoading,
                        action: {
                            Task {
                                await stateModel.updateEmail()
                            }
                        }
                    )
                }
            }
        }
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

