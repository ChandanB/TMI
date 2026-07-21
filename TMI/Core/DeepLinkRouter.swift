import Foundation

/// Converts supported external URLs into typed routes. Navigation state and
/// authorization remain owned by ``AppRouter``.
nonisolated enum DeepLinkRouter {
    static func route(for url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "tmi",
              let host = url.host?.lowercased() else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "student", "students":
            guard let studentID = identifier(at: 0, in: components) else {
                return nil
            }
            if components.count == 2, components[1].lowercased() == "edit" {
                return .editStudent(studentID)
            }
            guard components.count == 1 else { return nil }
            return .student(studentID)

        case "profile":
            return components.isEmpty ? .profile : nil

        case "settings":
            return components.isEmpty ? .settings : nil

        default:
            return nil
        }
    }

    private static func identifier(at index: Int, in components: [String]) -> String? {
        guard components.indices.contains(index) else { return nil }
        let identifier = components[index]
        return TrustedIdentifier.isValid(identifier) ? identifier : nil
    }
}
