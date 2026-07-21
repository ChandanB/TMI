//
//  AnyCodable.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//


import Foundation

/// Type-safe Codable storage for the scalar and collection values supported by
/// dynamic form responses.
nonisolated struct AnyCodable: Codable, Sendable {
    private enum Storage: Sendable {
        case string(String)
        case integer(Int)
        case double(Double)
        case boolean(Bool)
        case date(Date)
        case url(URL)
        case stringDictionary([String: String])
        case stringArray([String])
        case dictionary([String: AnyCodable])
        case array([AnyCodable])
        case null
    }

    private var storage: Storage

    var value: Any {
        switch storage {
        case .string(let value): value
        case .integer(let value): value
        case .double(let value): value
        case .boolean(let value): value
        case .date(let value): value
        case .url(let value): value
        case .stringDictionary(let value): value
        case .stringArray(let value): value
        case .dictionary(let value): value.mapValues(\.value)
        case .array(let value): value.map(\.value)
        case .null: NSNull()
        }
    }

    init<T: Sendable>(_ value: T) {
        switch value {
        case let value as String:
            storage = .string(value)
        case let value as Int:
            storage = .integer(value)
        case let value as Double:
            storage = .double(value)
        case let value as Bool:
            storage = .boolean(value)
        case let value as Date:
            storage = .date(value)
        case let value as URL:
            storage = .url(value)
        case let value as [String: String]:
            storage = .stringDictionary(value)
        case let value as [String]:
            storage = .stringArray(value)
        case let value as [String: AnyCodable]:
            storage = .dictionary(value)
        case let value as [AnyCodable]:
            storage = .array(value)
        default:
            preconditionFailure("Unsupported AnyCodable value: \(T.self)")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            storage = .null
        } else if let value = try? container.decode(String.self) {
            storage = .string(value)
        } else if let value = try? container.decode(Int.self) {
            storage = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            storage = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            storage = .boolean(value)
        } else if let value = try? container.decode(Date.self) {
            storage = .date(value)
        } else if let value = try? container.decode(URL.self) {
            storage = .url(value)
        } else if let value = try? container.decode([String: String].self) {
            storage = .stringDictionary(value)
        } else if let value = try? container.decode([String].self) {
            storage = .stringArray(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            storage = .dictionary(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            storage = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported dynamic form value"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch storage {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .date(let value): try container.encode(value)
        case .url(let value): try container.encode(value)
        case .stringDictionary(let value): try container.encode(value)
        case .stringArray(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
