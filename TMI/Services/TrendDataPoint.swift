import Foundation

/// Represents a single data point in a trend series (e.g., value over time)
public struct TrendDataPoint: Identifiable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let value: Double

    public init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}
