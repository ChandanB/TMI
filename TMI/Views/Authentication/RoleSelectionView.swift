//
//  RoleSelectionView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct Institution: Identifiable, Equatable {
  let id: String
  let name: String
  let domain: String
  let supportsSSOIntegration: Bool
}

struct RoleSelectionView: View {
  @State private var selectedRole: UserRole?
  @State private var selectedCategory: SimplifiedRoleCategory?
  @State private var showingAgeVerification = false
  @State private var institutionCode = ""
  @State private var selectedInstitution: Institution? = nil
  @State private var appearAnimation = false
  @State private var showingInfoSheet = false
  @State private var showingRegistrationView = false
  @Environment(\.dismiss) private var dismiss

  // Animation states for role cards
  @State private var animateCards = false
  @State private var animateButtons = false

  /// Closure called when registration is complete, passing selected role and institution
  let onRegistrationComplete: ((UserRole?, Institution?) -> Void)?

  // Registration step state removed to simplify flow and avoid multiple sheets

  init(onRegistrationComplete: ((UserRole?, Institution?) -> Void)? = nil) {
    self.onRegistrationComplete = onRegistrationComplete
  }

  var body: some View {
    ZStack {
      // Trauma-informed background
      TMIBackgroundView(variant: .auth)

      ScrollView {
        VStack(spacing: 30) {
          Spacer()
            .frame(minHeight: 40)

          // Trauma-informed welcome section
          TraumaInformedWelcomeSection(showingInfoSheet: $showingInfoSheet)
            .opacity(appearAnimation ? 1.0 : 0)
            .offset(y: appearAnimation ? 0 : 20)
            .animation(
              Animation.spring(response: 0.6, dampingFraction: 0.8)
                .delay(0.2),
              value: appearAnimation
            )

          // Role selection grid
          RoleSelectionGrid(selectedRole: $selectedRole, selectedCategory: $selectedCategory)
            .opacity(animateCards ? 1.0 : 0)
            .offset(y: animateCards ? 0 : 30)
            .animation(
              Animation.spring(response: 0.7, dampingFraction: 0.8)
                .delay(0.4),
              value: animateCards
            )

          // Institution verification section (when applicable)
          if selectedCategory == .staff {
            InstitutionVerificationSection(
              code: $institutionCode,
              selectedInstitution: $selectedInstitution
            )
              .opacity(animateButtons ? 1.0 : 0)
              .offset(y: animateButtons ? 0 : 20)
              .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.8)
                  .delay(0.6),
                value: animateButtons
              )
          }

          // Continue button
          if selectedRole != nil {
            TMIButton(
              text: continueButtonText,
              icon: "arrow.right",
              style: .primary,
              action: proceedWithRole
            )
            .padding(.horizontal, 40)
            .opacity(animateButtons ? 1.0 : 0)
            .offset(y: animateButtons ? 0 : 20)
            .animation(
              Animation.spring(response: 0.6, dampingFraction: 0.8)
                .delay(0.8),
              value: animateButtons
            )
          }

          Spacer()
            .frame(minHeight: 60)
        }
        .padding(.horizontal, 24)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(false)
    .sheet(isPresented: $showingInfoSheet) {
      RoleInformationSheet()
        .preferredColorScheme(.dark)
    }
    .sheet(isPresented: $showingAgeVerification) {
      AgeVerificationView(selectedRole: selectedRole!)
        .preferredColorScheme(.dark)
        .onDisappear {
          // After age verification, proceed to registration
          showingRegistrationView = true
          // Notify about registration start
          onRegistrationComplete?(selectedRole, selectedInstitution)
        }
    }
    // Present the RegistrationView sheet with selected context
    .sheet(isPresented: $showingRegistrationView) {
      RegistrationView()
        .preferredColorScheme(.dark)
    }
    .onAppear {
      // Trigger animations
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        appearAnimation = true
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        animateCards = true
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        animateButtons = true
      }
    }
    .preferredColorScheme(.dark)
  }

  private var continueButtonText: String {
    guard let role = selectedRole else { return "Continue" }

    switch role.requiredVerification {
    case .ageVerification:
      return "Verify Age"
    case .institutionalEmail:
      return "Connect Institution"
    case .professionalCredentials:
      return "Verify Credentials"
    case .guardianConsent:
      return "Request Guardian Consent"
    case .none:
      return "Continue"
    }
  }

  private func proceedWithRole() {
    guard let role = selectedRole else { return }

    switch role.requiredVerification {
    case .ageVerification:
      // Show age verification sheet
      showingAgeVerification = true

    case .institutionalEmail:
      // Always allow progress, initiate background verification if institutionCode or selectedInstitution present
      if !institutionCode.isEmpty || selectedInstitution != nil {
        Task {
          await verifyInstitutionInBackground()
        }
      }
      // Transition directly to registration
      showingRegistrationView = true
      // Notify about registration start
      onRegistrationComplete?(selectedRole, selectedInstitution)

    case .professionalCredentials:
      // Transition directly to registration
      showingRegistrationView = true
      // Notify about registration start
      onRegistrationComplete?(selectedRole, selectedInstitution)

    case .guardianConsent:
      // Transition directly to registration
      showingRegistrationView = true
      // Notify about registration start
      onRegistrationComplete?(selectedRole, selectedInstitution)

    case .none:
      // Transition directly to registration
      showingRegistrationView = true
      // Notify about registration start
      onRegistrationComplete?(selectedRole, selectedInstitution)
    }
  }

  private func verifyInstitutionInBackground() async {
    // Simulate background verification with delay
    print("Starting background institution verification...")
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
    print("Institution verification completed.")
  }
}

