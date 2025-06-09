//
//  FeatureOverlayStateModel.swift
//  The Social Point
//

import SwiftUI
import Observation
import FirebaseFirestore

// MARK: - Environment Key

struct FeatureOverlayStateModelKey: EnvironmentKey {
    static let defaultValue: UnlockedFeaturesOverlayStateModel = UnlockedFeaturesOverlayStateModel()
}

extension EnvironmentValues {
    var unlockedfeaturesOverlayStateModel: UnlockedFeaturesOverlayStateModel {
        get { self[FeatureOverlayStateModelKey.self] }
        set { self[FeatureOverlayStateModelKey.self] = newValue }
    }
}

// MARK: - Feature Activation Result

enum FeatureActivationResult: Equatable {
    case success
    case onCooldown(remainingTime: TimeInterval)
    case insufficientPoints(required: Int, available: Int)
    case requirementsNotMet
    case error(String)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var feedbackMessage: String {
        switch self {
        case .success:
            return "Feature activated!"
        case .onCooldown(let time):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .abbreviated
            let timeString = formatter.string(from: time) ?? "\(Int(time))s"
            return "On cooldown: \(timeString) remaining"
        case .insufficientPoints(let required, let available):
            return "Insufficient SP: \(required) required, \(available) available"
        case .requirementsNotMet:
            return "You don't meet the requirements for this feature"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}


// MARK: - Feature Activation Feedback

struct FeatureActivationFeedback: Equatable, Identifiable {
    let id = UUID()
    let feature: Feature
    let result: FeatureActivationResult
    let timestamp = Date()
}

// MARK: - State Model

@Observable
final class UnlockedFeaturesOverlayStateModel: BaseStateModel<Account, IdentifiableError> {
    // MARK: - UI State
    
    var isExpanded = false
    var animateExpansion = false
    var showingCreateContentSheet = false
    
    // Animation states for enhanced UI
    var animationStage: Int = 0
    var isShowingActivationFeedback = false
    
    // MARK: - Feature State
    
    // All features potentially relevant to the user's class/subclass
    private(set) var allFeatures: [Feature] = []
    // Cooldowns for features keyed by feature ID
    private(set) var featureCooldowns: [String: FeatureCooldownInfo] = [:]
    // Feedback on the last activation attempt
    private(set) var lastActivationResult: FeatureActivationFeedback?
    
    // Active feature effects tracking keyed by feature ID
    private(set) var activeEffects: [String: Date] = [:]
    
    // Property to track the currently selected feature type for filtering
    var selectedFeatureType: FeatureFunctionalType?
    
    // MARK: - Computed Feature Lists (Filtered from allFeatures)
    
    /// Features the user currently meets the requirements for (level, stats)
    var availableFeatures: [Feature] {
        guard let account = currentAccount, let stats = account.userStats else { return [] }
        return allFeatures
            .filter { $0.meetsRequirements(userLevel: account.level, userStats: stats, userVouches: account.vouches).meets }
            .sorted { $0.definition.impactLevel.rawValue > $1.definition.impactLevel.rawValue } // Sort by impact level
    }
    
    var availablePassiveFeatures: [Feature] {
        availableFeatures.filter { $0.isPassive }
                         .sorted { $0.definition.impactLevel.rawValue > $1.definition.impactLevel.rawValue }
    }
    
    var availableActiveFeatures: [Feature] {
        availableFeatures.filter { $0.definition.activationType == .active }
                         .sorted { $0.definition.impactLevel.rawValue > $1.definition.impactLevel.rawValue }
    }
    
    var availableUltimateFeatures: [Feature] {
        availableFeatures.filter { $0.isUltimate }
                         .sorted { $0.definition.impactLevel.rawValue > $1.definition.impactLevel.rawValue }
    }
    
    /// Features with active, non-expired effects
    var activeEffectFeatures: [Feature] {
        let now = Date()
        let activeFeatureIDs = activeEffects.filter { $1 > now }.keys
        
        return allFeatures.filter { feature in
            activeFeatureIDs.contains(feature.id)
        }
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthService
    private let userRepository: UserRepository
    private let postFeedStateModel: PostFeedStateModel // Consider if this is truly needed here or passed in activation
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private let logger: Logger
    
    private let featureRepository: FeatureRepository
    
    // MARK: - Initialization
    
    init(
        authService: AuthService = DependencyContainer.shared.authService,
        userRepository: UserRepository = DependencyContainer.shared.userRepository,
        featureRepository: FeatureRepository = DependencyContainer.shared.featureRepository,
        postFeedStateModel: PostFeedStateModel = PostFeedStateModel(),
        logger: Logger = Logger(category: "FeatureOverlay")
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.featureRepository = featureRepository
        self.postFeedStateModel = postFeedStateModel
        self.logger = logger
        
        super.init()
        
        Task { @MainActor in
            await fetch()
            startCooldownMonitoring()
        }
    }
    
    // MARK: - Data Fetching
    
    @MainActor
    override func fetch() async {
        if case .loading = state { return }
        updateState(.loading)
        
        do {
            // Attempt to get the account from authService first
            if let account = authService.currentUserAccount {
                updateState(.loaded(account))
                await refreshFeaturesAndCooldowns(for: account)
            } else {
                // If not available, maybe fetch from repository (depends on your auth flow)
                // This path might indicate an issue if authService should always have the account
                 guard let userId = authService.currentUserID else {
                     throw FirebaseError.userNotAuthenticated
                 }
                let account = try await userRepository.fetchUser(id: userId)
                 updateState(.loaded(account))
                 await refreshFeaturesAndCooldowns(for: account)
            }
            
        } catch {
            let identifiableError = ErrorHandlingHelper.handleRepositoryError(error)
            logger.error("Failed to fetch user account: \(identifiableError.localizedDescription)")
            updateState(.error(identifiableError))
        }
    }
    
    @MainActor
    private func refreshFeaturesAndCooldowns(for account: Account) async {
        // Fetch/update features based on the account
        await loadFeatures(for: account)
        
        // Fetch/update cooldowns (consider if this needs to be fetched or is managed locally)
        // For now, we assume cooldowns are managed locally and cleared on fetch/app start
        clearExpiredCooldowns()
        
        // TODO: Fetch activeEffects from persistence if needed, or assume they are managed locally
        clearExpiredEffects()
    }
    
    // MARK: - UI Controls
    
    @MainActor
    func toggleExpansion() {
        isExpanded.toggle()
        
        if isExpanded {
            // Prepare animations when expanding
            animationStage = 0
            
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                animateExpansion = true
                
                // Staggered animation stages for different feature categories
                for stage in 1...3 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds per stage
                    animationStage = stage
                }
            }
        } else {
            // Reset animation state when collapsing
            animateExpansion = false
            animationStage = 0
        }
    }
    
    @MainActor
    func showCreateContent() {
        showingCreateContentSheet = true
        isExpanded = false
        animateExpansion = false
    }
    
    @MainActor
    func hideCreateContent() {
        showingCreateContentSheet = false
    }
    
    // MARK: - Feature Management
    
    // Modify loadFeatures to also check unlocked features from repository
    @MainActor
    private func loadFeatures(for account: Account) async {
        let userClass = account.userClass
        let userSubclass = account.userSubclass
        
        logger.debug("Loading features for class \(userClass.rawValue) and subclass \(userSubclass.rawValue)")
        
        // Combine features from the main class and the subclass's unique feature
        var combinedFeatures = userClass.uniqueFeatures
        combinedFeatures.append(userSubclass.uniqueFeature)
        
        // Remove duplicates just in case (based on ID)
        var classFeatures = Array(Set(combinedFeatures))
        
        // Pre-sort all features by impact level (descending) for consistent ordering
        classFeatures.sort { $0.definition.impactLevel.rawValue > $1.definition.impactLevel.rawValue }
        
        // Now check for additional unlocked features from the repository
        if let userId = account.id {
            do {
                // Get unlocked features for each feature type
                let unlockedFeatureIds = try await featureRepository.getUserUnlockedFeatures(userID: userId)
                
                logger.info("Found \(unlockedFeatureIds.count) unlocked features from repository")
                
                // TODO: Convert unlocked feature IDs to Feature objects
                // This requires mapping between repository feature IDs and your Feature model
                // You may need to add a method to convert or fetch the full Feature objects
                
                // For now, we'll just use the class features
                self.allFeatures = classFeatures
                
                logger.info("Loaded \(self.allFeatures.count) total features for user's class/subclass.")
            } catch {
                logger.error("Failed to load unlocked features: \(error.localizedDescription)")
                // Fall back to just using class features
                self.allFeatures = classFeatures
            }
        } else {
            // No user ID, just use class features
            self.allFeatures = classFeatures
            logger.info("Loaded \(self.allFeatures.count) total features for user's class/subclass.")
        }
    }
    
    @MainActor
    func isFeatureUnlocked(_ feature: Feature) async -> Bool {
        guard let userId = currentAccount?.id else {
            return false
        }

        do {
            return try await featureRepository.isFeatureUnlocked(
                featureIdentifier: feature.featureID,
                userID: userId
            )
        } catch {
            logger.error("isFeatureUnlocked failed: \(error)")
            return false
        }
    }

    
    @MainActor
    func unlockFeature(_ feature: Feature) async -> Bool {
        guard let userId = currentAccount?.id else { return false }
        
        let featureID = feature.featureID
        
        do {
            let result = try await featureRepository.unlockFeature(
                featureIdentifier: featureID,
                userID: userId
            )
            
            if result {
                logger.info("Successfully unlocked feature: \(feature.name)")
                // Refresh features to include the newly unlocked one
                if let account = currentAccount {
                    await refreshFeaturesAndCooldowns(for: account)
                }
            } else {
                logger.warning("Failed to unlock feature: \(feature.name) - requirements not met")
            }
            
            return result
        } catch {
            logger.error("Error unlocking feature: \(error.localizedDescription)")
            return false
        }
    }
    
    // Modify validateFeatureActivationPrerequisites to also check if feature is unlocked
    private func validateFeatureActivationPrerequisites(_ feature: Feature, account: Account) -> FeatureActivationResult {
        let featureId = feature.id
        
        // Check cooldown
        if let cooldownInfo = featureCooldowns[featureId], cooldownInfo.isActive() {
            return .onCooldown(remainingTime: cooldownInfo.remainingTime())
        }
        
        // Check cost (Social Points)
        if let cost = feature.activationParams.socialPointsCost, cost > 0, account.socialPoints < cost {
            return .insufficientPoints(required: cost, available: account.socialPoints)
        }
        
        // Check requirements (Level, Stats, Vouches)
        if let stats = account.userStats, !feature.meetsRequirements(userLevel: account.level, userStats: stats, userVouches: account.vouches).meets {
            return .requirementsNotMet
        }
        
        // For features that need to be unlocked via the repository, check unlock status
        // This would be an async call, but validateFeatureActivationPrerequisites is sync
        // You might need to restructure this to be async or cache unlock status
        
        return .success // All checks passed
    }
    
    // MARK: - Feature Activation
    
    @MainActor
    func activateFeature(_ feature: Feature) async -> FeatureActivationResult {
        guard let account = currentAccount else {
            logger.error("Activation failed: No current account.")
            return .error("User account not available.")
        }
        
        let featureId = feature.id
        
        logger.debug("Attempting to activate feature: \(feature.name) (\(featureId))")
        
        // 1. Validate prerequisites
        let validationResult = validateFeatureActivationPrerequisites(feature, account: account)
        guard validationResult.isSuccess else {
            lastActivationResult = FeatureActivationFeedback(feature: feature, result: validationResult)
            feedbackGenerator.notificationOccurred(.error)
            logger.warning("Activation failed for \(feature.name): \(validationResult.feedbackMessage)")
            return validationResult
        }
        
        // 2. Perform updates (deduct cost, set cooldown, log)
        do {
            try await performFeatureActivationUpdates(feature, account: account)
            
            // 3. Apply effects
            applyFeatureEffects(feature)
            
            // 4. Refresh user data state locally (important after updates)
            await fetch() // Re-fetch to get updated points, etc.
            
            // 5. Provide success feedback
            let result = FeatureActivationResult.success
            lastActivationResult = FeatureActivationFeedback(feature: feature, result: result)
            showActivationFeedbackBriefly()
            feedbackGenerator.notificationOccurred(.success)
            logger.info("Successfully activated feature: \(feature.name)")
            
            return result
            
        } catch {
            let errorMessage = ErrorHandlingHelper.handleRepositoryError(error).localizedDescription
            let result = FeatureActivationResult.error(errorMessage)
            lastActivationResult = FeatureActivationFeedback(feature: feature, result: result)
            feedbackGenerator.notificationOccurred(.error)
            logger.error("Error during feature activation updates for \(feature.name): \(errorMessage)")
            return result
        }
    }
    
    /// Updates user data (points, cooldowns, logs) after successful validation.
    @MainActor
    private func performFeatureActivationUpdates(_ feature: Feature, account: Account) async throws {
        let featureId = feature.id
        
        guard let userId = account.id else {
            throw IdentifiableError(message: "Invalid user ID for update.")
        }
        
        var updates: [String: Any] = [:]
        
        // Deduct cost
        if let cost = feature.activationParams.socialPointsCost, cost > 0 {
            updates["socialPoints"] = FieldValue.increment(Int64(-cost))
            logger.debug("Prepared update to deduct \(cost) SP.")
        }
        // TODO: Add other cost deductions if needed
        
        // Update Firestore if there are cost changes
        if !updates.isEmpty {
            try await userRepository.update(userID: userId, with: updates)
        }
        
        // Set cooldown locally
        if let cooldown = feature.activationParams.cooldownSeconds, cooldown > 0 {
            let expiresAt = Date().addingTimeInterval(cooldown)
            featureCooldowns[featureId] = FeatureCooldownInfo(
                featureId: featureId,
                expiresAt: expiresAt,
                totalCooldown: cooldown
            )
            logger.debug("Set local cooldown for \(feature.name): \(cooldown) seconds")
            // TODO: Consider persisting cooldowns if needed across app sessions
        }
        
        // Log activation activity
        _ = try await userRepository.logUserActivity(
            userID: userId,
            activityType: .featureActivation,
            metadata: [
                "featureId": featureId,
                "featureName": feature.name,
                "activationType": feature.definition.activationType.rawValue,
                "functionalCategory": feature.definition.functionalCategory.rawValue,
                "socialPointsCost": feature.activationParams.socialPointsCost ?? 0,
                "impactLevel": feature.definition.impactLevel.rawValue
            ].anyCodable
        )
        logger.debug("Logged activation activity for \(feature.name)")
    }
    
    /// Shows the activation feedback UI element temporarily.
    @MainActor
    private func showActivationFeedbackBriefly() {
        isShowingActivationFeedback = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            if Task.isCancelled { return }
            isShowingActivationFeedback = false
        }
    }
    
