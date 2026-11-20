import Foundation

/// Random keys made for these tests. They don't belong to any real server.
enum Fixtures {
    static let privateKey = "u7jBiEiLq77Q8jcpXakYvblXYLqC6WMxgj3feYJXpxY="
    static let publicKey = "egKTjcrmM6VQ50IvOuzauW8C405Y0JeiY7pPdQdxW64="
    static let otherPublicKey = "5ySdajH6PpIcVm2A9snkSpHit8U25L9ISx1LkauXVk4="
    static let presharedKey = "OXssbeNI+OTiNFxrQzkxwyNtLWzxHt0xBlRdcxjoQU4="

    /// Shaped like the files Proton VPN's free plan hands out.
    static let protonStyle = """
    [Interface]
    # Key for laptop
    # Bouncing = 7
    # NetShield = 1
    PrivateKey = \(privateKey)
    Address = 10.2.0.2/32
    DNS = 10.2.0.1

    [Peer]
    # NL-FREE#12
    PublicKey = \(publicKey)
    AllowedIPs = 0.0.0.0/0, ::/0
    Endpoint = 203.0.113.7:51820
    """

    static func config(endpoint: String = "198.51.100.4:51820", publicKey: String = Fixtures.publicKey) -> String {
        """
        [Interface]
        PrivateKey = \(privateKey)
        Address = 10.8.0.2/24, fd00::2/64
        DNS = 1.1.1.1, home.lan

        [Peer]
        PublicKey = \(publicKey)
        AllowedIPs = 0.0.0.0/0
        Endpoint = \(endpoint)
        PersistentKeepalive = 25
        """
    }
}
