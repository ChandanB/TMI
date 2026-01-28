//
//  SSOService.swift
//  TMI
//
//  SSO scaffolding for district authentication providers
//

import Foundation

final class SSOService {
    static let shared = SSOService()

    private init() {}

    enum Provider: String, CaseIterable {
        case clever
        case classlink
        case googleWorkspace
        case microsoftAzure
    }

    func initiateSSO(provider: Provider, districtId: String) async throws -> URL {
        // TODO: Generate a provider-specific auth URL (usually via Cloud Functions).
        throw SSOServiceError.notImplemented("SSO initiation not implemented for \(provider.rawValue)")
    }

    func handleSSOCallback(provider: Provider, payload: String) async throws -> TMIUser {
        // TODO: Validate assertion, exchange for Firebase custom token, and fetch/create TMIUser.
        throw SSOServiceError.notImplemented("SSO callback handling not implemented for \(provider.rawValue)")
    }
}

enum SSOServiceError: LocalizedError {
    case notImplemented(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        case .invalidResponse(let message):
            return "SSO response invalid: \(message)"
        }
    }
}
