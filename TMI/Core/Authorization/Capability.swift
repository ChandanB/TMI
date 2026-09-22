nonisolated enum Capability: String, Codable, Sendable, CaseIterable, Equatable {
    case studentReadDetail = "student.read.detail"
    case studentWriteDetail = "student.write.detail"
    case studentRestrictedRead = "student.restricted.read"
    case studentRestrictedWrite = "student.restricted.write"
    case planApprove = "plan.approve"
    case staffManage = "staff.manage"
    case reportExport = "report.export"
    case auditRead = "audit.read"
}

nonisolated enum StaffRole: String, Codable, Sendable, CaseIterable, Equatable {
    case teacher
    case counselor
    case socialWorker
    case schoolAdministrator
    case districtAdministrator
}

nonisolated extension StaffRole {
    var displayName: String {
        switch self {
        case .teacher: "Teacher"
        case .counselor: "Counselor"
        case .socialWorker: "Social Worker"
        case .schoolAdministrator: "School Administrator"
        case .districtAdministrator: "District Administrator"
        }
    }
}

nonisolated extension Capability {
    var displayName: String {
        switch self {
        case .studentReadDetail: "Read student detail"
        case .studentWriteDetail: "Edit student detail"
        case .studentRestrictedRead: "Read restricted records"
        case .studentRestrictedWrite: "Write restricted records"
        case .planApprove: "Approve plans"
        case .staffManage: "Manage staff"
        case .reportExport: "Export reports"
        case .auditRead: "Read audit events"
        }
    }
}

nonisolated extension StaffRole {
    /// Default capabilities per role. Mirrors `defaultCapabilitiesByRole` in
    /// functions/src/developerConsole.ts; restricted-record capabilities are
    /// never defaults.
    var defaultCapabilities: [Capability] {
        switch self {
        case .teacher, .counselor:
            [.studentReadDetail, .studentWriteDetail]
        case .socialWorker:
            [.studentReadDetail]
        case .schoolAdministrator:
            [.studentReadDetail, .studentWriteDetail, .staffManage, .reportExport]
        case .districtAdministrator:
            [
                .studentReadDetail, .studentWriteDetail, .studentRestrictedRead,
                .planApprove, .staffManage, .reportExport, .auditRead,
            ]
        }
    }
}
