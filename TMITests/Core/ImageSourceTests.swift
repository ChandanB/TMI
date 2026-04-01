import XCTest
@testable import TMI

final class ImageSourceTests: XCTestCase {
    func testURLSourcesCompareAndHashByValue() {
        let lhs = ImageSource(urlString: "https://example.com/image.png")
        let rhs = ImageSource(urlString: "https://example.com/image.png")
        let other = ImageSource(urlString: "https://example.com/other.png")

        XCTAssertEqual(lhs, rhs)
        XCTAssertEqual(lhs.hashValue, rhs.hashValue)
        XCTAssertNotEqual(lhs, other)
    }

    func testURLSourceCodableRoundTrips() throws {
        let source = ImageSource(urlString: "https://example.com/image.png")

        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ImageSource.self, from: data)

        XCTAssertEqual(source, decoded)
        XCTAssertEqual(source.id, decoded.id)
    }
}
