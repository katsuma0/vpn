import XCTest

final class ServerLibraryTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("servers.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testDraftUsesPeerCommentAndDetectsCountry() throws {
        let draft = try ServerLibrary.makeDraft(config: Fixtures.protonStyle, fileName: "wg-NL-FREE-12.conf")
        XCTAssertEqual(draft.name, "NL-FREE#12")
        XCTAssertEqual(draft.countryCode, "NL")
    }

    func testDraftFallsBackToFileNameThenOther() throws {
        let fromFile = try ServerLibrary.makeDraft(config: Fixtures.config(), fileName: "tokyo-home.conf")
        XCTAssertEqual(fromFile.name, "tokyo-home")
        XCTAssertEqual(fromFile.countryCode, "JP")

        let unknown = try ServerLibrary.makeDraft(config: Fixtures.config())
        XCTAssertEqual(unknown.name, "198.51.100.4")
        XCTAssertEqual(unknown.countryCode, Country.otherCode)
    }

    func testBadConfigNeverBecomesADraft() {
        XCTAssertThrowsError(try ServerLibrary.makeDraft(config: "not a config"))
    }

    func testAddSavesAndReloads() throws {
        let library = ServerLibrary(fileURL: fileURL)
        let draft = try ServerLibrary.makeDraft(config: Fixtures.protonStyle)
        let server = try library.add(draft, now: Date(timeIntervalSince1970: 1_000))

        let reloaded = ServerLibrary(fileURL: fileURL)
        XCTAssertEqual(reloaded.servers, [server])
        XCTAssertEqual(reloaded.servers.first?.endpoint, "203.0.113.7:51820")
    }

    func testRejectsTheSameConfigTwice() throws {
        let library = ServerLibrary(fileURL: nil)
        try library.add(ServerLibrary.makeDraft(config: Fixtures.protonStyle))
        let again = Fixtures.protonStyle.replacingOccurrences(of: "\n", with: "\r\n") + "\n\n"
        XCTAssertThrowsError(try library.add(ServerLibrary.makeDraft(config: again))) { error in
            XCTAssertEqual(error as? ServerLibraryError, .duplicate(name: "NL-FREE#12"))
        }
    }

    func testCountriesAreGroupedAndOrdered() throws {
        let library = ServerLibrary(fileURL: nil)
        try library.add(ServerDraft(name: "Tokyo", countryCode: "JP", config: Fixtures.config(endpoint: "192.0.2.1:51820")))
        try library.add(ServerDraft(name: "NYC 1", countryCode: "US", config: Fixtures.config(endpoint: "192.0.2.2:51820")))
        try library.add(ServerDraft(name: "NYC 2", countryCode: "US", config: Fixtures.config(endpoint: "192.0.2.3:51820")))
        try library.add(ServerDraft(name: "Mystery", countryCode: Country.otherCode, config: Fixtures.config(endpoint: "192.0.2.4:51820")))

        XCTAssertEqual(library.countries.map(\.country.code), ["US", "JP", Country.otherCode])
        XCTAssertEqual(library.countries.first?.serverCount, 2)
        XCTAssertFalse(library.missingCountries.contains { $0.code == "US" })
        XCTAssertTrue(library.missingCountries.contains { $0.code == "GB" })
    }

    func testPicksOldestServerInACountry() throws {
        let library = ServerLibrary(fileURL: nil)
        let older = try library.add(
            ServerDraft(name: "A", countryCode: "US", config: Fixtures.config(endpoint: "192.0.2.1:51820")),
            now: Date(timeIntervalSince1970: 100)
        )
        try library.add(
            ServerDraft(name: "B", countryCode: "US", config: Fixtures.config(endpoint: "192.0.2.2:51820")),
            now: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(library.server(for: "us")?.id, older.id)
        XCTAssertNil(library.server(for: "FR"))
    }

    func testUpdateAndRemove() throws {
        let library = ServerLibrary(fileURL: fileURL)
        var server = try library.add(ServerLibrary.makeDraft(config: Fixtures.config()))
        server.countryCode = "CA"
        server.name = "Toronto"
        try library.update(server)
        XCTAssertEqual(ServerLibrary(fileURL: fileURL).servers.first?.name, "Toronto")
        XCTAssertEqual(library.server(for: "CA")?.id, server.id)

        try library.remove(id: server.id)
        XCTAssertTrue(ServerLibrary(fileURL: fileURL).servers.isEmpty)
    }

    func testCountryLookupNeverLosesALabel() {
        XCTAssertEqual(Country.with(code: "jp").name, "Japan")
        XCTAssertEqual(Country.with(code: "AR").name, "Argentina")
        XCTAssertEqual(Country.with(code: "nonsense"), .other)
    }
}