// MARK: - Trauma-Informed Welcome Section

struct TraumaInformedWelcomeSection: View {
  @Binding var showingInfoSheet: Bool

  var body: some View {
    VStack(spacing: 16) {
      // Safe, welcoming icon
      Image(systemName: "heart.circle.fill")
        .font(.system(size: 50))
        .foregroundColor(Color.tmiSecondary)

      Text("Welcome to TMI")
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)

      Text("A safe space for learning and growth")
        .font(.system(size: 16))
        .foregroundColor(.white.opacity(0.8))
        .multilineTextAlignment(.center)

      VStack(spacing: 8) {
        Text(
          "Help us understand how you'll be using TMI so we can provide the right protections and support for you."
        )
        .font(.system(size: 14))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)

        Button(action: {
          showingInfoSheet = true
        }) {
          HStack(spacing: 4) {
            Image(systemName: "info.circle")
            Text("Why do we ask this?")
          }
          .font(.system(size: 12))
          .foregroundColor(Color.tmiSecondary)
        }
      }
    }
    .padding(.bottom, 10)
  }
}

// MARK: - Simplified Role Category

enum SimplifiedRoleCategory: String, CaseIterable, Identifiable {
  case student = "student"
  case staff = "staff"
  case parentGuardian = "parent_guardian"
  
  var id: String { rawValue }
  
  var displayName: String {
    switch self {
    case .student: return "Student"
    case .staff: return "Staff"
    case .parentGuardian: return "Parent/Guardian"
    }
  }
  
  var iconName: String {
    switch self {
    case .student: return "graduationcap"
    case .staff: return "person.badge.key"
    case .parentGuardian: return "figure.2.and.child.holdinghands"
    }
  }
  
  var shortDescription: String {
    switch self {
    case .student: return "Learning and growing"
    case .staff: return "Educator or administrator"
    case .parentGuardian: return "Supporting my child"
    }
  }
  
  var defaultUserRole: UserRole {
    switch self {
    case .student: return .student
    case .staff: return .teacher
    case .parentGuardian: return .parent
    }
  }
  
  var requiresInstitutionalAffiliation: Bool {
    switch self {
    case .staff: return true
    case .student, .parentGuardian: return false
    }
  }
}

// MARK: - Role Selection Grid

struct RoleSelectionGrid: View {
  @Binding var selectedRole: UserRole?
  @Binding var selectedCategory: SimplifiedRoleCategory?

  private let categories = SimplifiedRoleCategory.allCases

  var body: some View {
    TMIGlassCard(style: .form) {
      VStack(spacing: 20) {
        Text("I am a...")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.white)

        LazyVGrid(
          columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
          ], spacing: 12
        ) {
          ForEach(categories, id: \.self) { category in
            SimplifiedRoleSelectionCard(
              category: category,
              isSelected: selectedCategory == category,
              onTap: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                  selectedCategory = category
                  selectedRole = category.defaultUserRole
                }
              }
            )
          }
        }
      }
      .padding(.vertical, 10)
    }
    .padding(.horizontal, 20)
  }
}

// MARK: - Simplified Role Selection Card

struct SimplifiedRoleSelectionCard: View {
  let category: SimplifiedRoleCategory
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 12) {
        // Role icon
        Image(systemName: category.iconName)
          .font(.system(size: 28))
          .foregroundColor(isSelected ? Color.tmiPrimary : .white.opacity(0.8))

        // Role name
        Text(category.displayName)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(isSelected ? .white : .white.opacity(0.9))
          .multilineTextAlignment(.center)

        // Role description
        Text(category.shortDescription)
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.6))
          .multilineTextAlignment(.center)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 120)
      .padding(.horizontal, 12)
      .padding(.vertical, 16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(
            isSelected ? Color.tmiSecondary.opacity(0.3) : Color.white.opacity(0.1)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                isSelected ? Color.tmiSecondary : Color.white.opacity(0.2),
                lineWidth: isSelected ? 2 : 1
              )
          )
      )
    }
    .scaleEffect(isSelected ? 1.05 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
  }
}

