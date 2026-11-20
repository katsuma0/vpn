import XCTest

final class WireGuardConfigTests: XCTestCase {
    func testParsesProtonStyleConfig() throws {
        let config = try WireGuardConfig.parse(Fixtures.protonStyle)
        XCTAssertEqual(config.interface.privateKey, Fixtures.privateKey)
        XCTAssertEqual(config.interface.addresses, ["10.2.0.2/32"])
        XCTAssertEqual(config.interface.dns, ["10.2.0.1"])
        XCTAssertEqual(config.peers.count, 1)
        XCTAssertEqual(config.peers[0].publicKey, Fixtures.publicKey)
        XCTAssertEqual(config.peers[0].allowedIPs, ["0.0.0.0/0", "::/0"])
        XCTAssertEqual(config.primaryEndpoint, "203.0.113.7:51820")
        XCTAssertEqual(config.primaryHost, "203.0.113.7")
    }

    func testKeepsPeerCommentsButNotInterfaceComments() throws {
        let config = try WireGuardConfig.parse(Fixtures.protonStyle)
        XCTAssertEqual(config.peers[0].comments, ["NL-FREE#12"])
    }

    func testParsesListsKeepaliveAndSearchDomains() throws {
        let config = try WireGuardConfig.parse(Fixtures.config())
        XCTAssertEqual(config.interface.addresses, ["10.8.0.2/24", "fd00::2/64"])
        XCTAssertEqual(config.interface.dns, ["1.1.1.1", "home.lan"])
        XCTAssertEqual(config.peers[0].persistentKeepalive, 25)
    }

    func testKeysAndSectionsAreCaseInsensitiveAndWindowsLineEndingsWork() throws {
        let text = """
        [interface]\r
        privatekey = \(Fixtures.privateKey)\r
        address = 10.0.0.2/32\r
        [PEER]\r
        publickey = \(Fixtures.publicKey)\r
        endpoint = vpn.example.com:51820\r
        allowedips = 0.0.0.0/0\r
        """
        let config = try WireGuardConfig.parse(text)
        XCTAssertEqual(config.primaryHost, "vpn.example.com")
    }

    func testAcceptsBracketedIPv6Endpoint() throws {
        let config = try WireGuardConfig.parse(Fixtures.config(endpoint: "[2001:db8::1]:51820"))
        XCTAssertEqual(config.primaryHost, "2001:db8::1")
    }

    func testIgnoresLinuxOnlyKeys() throws {
        let text = Fixtures.config().replacingOccurrences(
            of: "DNS = 1.1.1.1, home.lan",
            with: "DNS = 1.1.1.1\nTable = off\nPostUp = iptables -A FORWARD -j ACCEPT"
        )
        XCTAssertNoThrow(try WireGuardConfig.parse(text))
    }

    func testParsesPresharedKey() throws {
        let text = Fixtures.config().replacingOccurrences(
            of: "PersistentKeepalive = 25",
            with: "PresharedKey = \(Fixtures.presharedKey)"
        )
        let config = try WireGuardConfig.parse(text)
        XCTAssertEqual(config.peers[0].preSharedKey, Fixtures.presharedKey)
        XCTAssertNil(config.peers[0].persistentKeepalive)
    }

    // MARK: Errors you'd actually hit

    func testEmptyTextIsRejected() {
        XCTAssertThrowsError(try WireGuardConfig.parse("  \n\n")) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .empty)
        }
    }

    func testRandomTextIsRejected() {
        XCTAssertThrowsError(try WireGuardConfig.parse("hello there")) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .badLine(1))
        }
    }

    func testMissingPrivateKey() {
        let text = Fixtures.config().replacingOccurrences(of: "PrivateKey = \(Fixtures.privateKey)\n", with: "")
        XCTAssertThrowsError(try WireGuardConfig.parse(text)) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .missingPrivateKey)
        }
    }

    func testBadKey() {
        let text = Fixtures.config(publicKey: "not-a-key")
        XCTAssertThrowsError(try WireGuardConfig.parse(text)) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .invalidKey(field: "PublicKey"))
        }
    }

    func testNoPeer() {
        let text = """
        [Interface]
        PrivateKey = \(Fixtures.privateKey)
        Address = 10.0.0.2/32
        """
        XCTAssertThrowsError(try WireGuardConfig.parse(text)) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .noPeers)
        }
    }

    func testPeerWithoutEndpoint() {
        let text = Fixtures.config().replacingOccurrences(of: "Endpoint = 198.51.100.4:51820\n", with: "")
        XCTAssertThrowsError(try WireGuardConfig.parse(text)) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .missingEndpoint)
        }
    }

    func testEndpointWithoutPort() {
        XCTAssertThrowsError(try WireGuardConfig.parse(Fixtures.config(endpoint: "198.51.100.4"))) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .invalidValue(field: "Endpoint", value: "198.51.100.4"))
        }
    }

    func testBadAddress() {
        let text = Fixtures.config().replacingOccurrences(of: "10.8.0.2/24", with: "10.8.0.300/24")
        XCTAssertThrowsError(try WireGuardConfig.parse(text)) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .invalidValue(field: "Address", value: "10.8.0.300/24"))
        }
    }

    func testDuplicatePeers() {
        let peer = """

        [Peer]
        PublicKey = \(Fixtures.publicKey)
        AllowedIPs = 10.0.0.0/8
        """
        XCTAssertThrowsError(try WireGuardConfig.parse(Fixtures.config() + peer)) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .duplicatePeer)
        }
    }

    func testUnknownSection() {
        XCTAssertThrowsError(try WireGuardConfig.parse("[Nope]\nKey = Value")) { error in
            XCTAssertEqual(error as? WireGuardConfigError, .unknownSection("Nope"))
        }
    }

    func testEveryErrorHasAFriendlyMessage() {
        let errors: [WireGuardConfigError] = [
            .empty, .missingInterface, .missingPrivateKey, .noPeers, .missingPublicKey,
            .missingEndpoint, .duplicatePeer, .invalidKey(field: "PublicKey"),
            .invalidValue(field: "MTU", value: "1"), .unknownSection("X"), .badLine(3),
        ]
        for error in errors {
            let message = error.errorDescription ?? ""
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.contains("\u{2014}"), "No em dashes in UI text")
        }
    }
}
