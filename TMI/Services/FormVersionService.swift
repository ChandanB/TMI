//
//  FormVersionService.swift
//  TMI
//
//  Service for managing form template versions
//

import Foundation
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseAuth

/// Service for managing form template versioning
final class FormVersionService {
    static let shared = FormVersionService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Version Creation

    /// Create a new version from a form template
    func createVersion(
        from template: FormTemplate,
        changeLog: String? = nil
    ) async throws -> FormVersion {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FormVersionError.userNotAuthenticated
        }

        // Get the latest version number for this template
        let templateId = template.id ?? UUID().uuidString
        let latestVersion = try await getLatestVersionNumber(templateId: templateId)
        let newVersionNumber = latestVersion + 1

        // Create new version
        var version = FormVersion.from(
            template: template,
            createdBy: uid,
            changeLog: changeLog
        )
        version.version = newVersionNumber

        // Save to Firestore
        let collection = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")

        let docRef = try collection.addDocument(from: version)

        print("[FormVersionService] ✅ Created version \(newVersionNumber) for template \(templateId)")

        var savedVersion = version
        savedVersion.id = docRef.documentID
        return savedVersion
    }

    /// Create initial version when template is first created
    func createInitialVersion(
        from template: FormTemplate
    ) async throws -> FormVersion {
        return try await createVersion(
            from: template,
            changeLog: "Initial version"
        )
    }

    // MARK: - Version Retrieval

    /// Get a specific version by ID
    func getVersion(
        templateId: String,
        versionId: String
    ) async throws -> FormVersion? {
        let docRef = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .document(versionId)

        let snapshot = try await docRef.getDocument()

        guard snapshot.exists else { return nil }

        return try snapshot.data(as: FormVersion.self)
    }

    /// Get a specific version by version number
    func getVersion(
        templateId: String,
        versionNumber: Int
    ) async throws -> FormVersion? {
        let query = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .whereField("version", isEqualTo: versionNumber)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()

        guard let document = snapshot.documents.first else { return nil }

        return try document.data(as: FormVersion.self)
    }

    /// Get the latest version of a template
    func getLatestVersion(templateId: String) async throws -> FormVersion? {
        let query = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .order(by: "version", descending: true)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()

        guard let document = snapshot.documents.first else { return nil }

        return try document.data(as: FormVersion.self)
    }

    /// Get all versions of a template
    func getAllVersions(templateId: String) async throws -> [FormVersion] {
        let query = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .order(by: "version", descending: false)

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: FormVersion.self)
        }
    }

    /// Get the latest version number for a template
    func getLatestVersionNumber(templateId: String) async throws -> Int {
        if let latestVersion = try await getLatestVersion(templateId: templateId) {
            return latestVersion.version
        }
        return 0
    }

    /// Get all published versions
    func getPublishedVersions(templateId: String) async throws -> [FormVersion] {
        let query = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .whereField("isPublished", isEqualTo: true)
            .order(by: "version", descending: false)

        let snapshot = try await query.getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: FormVersion.self)
        }
    }

    // MARK: - Version Updates

    /// Update version metadata
    func updateVersion(
        _ version: FormVersion
    ) async throws {
        guard let versionId = version.id else {
            throw FormVersionError.invalidVersionId
        }

        let docRef = db.collection("formTemplates")
            .document(version.templateId)
            .collection("versions")
            .document(versionId)

        try docRef.setData(from: version, merge: true)

        print("[FormVersionService] ✅ Updated version \(version.version) for template \(version.templateId)")
    }

    /// Publish a version (make it available for use)
    func publishVersion(
        templateId: String,
        versionId: String
    ) async throws {
        let docRef = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .document(versionId)

        try await docRef.updateData([
            "isPublished": true,
            "isActive": true
        ])

        print("[FormVersionService] ✅ Published version \(versionId) for template \(templateId)")
    }

    /// Unpublish a version (make it unavailable for new assignments)
    func unpublishVersion(
        templateId: String,
        versionId: String
    ) async throws {
        let docRef = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .document(versionId)

        try await docRef.updateData([
            "isPublished": false
        ])

        print("[FormVersionService] ✅ Unpublished version \(versionId) for template \(templateId)")
    }

    /// Archive a version
    func archiveVersion(
        templateId: String,
        versionId: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FormVersionError.userNotAuthenticated
        }

        let docRef = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .document(versionId)

        try await docRef.updateData([
            "isActive": false,
            "isPublished": false,
            "archivedAt": FieldValue.serverTimestamp(),
            "archivedBy": uid
        ])

        print("[FormVersionService] ✅ Archived version \(versionId) for template \(templateId)")
    }

    // MARK: - Version Comparison

    /// Compare two versions and generate a diff
    func compareVersions(
        templateId: String,
        oldVersionId: String,
        newVersionId: String
    ) async throws -> FormVersionDiff? {
        guard let oldVersion = try await getVersion(templateId: templateId, versionId: oldVersionId),
              let newVersion = try await getVersion(templateId: templateId, versionId: newVersionId) else {
            return nil
        }

        return FormVersionDiff(oldVersion: oldVersion, newVersion: newVersion)
    }

    // MARK: - Usage Tracking

    /// Increment usage count when a version is used in an assignment
    func incrementUsageCount(
        templateId: String,
        versionId: String
    ) async throws {
        let docRef = db.collection("formTemplates")
            .document(templateId)
            .collection("versions")
            .document(versionId)

        try await docRef.updateData([
            "usageCount": FieldValue.increment(Int64(1))
        ])
    }

    /// Get usage statistics for all versions of a template
    func getUsageStatistics(templateId: String) async throws -> [String: Int] {
        let versions = try await getAllVersions(templateId: templateId)

        var statistics: [String: Int] = [:]
        for version in versions {
            let versionLabel = version.versionLabel ?? "v\(version.version)"
            statistics[versionLabel] = version.usageCount
        }

        return statistics
    }

    // MARK: - Cleanup

    /// Delete old, unused versions (with safety checks)
    func cleanupUnusedVersions(
        templateId: String,
        keepMinimum: Int = 3,
        minimumAge: TimeInterval = 90 * 24 * 60 * 60 // 90 days
    ) async throws {
        let versions = try await getAllVersions(templateId: templateId)

        // Sort by version number descending (newest first)
        let sortedVersions = versions.sorted { $0.version > $1.version }

        // Keep at least the minimum number of versions
        let versionsToConsider = Array(sortedVersions.dropFirst(keepMinimum))

        let now = Date()

        for version in versionsToConsider {
            // Only delete if:
            // 1. Not published
            // 2. No usage
            // 3. Older than minimum age
            guard !version.isPublished,
                  version.usageCount == 0,
                  now.timeIntervalSince(version.createdAt) > minimumAge,
                  let versionId = version.id else {
                continue
            }

            // Delete the version
            try await db.collection("formTemplates")
                .document(templateId)
                .collection("versions")
                .document(versionId)
                .delete()

            print("[FormVersionService] 🗑️ Deleted unused version \(version.version) for template \(templateId)")
        }
    }
}

// MARK: - Errors

enum FormVersionError: LocalizedError {
    case userNotAuthenticated
    case invalidVersionId
    case templateNotFound
    case versionNotFound
    case alreadyPublished
    case cannotDeletePublishedVersion

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidVersionId:
            return "Invalid version ID"
        case .templateNotFound:
            return "Form template not found"
        case .versionNotFound:
            return "Version not found"
        case .alreadyPublished:
            return "This version is already published"
        case .cannotDeletePublishedVersion:
            return "Cannot delete a published version"
        }
    }
}