    // MARK: - Effect Application
    
    @MainActor // Mark MainActor if it modifies @Observable state or calls MainActor functions
    private func applyFeatureEffects(_ feature: Feature) {
        guard let account = currentAccount, let accountId = account.id else {
            logger.warning("Cannot apply feature effects: invalid account")
            return
        }
        
        let featureId = feature.id
        
        logger.debug("Applying effects for feature: \(feature.name)")
        
        // Set expiration time for temporary effects if applicable
        if let duration = feature.activationParams.effectDurationSeconds, duration > 0 {
            let expiresAt = Date().addingTimeInterval(duration)
            activeEffects[featureId] = expiresAt // Track effect expiration locally
            logger.debug("Tracking effect expiration for \(feature.name) at \(expiresAt)")
             // TODO: Persist activeEffects if they need to survive app restarts
        }
        
        // Apply effects based on functional category and specific effect targets
        handleEffectsByFunctionalCategory(feature, accountId: accountId)
        
        // Apply specific listed effects
        for effect in feature.effects.effects {
            handleSpecificEffectTarget(effect, feature: feature, accountId: accountId)
        }
    }
    
    @MainActor
    private func handleEffectsByFunctionalCategory(_ feature: Feature, accountId: String) {
        logger.debug("Handling effects based on functional category: \(feature.definition.functionalCategory.rawValue)")
        
        switch feature.definition.functionalCategory {
        case .social, .community, .networking:
            // Effects related to social interactions, reach, etc.
            // Example: Refresh feed if reach/engagement is affected
            if feature.effects.effects.contains(where: { $0.target == .engagement || $0.target == .reach || $0.target == .contentReachMultiplier }) {
                Task {
                    await postFeedStateModel.refresh() // Assuming this is safe to call
                    logger.debug("Refreshed post feed due to social/community/networking effect.")
                }
            }
            
        case .contentCreation:
            // Effects related to creating content (cost reduction, quality boost?) handled by specific effects
            break
            
        case .profileCustomization:
            // Effects usually passive, handled by specific effects or flags
             break
            
        case .analytics:
            // Might grant temporary access to data or insights
            break
            
        case .monetization:
            // Effects related to points, tipping, etc., handled by specific effects
            break
            
        case .utility:
            // Handle general utility effects like cooldown reduction
            if feature.effects.effects.contains(where: { $0.target == .cooldownReduction }) {
                 reduceCooldowns(feature)
             }
            
        default :
            break
        }
        
        // Handle temporary stat boosts if the feature provides them
        if let stats = currentAccount?.userStats, feature.effects.effects.contains(where: { $0.target.isStatRelated }) {
             handleTemporaryStatBoosts(feature, currentStats: stats, accountId: accountId)
        }
    }
    
