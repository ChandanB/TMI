import Foundation
import Testing
@testable import TMI

@Suite("AnyCodable dynamic form values")
struct AnyCodableTests {
    @Test("Multiple-choice selections round-trip as strings")
    func stringArrayRoundTrip() throws {
        let value = AnyCodable(["Robotics", "Music"])
        let decoded = try roundTrip(value)

        #expect(decoded.value as? [String] == ["Robotics", "Music"])
    }

    @Test("Table responses round-trip as string dictionaries")
    func stringDictionaryRoundTrip() throws {
        let value = AnyCodable(["goal": "Complete project", "status": "Started"])
        let decoded = try roundTrip(value)

        #expect(
            decoded.value as? [String: String]
                == ["goal": "Complete project", "status": "Started"]
        )
    }

    private func roundTrip(_ value: AnyCodable) throws -> AnyCodable {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(AnyCodable.self, from: data)
    }
}
