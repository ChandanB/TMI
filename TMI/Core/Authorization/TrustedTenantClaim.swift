import Foundation

nonisolated enum TrustedAccessClass: String, Codable, Sendable, CaseIterable, Equatable {
    case staff
    case studentMode
    case guardianRespondent
}

nonisolated struct TrustedTenantClaim: Sendable, Equatable {
    static let districtIDClaimKey = "tmiDistrictID"
    static let accessClassClaimKey = "tmiAccessClass"
    static let membershipVersionClaimKey = "tmiMembershipVersion"

    let userID: String
    let districtID: String
    let accessClass: TrustedAccessClass
    let membershipVersion: Int

    init(
        userID: String,
        districtID: String,
        accessClass: TrustedAccessClass,
        membershipVersion: Int
    ) {
        self.userID = userID
        self.districtID = districtID
        self.accessClass = accessClass
        self.membershipVersion = membershipVersion
    }

    init(userID: String, tokenClaims: [String: Any]) throws {
        guard TrustedIdentifier.isValid(userID) else {
            throw TrustedTenantClaimError.malformed
        }
        let trustedKeys = [
            Self.districtIDClaimKey,
            Self.accessClassClaimKey,
            Self.membershipVersionClaimKey,
        ]
        let presentTrustedKeyCount = trustedKeys.count {
            tokenClaims[$0] != nil
        }
        guard presentTrustedKeyCount > 0 else {
            throw TrustedTenantClaimError.missing
        }
        guard presentTrustedKeyCount == trustedKeys.count else {
            throw TrustedTenantClaimError.malformed
        }
        guard let districtID = tokenClaims[Self.districtIDClaimKey] as? String,
              TrustedIdentifier.isValid(districtID) else {
            throw TrustedTenantClaimError.malformed
        }
        guard let accessClassValue = tokenClaims[Self.accessClassClaimKey] as? String,
              let accessClass = TrustedAccessClass(rawValue: accessClassValue),
              accessClass == .staff else {
            throw TrustedTenantClaimError.unsupportedAccessClass
        }
        guard let membershipVersion = Self.integralClaimValue(
            tokenClaims[Self.membershipVersionClaimKey]
        ), membershipVersion > 0 else {
            throw TrustedTenantClaimError.malformed
        }

        self.init(
            userID: userID,
            districtID: districtID,
            accessClass: accessClass,
            membershipVersion: membershipVersion
        )
    }

    private static func integralClaimValue(_ value: Any?) -> Int? {
        guard let value, !(value is Bool) else {
            return nil
        }

        if let integer = value as? Int {
            return integer
        }

        guard let number = value as? NSNumber else {
            return nil
        }
        let double = number.doubleValue
        guard double.isFinite,
              double.rounded(.towardZero) == double else {
            return nil
        }
        return Int(exactly: double)
    }
}

nonisolated enum TrustedTenantClaimError: Error, Equatable {
    case missing
    case malformed
    case unsupportedAccessClass
}

nonisolated struct AuthenticatedSession: Sendable, Equatable {
    let profile: TMIUser
    let claim: TrustedTenantClaim
    let membership: MembershipContext
}

nonisolated enum TrustedIdentifier {
    static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
            && value.utf8.count <= 1_500
            && !value.contains("/")
            && value != "."
            && value != ".."
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}
