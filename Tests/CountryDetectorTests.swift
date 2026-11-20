import XCTest

final class CountryDetectorTests: XCTestCase {
    func testProtonFileNamesAndComments() {
        XCTAssertEqual(CountryDetector.detect(in: "wg-US-FREE-12"), "US")
        XCTAssertEqual(CountryDetector.detect(in: "NL-FREE#3"), "NL")
        XCTAssertEqual(CountryDetector.detect(in: "protonvpn-JP-FREE-7"), "JP")
    }

    func testMullvadStyleHostnames() {
        XCTAssertEqual(CountryDetector.detect(in: "us-nyc-wg-001"), "US")
        XCTAssertEqual(CountryDetector.detect(in: "gb-lon-wg-002.relays.example.net"), "GB")
        XCTAssertEqual(CountryDetector.detect(in: "de-fra-wg-005"), "DE")
    }

    func testCountryNamesAliasesAndCities() {
        XCTAssertEqual(CountryDetector.detect(in: "My Japan box"), "JP")
        XCTAssertEqual(CountryDetector.detect(in: "uk-server"), "GB")
        XCTAssertEqual(CountryDetector.detect(in: "United States of America 2"), "US")
        XCTAssertEqual(CountryDetector.detect(in: "server-in-tokyo"), "JP")
        XCTAssertEqual(CountryDetector.detect(in: "new_york_1"), "US")
        XCTAssertEqual(CountryDetector.detect(in: "Hong Kong 3"), "HK")
    }

    func testCommonWordsDontMisfire() {
        XCTAssertNil(CountryDetector.detect(in: "my server in the attic"))
        XCTAssertNil(CountryDetector.detect(in: "home"))
        XCTAssertNil(CountryDetector.detect(in: "203.0.113.7"))
        XCTAssertNil(CountryDetector.detect(in: ""))
    }

    func testFirstConvincingHintWins() {
        XCTAssertEqual(CountryDetector.detect(in: ["home", "SE-FREE#1", "us-nyc"]), "SE")
        XCTAssertNil(CountryDetector.detect(in: ["home", "203.0.113.7"]))
    }
}
