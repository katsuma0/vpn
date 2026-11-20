import Foundation

/// A country you can tunnel through. `code` is an ISO 3166-1 alpha-2 code.
struct Country: Identifiable, Hashable, Codable {
    let code: String
    let name: String

    var id: String { code }
}

extension Country {
    /// Code used for servers whose country we couldn't figure out.
    static let otherCode = "ZZ"

    static let other = Country(code: otherCode, name: "Other")

    /// The countries people ask for most, in the order the app lists them.
    static let major: [Country] = [
        Country(code: "US", name: "United States"),
        Country(code: "CA", name: "Canada"),
        Country(code: "MX", name: "Mexico"),
        Country(code: "BR", name: "Brazil"),
        Country(code: "GB", name: "United Kingdom"),
        Country(code: "IE", name: "Ireland"),
        Country(code: "FR", name: "France"),
        Country(code: "DE", name: "Germany"),
        Country(code: "NL", name: "Netherlands"),
        Country(code: "BE", name: "Belgium"),
        Country(code: "CH", name: "Switzerland"),
        Country(code: "AT", name: "Austria"),
        Country(code: "ES", name: "Spain"),
        Country(code: "PT", name: "Portugal"),
        Country(code: "IT", name: "Italy"),
        Country(code: "SE", name: "Sweden"),
        Country(code: "NO", name: "Norway"),
        Country(code: "DK", name: "Denmark"),
        Country(code: "FI", name: "Finland"),
        Country(code: "PL", name: "Poland"),
        Country(code: "CZ", name: "Czechia"),
        Country(code: "RO", name: "Romania"),
        Country(code: "TR", name: "Turkey"),
        Country(code: "IL", name: "Israel"),
        Country(code: "AE", name: "United Arab Emirates"),
        Country(code: "IN", name: "India"),
        Country(code: "SG", name: "Singapore"),
        Country(code: "HK", name: "Hong Kong"),
        Country(code: "TW", name: "Taiwan"),
        Country(code: "JP", name: "Japan"),
        Country(code: "KR", name: "South Korea"),
        Country(code: "AU", name: "Australia"),
        Country(code: "NZ", name: "New Zealand"),
        Country(code: "ZA", name: "South Africa"),
    ]

    /// Every country the app can show, `Other` last.
    static let all: [Country] = major + [other]

    private static let byCode: [String: Country] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.code, $0) }
    )

    /// Looks up a country by code. Codes the app doesn't list fall back to
    /// the system's localized name so imported servers never lose their label.
    static func with(code: String) -> Country {
        let upper = code.uppercased()
        if let known = byCode[upper] { return known }
        if upper.count == 2,
           let name = Locale(identifier: "en_US").localizedString(forRegionCode: upper) {
            return Country(code: upper, name: name)
        }
        return other
    }

    /// Position in the app's list, so sorting stays stable and familiar.
    var sortIndex: Int {
        Country.all.firstIndex(of: self) ?? Country.major.count
    }
}
