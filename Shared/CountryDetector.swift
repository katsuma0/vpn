import Foundation

/// Guesses which country a server lives in from the clues a config usually
/// carries: the file name ("wg-US-FREE-12.conf"), the peer comment
/// ("# NL-FREE#3") or the endpoint host ("de-fra-wg-001.example.net").
enum CountryDetector {
    /// Returns an ISO country code, or nil when nothing looks convincing.
    static func detect(in hints: [String]) -> String? {
        for hint in hints {
            if let code = detect(in: hint) { return code }
        }
        return nil
    }

    static func detect(in hint: String) -> String? {
        let tokens = tokenize(hint)
        guard !tokens.isEmpty else { return nil }
        let lowered = tokens.map { $0.lowercased() }
        let joined = lowered.joined(separator: " ")

        // 1. Full country names and well known aliases ("japan", "uk", "usa").
        for (name, code) in nameAliases where contains(phrase: name, in: joined) {
            return code
        }

        // 2. Big cities and the airport style codes providers love ("nyc", "fra").
        for (city, code) in cityAliases where contains(phrase: city, in: joined) {
            return code
        }

        // 3. Two letter codes written in capitals anywhere ("US-FREE#1").
        for token in tokens where token.count == 2 && token == token.uppercased() {
            if let code = knownCode(token) { return code }
        }

        // 4. A lowercase two letter code only counts as the first real word
        //    ("us-nyc-wg-001"), so words like "in" or "it" don't misfire.
        if let first = lowered.first(where: { !ignoredPrefixes.contains($0) }),
           first.count == 2,
           let code = knownCode(first) {
            return code
        }
        return nil
    }

    // MARK: - Helpers

    private static func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private static func contains(phrase: String, in joined: String) -> Bool {
        let padded = " \(joined) "
        return padded.contains(" \(phrase) ")
    }

    private static func knownCode(_ token: String) -> String? {
        let upper = token.uppercased()
        if upper == "UK" { return "GB" }
        return Country.major.contains { $0.code == upper } ? upper : nil
    }

    /// Words that often lead a file name but never name a country.
    private static let ignoredPrefixes: Set<String> = [
        "wg", "wireguard", "proton", "protonvpn", "mullvad", "ivpn", "vpn", "conf", "config", "server",
    ]

    private static let nameAliases: [(String, String)] = {
        var pairs = Country.major.map { ($0.name.lowercased(), $0.code) }
        pairs += [
            ("usa", "US"), ("america", "US"), ("united states of america", "US"),
            ("uk", "GB"), ("britain", "GB"), ("great britain", "GB"), ("england", "GB"),
            ("holland", "NL"), ("korea", "KR"), ("czech republic", "CZ"), ("uae", "AE"),
            ("swiss", "CH"), ("deutschland", "DE"),
        ]
        // Longest first, so "united states of america" wins over "america".
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    private static let cityAliases: [(String, String)] = [
        ("new york", "US"), ("nyc", "US"), ("los angeles", "US"), ("lax", "US"), ("chicago", "US"),
        ("dallas", "US"), ("miami", "US"), ("seattle", "US"), ("san francisco", "US"), ("atlanta", "US"),
        ("toronto", "CA"), ("vancouver", "CA"), ("montreal", "CA"),
        ("london", "GB"), ("lon", "GB"), ("manchester", "GB"),
        ("paris", "FR"), ("par", "FR"),
        ("berlin", "DE"), ("frankfurt", "DE"), ("fra", "DE"),
        ("amsterdam", "NL"), ("ams", "NL"),
        ("zurich", "CH"), ("zrh", "CH"),
        ("stockholm", "SE"), ("sto", "SE"),
        ("oslo", "NO"), ("madrid", "ES"), ("milan", "IT"), ("rome", "IT"), ("warsaw", "PL"),
        ("tokyo", "JP"), ("tyo", "JP"), ("osaka", "JP"),
        ("seoul", "KR"), ("sydney", "AU"), ("syd", "AU"), ("melbourne", "AU"),
        ("hong kong", "HK"), ("taipei", "TW"), ("mumbai", "IN"), ("dubai", "AE"),
        ("johannesburg", "ZA"), ("sao paulo", "BR"), ("auckland", "NZ"),
    ]
}