    @MainActor
    private func handleTemporaryStatBoosts(_ feature: Feature, currentStats: UserAttributes, accountId: String) {
        let featureId = feature.id
        
        var boostedStats = currentStats // Start with current stats
        var didBoost = false
        
        for effect in feature.effects.effects where effect.target.isStatRelated {
            // Apply the boost logic (this depends on how effects are defined, assuming additive for now)
            // Example: If effect.target is .charisma, add effect.value
             switch effect.target {
                 default: break
             }
            didBoost = true
            logger.debug("Applied temporary boost to \(effect.target.rawValue) by \(effect.value)")
        }
        
        // If stats were boosted and there's a duration, store temporarily
        if didBoost, let duration = feature.activationParams.effectDurationSeconds, duration > 0, let expirationDate = activeEffects[featureId] {
            // TODO: Persist temporary boosts if needed beyond local state.
            // For now, we rely on activeEffects dictionary to know when the boost expires.
            // The actual application of the boosted stats would happen wherever stats are read,
            // checking if a relevant feature ID exists in activeEffects.
            logger.info("Temporary stat boosts for feature \(featureId) are active until \(expirationDate).")
            // Example: Store in Firestore (consider structure carefully)
            /*
            Task {
                do {
                    try await userRepository.update(
                        userID: accountId,
                        with: [
                            "tempStatBoosts": [ // Or a subcollection
                                featureId: [
                                    "expiresAt": expirationDate,
                                    "stats": boostedStats.asDictionary() // Assuming UserStats has this method
                                ]
                            ]
                        ]
                    )
                    logger.debug("Persisted temporary stat boosts for \(featureId)")
                } catch {
                    logger.error("Failed to persist temporary stat boosts: \(error.localizedDescription)")
                }
            }
             */
        }
    }
    
    
    private func handlePassiveFeatureEffects(_ feature: Feature, accountId: String) {
         // Passive effects are generally always active if unlocked.
         // Their impact might be checked directly where relevant (e.g., checking post cost logic).
         // We might set a flag on the user account if needed for optimization.
        logger.debug("Handling passive feature effects for \(feature.name) - likely checked elsewhere.")
    }
    
    
    @MainActor // Mark MainActor if it modifies @Observable state
    private func handleSpecificEffectTarget(_ effect: FeatureEffect, feature: Feature, accountId: String) {
        let featureId = feature.id
        logger.debug("Handling specific effect target: \(effect.target.description) with value \(effect.value)")
        
        let expirationDate: Date? = { // Calculate expiration only if there's a duration
             if let duration = feature.activationParams.effectDurationSeconds, duration > 0 {
                 return activeEffects[featureId] // Use the already calculated expiration time
             }
             return nil
         }()
        
        // Prepare updates for Firestore if persistence is needed for the effect's duration
        var updates: [String: Any] = [:]
        let requiresUpdate = true // Assume update needed unless effect is purely local/instantaneous
        
        switch effect.target {
        case .followerGainRate:
            updates["followerGainMultiplier"] = max(1, effect.value) // Ensure multiplier is at least 1
            if let expirationDate = expirationDate { updates["followerGainExpiresAt"] = expirationDate }
            
        case .socialPoints, .influencePoints:
            let field = effect.target == .socialPoints ? "spGainMultiplier" : "ipGainMultiplier"
            updates[field] = max(1, effect.value)
             if let expirationDate = expirationDate { updates["\\(field)ExpiresAt"] = expirationDate }
            
        case .contentReachMultiplier:
            updates["contentReachMultiplier"] = max(1, effect.value)
             if let expirationDate = expirationDate { updates["contentReachExpiresAt"] = expirationDate }
            
        case .postCost: // This is likely a passive effect modifier, checked elsewhere
             logger.debug("Post cost modifier effect noted for \(feature.name).")
            // requiresUpdate = false // No direct update needed here, logic applied at posting time
             break
            
        case .cooldownReduction: // Handled in reduceCooldowns called from handleUtilityFeatureEffects
             logger.debug("Cooldown reduction effect handled separately.")
             // requiresUpdate = false
             break
            
        case .xp: // Grant XP directly
             updates["xp"] = FieldValue.increment(Int64(effect.value))
             logger.debug("Granting \(effect.value) XP.")
            
        // Add cases for other specific EffectTargets (visibility, engagement, contentQuality, etc.)
        // How these are applied depends heavily on the system design (e.g., flags, direct value changes)
            
        default:
            // If the target is a stat, it's handled by handleTemporaryStatBoosts
            if !effect.target.isStatRelated {
                 logger.warning("Unhandled specific effect target: \(effect.target.rawValue)")
                 // requiresUpdate = false
            } else {
                 // Stat boosts are handled, no direct update here
                 // requiresUpdate = false
            }
        }
        
        // Perform Firestore update if needed and updates dictionary is not empty
        if requiresUpdate && !updates.isEmpty {
            Task {
                do {
                    try await userRepository.update(userID: accountId, with: updates)
                    logger.debug("Applied specific effect updates for \(feature.name) to Firestore.")
                } catch {
                    logger.error("Failed to apply specific effect updates for \(feature.name): \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor // Mark MainActor as it modifies featureCooldowns (@Observable)
    private func reduceCooldowns(_ feature: Feature) {
        // Find cooldown reduction effect
        guard let reductionEffect = feature.effects.effects.first(where: { $0.target == .cooldownReduction }) else { return }
        
        let reductionPercentage = Double(reductionEffect.value) / 100.0
        guard reductionPercentage > 0 else { return }
        
        logger.debug("Applying cooldown reduction of \(reductionEffect.value)%")
        
        let now = Date()
        for (featureId, cooldownInfo) in featureCooldowns where cooldownInfo.isActive() {
            // Don't reduce the cooldown of the feature causing the reduction
            if featureId == feature.id { continue }
            
            let remainingTime = cooldownInfo.remainingTime(now: now)
            let reductionAmount = remainingTime * reductionPercentage
            
            if reductionAmount >= 1.0 { // Only apply if reduction is at least 1 second
                let newExpiresAt = now.addingTimeInterval(remainingTime - reductionAmount)
                
                // Update cooldown with reduced time
                featureCooldowns[featureId] = FeatureCooldownInfo(
                    featureId: featureId,
                    expiresAt: newExpiresAt,
                    totalCooldown: cooldownInfo.totalCooldown // Keep original total for progress calculation
                )
                logger.debug("Reduced cooldown for feature \(featureId) by \(Int(reductionAmount)) seconds. New expiry: \(newExpiresAt)")
            }
        }
    }
    
    // MARK: - Cooldown Management
    
    @MainActor
    func getRemainingCooldown(for feature: Feature) -> TimeInterval? {
        let featureId = feature.featureID.rawValue
        
        guard let cooldownInfo = featureCooldowns[featureId], cooldownInfo.isActive() else {
            return nil
        }
        
        return cooldownInfo.remainingTime()
    }
    
    @MainActor
    func clearExpiredCooldowns() {
        let now = Date()
        let expiredKeys = featureCooldowns.filter { !$0.value.isActive(now: now) }.map { $0.key }
        
        if !expiredKeys.isEmpty {
            for key in expiredKeys {
                featureCooldowns.removeValue(forKey: key)
                logger.debug("Cleared expired cooldown for feature: \(key)")
            }
        }
    }
    
    @MainActor
    private func clearExpiredEffects() {
        let now = Date()
        let expiredEffectKeys = activeEffects.filter { $1 < now }.map { $0.key }
        
        if !expiredEffectKeys.isEmpty {
            for key in expiredEffectKeys {
                activeEffects.removeValue(forKey: key)
                logger.debug("Cleared expired effect for feature: \(key)")
            }
            // TODO: If effects were persisted (e.g., tempStatBoosts), clear them from persistence too.
        }
    }
    
    @MainActor
    private func startCooldownMonitoring() {
        // Set up a timer to periodically check and update cooldowns and effects
        Task {
            while !Task.isCancelled {
                clearExpiredCooldowns()
                clearExpiredEffects()
                // Use objectWillChange.send() if manual triggering is needed for UI updates,
                // but @Observable should handle changes to featureCooldowns/activeEffects automatically.
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Update every 1 second
            }
        }
    }
    
    // MARK: - Helper Methods
    
    var currentAccount: Account? {
        if case .loaded(let account) = state {
            return account
        }
        return authService.currentUserAccount
    }
    
    func getCooldownProgress(for feature: Feature) -> Double? {
        let featureId = feature.id
        
        guard let cooldownInfo = featureCooldowns[featureId],
              cooldownInfo.isActive() else {
            return nil // No active cooldown or invalid feature
        }
        
        return cooldownInfo.progress // Use the computed progress from the struct
    }
    
    func isFeatureOnCooldown(_ feature: Feature) -> Bool {
        let featureId = feature.id
        
        guard let cooldownInfo = featureCooldowns[featureId] else {
            return false
        }
        
        return cooldownInfo.isActive()
    }
    
    func canActivateFeature(_ feature: Feature) -> Bool {
        guard let account = currentAccount else { return false }
        
        // Use the validation logic, checking only for success
        return validateFeatureActivationPrerequisites(feature, account: account).isSuccess
    }
    
    @MainActor
    func getFeatureStatus(_ feature: Feature) -> String {
        guard let account = currentAccount else { return "Unavailable" }
        
        let validationResult = validateFeatureActivationPrerequisites(feature, account: account)
        
        switch validationResult {
        case .success:
            return "Ready"
        case .onCooldown(let remainingTime):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .abbreviated
            let timeString = formatter.string(from: remainingTime) ?? "\(Int(remainingTime))s"
            return "Cooldown: \(timeString)"
        case .insufficientPoints(let required, _):
            // Assuming SP cost for now
            return "Need \(required) SP"
             // TODO: Add checks for other costs if needed
        case .requirementsNotMet:
            return "Requirements not met"
        case .error(let message):
            return "Error: \(message)" // Or a generic "Error" message
        }
    }
    
    // MARK: - Feature Category Selection
    
    @MainActor
    func selectFeatureType(_ type: FeatureFunctionalType?) {
        if type != selectedFeatureType {
            // Add haptic feedback for type change
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            
            selectedFeatureType = type
        }
    }
    
    /// Helper to get available features filtered by the selected functional category.
    func getFeaturesForSelectedCategory() -> [Feature] {
        guard let category = selectedFeatureType else {
            // If no category selected, return all available features
            return availableFeatures
        }
        return availableFeatures.filter { $0.definition.functionalCategory == category }
    }
    
    /// Deprecated or review: Original getFeaturesByCategory used different logic.
    /// This new version filters the already 'availableFeatures'.
    func getAvailableFeaturesByCategory(_ type: FeatureFunctionalType) -> [Feature] {
        return availableFeatures.filter { $0.definition.functionalCategory == type }
    }
}

// MARK: - Update FeatureCooldownInfo

// Add a `now` parameter to isActive and remainingTime for accurate calculations
struct FeatureCooldownInfo: Equatable {
    let featureId: String
    let expiresAt: Date
    let totalCooldown: TimeInterval // Keep total duration for progress calculation
    
    func remainingTime(now: Date = Date()) -> TimeInterval {
        max(0, expiresAt.timeIntervalSince(now))
    }
    
    var progress: Double {
        let remaining = remainingTime() // Use current time
        // Avoid division by zero if totalCooldown is somehow 0
        return totalCooldown > 0 ? 1.0 - (remaining / totalCooldown) : 1.0
    }
    
    func isActive(now: Date = Date()) -> Bool {
        remainingTime(now: now) > 0
    }
}

// MARK: - Logger for Diagnostic Information

class Logger {
    enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        var prefix: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            }
        }
    }
    
    private let category: String
    private let minLevel: LogLevel
    
    init(category: String, minLevel: LogLevel = .debug) {
        self.category = category
        self.minLevel = minLevel
    }
    
    func log(_ level: LogLevel, _ message: String) {
        if level.rawValue >= minLevel.rawValue {
            print("[\(level.prefix)] [\(category)] \(message)")
        }
    }
    
    func debug(_ message: String) {
        log(.debug, message)
    }
    
    func info(_ message: String) {
        log(.info, message)
    }
    
    func warning(_ message: String) {
        log(.warning, message)
    }
    
    func error(_ message: String) {
        log(.error, message)
    }
}

