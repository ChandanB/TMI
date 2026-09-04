import FirebaseFunctions
import Foundation

/// Records that an export happened, and returns the identifier printed on it.
///
/// The identifier has to come from the server. A client-generated one would
/// appear on every page as though the export were traceable while nothing
/// anywhere recorded that a child's record left the building — worse than no
/// identifier, because it reads as an assurance.
///
/// `districts/{id}/auditEvents` is `allow write: if false`, so only the Admin
/// SDK can write one.
nonisolated protocol PlanExportAuditing: Sendable {
    func recordExport(
        planID: String,
        studentID: String,
        kind: PlanExportKind,
        districtID: String
    ) async throws -> String
}

nonisolated enum PlanExportAuditError: Error, Equatable, LocalizedError {
    /// The function that records an export is not deployed.
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "This build cannot record that an export happened, so it will not "
                + "produce one. Ask your administrator to deploy the export "
                + "function, then try again."
        case .notAuthorized:
            "You do not have access to export this plan."
        }
    }
}

nonisolated struct FirebasePlanExportAuditing: PlanExportAuditing {
    private let functions: Functions

    init(functions: Functions = .functions(region: "us-central1")) {
        self.functions = functions
    }

    func recordExport(
        planID: String,
        studentID: String,
        kind: PlanExportKind,
        districtID: String
    ) async throws -> String {
        // The key is the audit event's document id, so retrying a failed
        // export records one event rather than a second copy.
        let idempotencyKey = "export_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        do {
            let result = try await functions.httpsCallable("recordPlanExport").call([
                "districtID": districtID,
                "planID": planID,
                "studentID": studentID,
                "kind": kind.rawValue,
                "idempotencyKey": idempotencyKey,
                "reasonCode": "educator-plan-export",
                "expectedRecordVersion": 0,
            ])
            guard let payload = result.data as? [String: Any],
                  let auditID = payload["auditID"] as? String,
                  !auditID.isEmpty else {
                throw PlanExportAuditError.unavailable
            }
            return auditID
        } catch let error as PlanExportAuditError {
            throw error
        } catch {
            let functionsError = error as NSError
            guard functionsError.domain == FunctionsErrorDomain else {
                throw PlanExportAuditError.unavailable
            }
            // An undeployed callable answers NOT_FOUND. Say so plainly: there
            // is no client-authorized path to fall back to.
            if functionsError.code == FunctionsErrorCode.notFound.rawValue {
                throw PlanExportAuditError.unavailable
            }
            if functionsError.code == FunctionsErrorCode.permissionDenied.rawValue {
                throw PlanExportAuditError.notAuthorized
            }
            throw PlanExportAuditError.unavailable
        }
    }
}
