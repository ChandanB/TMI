//
//  ResourceGenerationService.swift
//  TMI
//
//  AI-powered resource generation using Apple Foundation Models
//

import Foundation
import FoundationModels
import FirebaseFirestore
import FirebaseAuth

// MARK: - Generable Structures for AI

@available(iOS 26.0, macOS 15.0, *)
@Generable
struct GeneratedResourceList {
    @Generable
    struct ResourceItem {
        let title: String
        let type: String
        let url: String
        let description: String
        let tags: [String]
    }

    let resources: [ResourceItem]
}

@available(iOS 26.0, macOS 15.0, *)
actor ResourceGenerationService {
    static let shared = ResourceGenerationService()

    private let firestore = Firestore.firestore()
    private var languageModelSession: LanguageModelSession?

    // MARK: - Initialization

    private init() {}

    /// Check if Foundation Models are available on this device
    func checkAvailability() async -> Bool {
        do {
            // Check if we can create a language model session
            let session = LanguageModelSession()
            languageModelSession = session
            return true
        } 
    }

    // MARK: - Resource Generation

    /// Generate personalized resources for an interest, checking cache first
    func generateResources(for interest: Interest, plan: TMIPlan) async throws -> [Resource] {
        // 1. Check if resources already exist in Firestore
        if let cachedResources = try await fetchCachedResources(for: interest) {
            print("[ResourceGeneration] Using cached resources for \(interest.name)")
            return cachedResources
        }

        // 2. Generate new resources using Foundation Models
        print("[ResourceGeneration] Generating new resources for \(interest.name)")
        let generatedResources = try await generateResourcesWithAI(for: interest, plan: plan)

        // 3. Upload to Firestore for caching
        try await cacheResources(generatedResources, for: interest)

        // 4. IMPORTANT: Fetch back from Firestore to ensure consistency
        // This prevents race conditions and ensures UI shows exactly what's cached
        if let freshlyFetchedResources = try await fetchCachedResources(for: interest) {
            print("[ResourceGeneration] Returning freshly cached resources for \(interest.name)")
            return freshlyFetchedResources
        }

        // 5. Fallback to generated resources if fetch fails
        return generatedResources
    }

    // MARK: - AI Generation

    private func generateResourcesWithAI(for interest: Interest, plan: TMIPlan) async throws -> [Resource] {
        // Initialize session if needed
        if languageModelSession == nil {
            languageModelSession = LanguageModelSession()
        }

        guard let session = languageModelSession else {
            throw ResourceGenerationError.contextUnavailable
        }

        // Build prompt for resource generation
        let prompt = buildPrompt(for: interest, plan: plan)

        // Generate using Foundation Models
        let resources = try await generateStructuredResources(session: session, prompt: prompt, interest: interest)

        return resources
    }

    private func buildPrompt(for interest: Interest, plan: TMIPlan) -> String {
        let studentName = plan.primaryStudent?.name ?? "the student"
        let grade = plan.primaryStudent?.grade ?? "middle school"
        let modelType = plan.model.rawValue

        return """
        Generate exactly 3 DIFFERENT educational resources for a \(grade) student interested in \(interest.name).

        IMPORTANT: Each resource must be completely different - different title, type, and URL.

        Context:
        - Student: \(studentName) (Grade: \(grade))
        - Interest: \(interest.name)
        - Description: \(interest.description ?? "General interest")
        - TMI Model: \(modelType)
        - Academic Subjects: \(interest.academicRelevance.map { $0.rawValue }.joined(separator: ", "))

        REQUIRED MIX (must have one of each):
        1. FIRST resource: type MUST be "article" - an educational article or guide
        2. SECOND resource: type MUST be "video" - an educational video or course
        3. THIRD resource: type MUST be "interactiveContent" - hands-on activity, game, or interactive tool

        For URLs, use only the main website URL (not specific pages that may not exist):
        - For articles: use "https://www.khanacademy.org" or "https://www.nationalgeographic.org"
        - For videos: use "https://www.youtube.com/education" or "https://www.pbs.org/education"
        - For interactive: use "https://www.pbs.org/education" or "https://www.nationalgeographic.org/education"

        Each resource must have:
        - title: Specific, engaging title related to \(interest.name)
        - type: Exactly as specified above ("article", "video", or "interactiveContent")
        - url: One of the main URLs listed above (matching the type)
        - description: 1-2 sentences about what the student will learn
        - tags: Include "\(interest.name)" plus 2-3 other relevant tags

        Make each resource unique and age-appropriate for \(grade).
        """
    }

    private func generateStructuredResources(session: LanguageModelSession, prompt: String, interest: Interest) async throws -> [Resource] {
        // Use @Generable macro for structured output
        let response = try await session.respond(to: prompt, generating: GeneratedResourceList.self)

        // Access the generated content from the response
        let generatedData = response.content

        // Debug: Log what was generated
        print("[ResourceGeneration] AI generated \(generatedData.resources.count) resources for \(interest.name):")
        for (index, item) in generatedData.resources.enumerated() {
            print("  Resource \(index + 1): type=\(item.type), title=\(item.title)")
        }

        // Convert to Resource objects
        let resources = generatedData.resources.map { item in
            Resource(
                title: item.title,
                description: item.description,
                category: mapResourceCategory(item.type),
                url: item.url,
                createdAt: Date(),
                updatedAt: Date(),
                tags: item.tags + [interest.name],
                recommendedFor: ["Students", "Educators"],
                isFeatured: false,
                thumbnail: nil,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            )
        }

        // Debug: Log converted resources
        print("[ResourceGeneration] Converted to Resource objects:")
        for (index, resource) in resources.enumerated() {
            print("  Resource \(index + 1): category=\(resource.category.rawValue), title=\(resource.title)")
        }

        return resources.isEmpty ? createFallbackResources(for: interest) : resources
    }

    private func mapResourceCategory(_ type: String) -> Resource.ResourceCategory {
        switch type.lowercased() {
        case "article": return .article
        case "video": return .video
        case "interactive", "interactivecontent": return .interactiveContent
        case "course": return .course
        case "book": return .book
        case "tool": return .tool
        default: return .article
        }
    }

    private func parseResourceResponse(_ content: String, interest: Interest) -> [Resource] {
        var resources: [Resource] = []
        let lines = content.components(separatedBy: "\n")

        var currentResource: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("RESOURCE") {
                // Save previous resource if exists
                if !currentResource.isEmpty {
                    if let resource = createResource(from: currentResource, interest: interest) {
                        resources.append(resource)
                    }
                    currentResource = [:]
                }
            } else if trimmed.hasPrefix("Title:") {
                currentResource["title"] = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Type:") {
                currentResource["type"] = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("URL:") {
                currentResource["url"] = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Description:") {
                currentResource["description"] = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Tags:") {
                currentResource["tags"] = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Don't forget the last resource
        if !currentResource.isEmpty {
            if let resource = createResource(from: currentResource, interest: interest) {
                resources.append(resource)
            }
        }

        // Fallback: if parsing failed, create default resources
        if resources.isEmpty {
            resources = createFallbackResources(for: interest)
        }

        return resources
    }

    private func createResource(from data: [String: String], interest: Interest) -> Resource? {
        guard let title = data["title"],
              let typeString = data["type"],
              let url = data["url"],
              let description = data["description"] else {
            return nil
        }

        let category: Resource.ResourceCategory
        switch typeString.lowercased() {
        case "article": category = .article
        case "video": category = .video
        case "interactive", "interactivecontent": category = .interactiveContent
        case "course": category = .course
        case "book": category = .book
        case "tool": category = .tool
        default: category = .article
        }

        let tags = data["tags"]?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [interest.name]

        return Resource(
            title: title,
            description: description,
            category: category,
            url: url,
            createdAt: Date(),
            updatedAt: Date(),
            tags: tags + [interest.name],
            recommendedFor: ["Students", "Educators"],
            isFeatured: false,
            thumbnail: nil,
            scope: .global,
            districtId: nil,
            ownerUid: nil
        )
    }

    private func createFallbackResources(for interest: Interest) -> [Resource] {
        return [
            Resource(
                title: "Exploring \(interest.name): Beginner's Guide",
                description: "A comprehensive introduction to \(interest.name) designed for students.",
                category: .article,
                url: "https://www.khanacademy.org",
                createdAt: Date(),
                updatedAt: Date(),
                tags: [interest.name, "beginner", "guide"],
                recommendedFor: ["Students"],
                isFeatured: false,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            ),
            Resource(
                title: "Career Paths in \(interest.name)",
                description: "Explore career opportunities related to \(interest.name).",
                category: .video,
                url: "https://www.pbs.org/education",
                createdAt: Date(),
                updatedAt: Date(),
                tags: [interest.name, "career", "exploration"],
                recommendedFor: ["Students", "Counselors"],
                isFeatured: false,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            ),
            Resource(
                title: "\(interest.name) Interactive Activities",
                description: "Hands-on activities and projects to deepen understanding of \(interest.name).",
                category: .interactiveContent,
                url: "https://www.nationalgeographic.org/education",
                createdAt: Date(),
                updatedAt: Date(),
                tags: [interest.name, "interactive", "activities"],
                recommendedFor: ["Students", "Teachers"],
                isFeatured: false,
                scope: .global,
                districtId: nil,
                ownerUid: nil
            )
        ]
    }

    // MARK: - Firestore Caching (Global Resources)

    private func fetchCachedResources(for interest: Interest) async throws -> [Resource]? {
        guard let interestId = interest.id else {
            return nil
        }

        // Use global collection at root level (not user-scoped)
        let collection = firestore
            .collection("generatedResources")
            .document(interestId)
            .collection("resources")

        let snapshot = try await collection.getDocuments()

        if snapshot.documents.isEmpty {
            return nil
        }

        let resources = try snapshot.documents.compactMap { doc in
            try doc.data(as: Resource.self)
        }

        return resources
    }

    private func cacheResources(_ resources: [Resource], for interest: Interest) async throws {
        guard let interestId = interest.id else {
            return
        }

        // Use global collection at root level (not user-scoped)
        let collection = firestore
            .collection("generatedResources")
            .document(interestId)
            .collection("resources")

        // Upload each resource
        for resource in resources {
            let _ = try collection.addDocument(from: resource)
        }

        // Also update the interest document to mark it as having generated resources
        let interestDoc = firestore
            .collection("generatedResources")
            .document(interestId)

        try await interestDoc.setData([
            "interestName": interest.name,
            "interestId": interestId,
            "generatedAt": FieldValue.serverTimestamp(),
            "resourceCount": resources.count
        ], merge: true)

        print("[ResourceGeneration] Cached \(resources.count) global resources for \(interest.name)")
    }
}

// MARK: - Errors

enum ResourceGenerationError: LocalizedError {
    case contextUnavailable
    case generationFailed
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "Foundation Models context is unavailable"
        case .generationFailed:
            return "Failed to generate resources"
        case .parsingFailed:
            return "Failed to parse generated resources"
        }
    }
}