// MARK: - Institution Verification Section

struct InstitutionVerificationSection: View {
  @Binding var code: String
  @Binding var selectedInstitution: Institution?
  @State private var showingInstitutionSearch = false

  var body: some View {
    TMIGlassCard(style: .form) {
      VStack(spacing: 16) {
        HStack {
          Image(systemName: "building.2")
            .font(.system(size: 20))
            .foregroundColor(Color.tmiSecondary)

          Text("Connect with your institution")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)

          Spacer()
        }

        Text(
          "To verify your role and provide appropriate access, we need to connect you with your educational institution."
        )
        .font(.system(size: 14))
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.leading)

        TMITextField(
          icon: "number",
          placeholder: "Institution Code",
          text: Binding(
            get: {
              selectedInstitution?.name ?? code
            },
            set: { newValue in
              // If user edits manual entry, clear selectedInstitution
              selectedInstitution = nil
              code = newValue
            }
          ),
          keyboardType: .default
        )

        Button(action: {
          showingInstitutionSearch = true
        }) {
          HStack {
            Image(systemName: "magnifyingglass")
            Text("Search for your institution")
          }
          .font(.system(size: 14))
          .foregroundColor(Color.tmiSecondary)
        }
        .padding(.top, 4)
      }
    }
    .padding(.horizontal, 20)
    .sheet(isPresented: $showingInstitutionSearch) {
      InstitutionSearchView(selectedInstitution: $selectedInstitution)
        .preferredColorScheme(.dark)
        .onDisappear {
          // When institution is selected, update code accordingly
          if let selected = selectedInstitution {
            code = selected.name
          }
        }
    }
  }
}

// MARK: - Age Verification View

struct AgeVerificationView: View {
  let selectedRole: UserRole
  @State private var dateOfBirth = Date()
  @State private var isValidAge = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .auth)

        VStack(spacing: 30) {
          Spacer()

          // Trauma-informed age verification explanation
          VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
              .font(.system(size: 40))
              .foregroundColor(Color.tmiSecondary)

            Text("Age Verification")
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.white)

            Text(
              "We need to verify your age to ensure we provide the right protections and follow important privacy laws that keep you safe."
            )
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
          }

          // Date picker in a glass card
          TMIGlassCard(style: .form) {
            VStack(spacing: 20) {
              Text("What's your date of birth?")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

              DatePicker(
                "Date of Birth",
                selection: $dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
              )
              .datePickerStyle(.wheel)
              .colorScheme(.dark)
              .onChange(of: dateOfBirth) { _, newValue in
                validateAge(newValue)
              }
              .onAppear {
                validateAge(dateOfBirth)
              }

              if isValidAge {
                HStack {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                  Text("Age verified successfully")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                }
                .padding(.top, 8)
              }
            }
            .padding(.vertical, 10)
          }
          .padding(.horizontal, 30)

          // Continue button
          if isValidAge {
            TMIButton(
              text: "Continue",
              icon: "arrow.right",
              style: .primary,
              action: {
                // Continue to next step
                dismiss()
              }
            )
            .padding(.horizontal, 40)
          }

          Spacer()
        }
      }
      .navigationTitle("Age Verification")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(false)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Back") {
            dismiss()
          }
          .foregroundColor(Color.tmiSecondary)
        }
      }
    }
  }

  private func validateAge(_ date: Date) {
    let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0

    // Different age requirements based on role
    switch selectedRole {
    case .student:
      isValidAge = age >= 4 && age <= 25
    case .teacher, .counselor, .administrator, .socialWorker:
      isValidAge = age >= 18
    case .parent, .legalGuardian:
      isValidAge = age >= 18
    default:
      isValidAge = age >= 13
    }
  }
}

// MARK: - Institution Search View

