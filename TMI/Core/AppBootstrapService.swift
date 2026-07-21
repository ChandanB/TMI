//
//  AppBootstrapService.swift
//  TMI
//
//  Handles post-authentication bootstrap operations:
//  - Primes shared domain caches (students, plans, interest library)
//  - Initializes district context
//  - Prepares state models for fast navigation
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service responsible for warming up the app after authentication
@MainActor
final class AppBootstrapService {
    static let shared = AppBootstrapService()
    
    private init() {}
    
    // MARK: - Bootstrap State
    
    private var isBootstrapping = false
    private var lastBootstrapTime: Date?
    private var bootstrapErrors: [String: Error] = [:]
    
    // MARK: - Cache State
    
    /// Cached interest library (global)
    private(set) var cachedInterests: [Interest] = []
    
    /// Cached career library (global)
    private(set) var cachedCareers: [Career] = []
    
    /// Cached resource library (global + district)
    private(set) var cachedResources: [Resource] = []
    
    /// Whether caches are warm and ready
    var isCacheReady: Bool {
        !cachedInterests.isEmpty || !cachedCareers.isEmpty
    }
    
    // MARK: - Bootstrap Operations
    
    /// Warm start the app after authentication
    /// - Parameter membership: Server-verified tenant and staff scope.
    func warmStart(membership: MembershipContext) async {
        guard membership.isActive,
              membership.version > 0,
              TrustedIdentifier.isValid(membership.districtID) else {
            return
        }

        guard !isBootstrapping else {
            print("[AppBootstrap] Already bootstrapping, skipping...")
            return
        }
        
        isBootstrapping = true
        defer { isBootstrapping = false }
        
        let startTime = Date()
        
        // Clear previous errors
        bootstrapErrors.removeAll()
        
        // Run bootstrap tasks in parallel
        await withTaskGroup(of: Void.self) { group in
            // Always load global libraries
            group.addTask {
                await self.loadInterestLibrary()
            }
            
            group.addTask {
                await self.loadCareerLibrary()
            }
            
            group.addTask {
                await self.loadResourceLibrary(districtId: membership.districtID)
            }
            
            group.addTask {
                await self.primeStudentCache()
            }

            group.addTask {
                await self.primePlanCache()
            }

            if AuthorizationPolicy.canViewAggregate(
                membership,
                districtID: membership.districtID
            ) {
                group.addTask {
                    await self.loadDistrictContext(districtId: membership.districtID)
                }
            }
        }
        
        lastBootstrapTime = Date()
        let duration = Date().timeIntervalSince(startTime)
        
        print("[AppBootstrap] Warm start complete in \(String(format: "%.2f", duration))s")
        
        let errors = bootstrapErrors
        if !errors.isEmpty {
            print("[AppBootstrap] Errors during bootstrap:")
            for (domain, error) in errors {
                print("  - \(domain): \(error.localizedDescription)")
            }
        }
    }
    
    /// Cold start with minimal data (for quick app launch)
    func coldStart() async {
        print("[AppBootstrap] Cold start - loading minimal data")
        
        // Just load the interest library for the homepage
        await loadInterestLibrary()
    }
    
    /// Invalidate all caches (e.g., on sign out)
    func invalidateCaches() {
        cachedInterests = []
        cachedCareers = []
        cachedResources = []
        lastBootstrapTime = nil
        bootstrapErrors.removeAll()
        
        print("[AppBootstrap] Caches invalidated")
    }
    
    // MARK: - Library Loading
    
    private func loadInterestLibrary() async {
        do {
            let interests = try await InterestLibraryService.shared.fetchAllInterests()
            cachedInterests = interests
            print("[AppBootstrap] Loaded \(interests.count) interests")
        } catch {
            bootstrapErrors["interests"] = error
            print("[AppBootstrap] Failed to load interests: \(error.localizedDescription)")
        }
    }
    
    private func loadCareerLibrary() async {
        do {
            let careers = try await CareerLibraryService.shared.fetchAllCareers()
            cachedCareers = careers
            print("[AppBootstrap] Loaded \(careers.count) careers")
        } catch {
            bootstrapErrors["careers"] = error
            print("[AppBootstrap] Failed to load careers: \(error.localizedDescription)")
        }
    }
    
    private func loadResourceLibrary(districtId: String?) async {
        do {
            // Load resources with scope filtering
            let resources = try await ResourceLibraryService.shared.fetchResources(scope: nil, districtId: districtId)
            
            cachedResources = resources
            print("[AppBootstrap] Loaded \(resources.count) resources")
        } catch {
            bootstrapErrors["resources"] = error
            print("[AppBootstrap] Failed to load resources: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Domain Caching
    
    private func primeStudentCache() async {
        do {
            let service = StudentService()
            let students = try await service.fetchStudents()
            
            // Cache in the state model or local store
            // The actual caching is handled by StudentListStateModel
            print("[AppBootstrap] Primed student cache with \(students.count) students")
        } catch {
            bootstrapErrors["students"] = error
            print("[AppBootstrap] Failed to prime student cache: \(error.localizedDescription)")
        }
    }
    
    private func primePlanCache() async {
        do {
            let service = TMIPlanService.shared
            let plans = try await service.fetchPlans()
            
            // Cache in the state model or local store
            print("[AppBootstrap] Primed plan cache with \(plans.count) plans")
        } catch {
            bootstrapErrors["plans"] = error
            print("[AppBootstrap] Failed to prime plan cache: \(error.localizedDescription)")
        }
    }
    
    private func loadDistrictContext(districtId: String) async {
        do {
            let district = try await DistrictService.shared.fetchDistrict(id: districtId)
            print("[AppBootstrap] Loaded district context: \(district.name)")
        } catch {
            bootstrapErrors["district"] = error
            print("[AppBootstrap] Failed to load district context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Access
    
    /// Get cached interests (returns empty if not loaded)
    func getCachedInterests() -> [Interest] {
        cachedInterests
    }
    
    /// Get cached careers (returns empty if not loaded)
    func getCachedCareers() -> [Career] {
        cachedCareers
    }
    
    /// Get cached resources (returns empty if not loaded)
    func getCachedResources() -> [Resource] {
        cachedResources
    }
}