struct InstitutionSearchView: View {
  @Binding var selectedInstitution: Institution?
  @State private var searchText = ""
  @State private var institutions: [Institution] = InstitutionSearchView.sampleInstitutions
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .auth)

        VStack(spacing: 20) {
          // Search bar
          TMITextField(
            icon: "magnifyingglass",
            placeholder: "Search institutions...",
            text: $searchText
          )
          .padding(.horizontal, 20)
          .padding(.top, 20)

          // Institution list
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(filteredInstitutions, id: \.id) { institution in
                InstitutionCard(institution: institution) {
                  selectedInstitution = institution
                  dismiss()
                }
              }
            }
            .padding(.horizontal, 20)
          }
        }
      }
      .navigationTitle("Find Your Institution")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(Color.tmiSecondary)
        }
      }
    }
  }

  private var filteredInstitutions: [Institution] {
    if searchText.isEmpty {
      return institutions
    } else {
      return institutions.filter { institution in
        institution.name.localizedCaseInsensitiveContains(searchText)
      }
    }
  }

  private static let sampleInstitutions: [Institution] = [
    Institution(
      id: "1", name: "Roosevelt Elementary School", domain: "roosevelt.edu",
      supportsSSOIntegration: true),
    Institution(
      id: "2", name: "Lincoln Middle School", domain: "lincoln.edu", supportsSSOIntegration: false),
    Institution(
      id: "3", name: "Washington High School", domain: "washington.edu",
      supportsSSOIntegration: true),
    Institution(
      id: "4", name: "Jefferson County School District", domain: "jefferson.edu",
      supportsSSOIntegration: true),
  ]
}

// MARK: - Institution Card

struct InstitutionCard: View {
  let institution: Institution
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      TMIGlassCard(style: .form) {
        HStack(spacing: 16) {
          Image(systemName: "building.2")
            .font(.system(size: 24))
            .foregroundColor(Color.tmiSecondary)

          VStack(alignment: .leading, spacing: 4) {
            Text(institution.name)
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white)
              .multilineTextAlignment(.leading)

            Text(institution.domain)
              .font(.system(size: 14))
              .foregroundColor(.white.opacity(0.7))

            if institution.supportsSSOIntegration {
              HStack {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
                Text("SSO Supported")
                  .font(.system(size: 12))
                  .foregroundColor(.green)
              }
            }
          }

          Spacer()

          Image(systemName: "arrow.right")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 4)
      }
    }
  }
}

// MARK: - Role Information Sheet

struct RoleInformationSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        TMIBackgroundView(variant: .auth)

        ScrollView {
          VStack(spacing: 24) {
            Text("Why We Ask About Your Role")
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.white)
              .padding(.top, 20)

            VStack(spacing: 20) {
              InfoCard(
                icon: "shield.checkered",
                title: "Privacy Protection",
                description:
                  "Different roles require different privacy protections. Students under 13 need special COPPA protections, while educators need FERPA compliance."
              )

              InfoCard(
                icon: "person.2.badge.gearshape",
                title: "Appropriate Access",
                description:
                  "Your role determines what information you can access and what features are available to you, ensuring everyone stays safe."
              )

              InfoCard(
                icon: "heart.text.square",
                title: "Trauma-Informed Support",
                description:
                  "We provide different types of support and resources based on your role and needs in the educational environment."
              )

              InfoCard(
                icon: "checkmark.shield",
                title: "Legal Compliance",
                description:
                  "We follow strict educational privacy laws (COPPA, FERPA) that require us to handle different user types appropriately."
              )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
          }
        }
      }
      .navigationTitle("Role Information")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(Color.tmiSecondary)
        }
      }
    }
  }
}

// MARK: - Info Card

struct InfoCard: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    TMIGlassCard(style: .form) {
      HStack(spacing: 16) {
        Image(systemName: icon)
          .font(.system(size: 24))
          .foregroundColor(Color.tmiSecondary)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 8) {
          Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)

          Text(description)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.leading)
        }

        Spacer()
      }
      .padding(.horizontal, 4)
    }
  }
}

// MARK: - UserRole Extensions (Legacy - for compatibility)

extension UserRole {
  var iconName: String {
    switch self {
    case .student: return "graduationcap"
    case .teacher: return "person.chalkboard"
    case .counselor: return "heart.circle"
    case .administrator, .admin: return "person.badge.key"
    case .socialWorker: return "person.2.circle"
    case .parent: return "figure.2.and.child.holdinghands"
    case .legalGuardian: return "person.crop.circle.badge.checkmark"
    default: return "person"
    }
  }

  var shortDescription: String {
    switch self {
    case .student: return "Learning and growing"
    case .teacher: return "Educating students"
    case .counselor: return "Supporting wellbeing"
    case .administrator, .admin: return "Managing institution"
    case .socialWorker: return "Providing social support"
    case .parent: return "Supporting my child"
    case .legalGuardian: return "Legal guardian"
    default: return "User"
    }
  }
}

// MARK: - Preview

#Preview {
  RoleSelectionView()
    .preferredColorScheme(.dark)
}

