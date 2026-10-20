import Foundation
import libphonenumber
import AccountContext
import TelegramCore

private let phoneNumberUtil = NBPhoneNumberUtil()

public func cleanPhoneNumber(_ text: String, removePlus: Bool = false) -> String {
    var result = ""
    for c in text {
        if c == "+" && !removePlus {
            if result.isEmpty {
                result += String(c)
            }
        } else if c >= "0" && c <= "9" {
            result += String(c)
        }
    }
    return result
}

public func formatPhoneNumber(_ string: String) -> String {
    do {
        let number = try phoneNumberUtil.parse("+" + string, defaultRegion: nil)
        return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
    } catch _ {
        return string
    }
}

public func formatPhoneNumber(context: AccountContext, number: String) -> String {
    if let pattern = lookupPatternByNumber(number, configuration: context.currentCountriesConfiguration.with { $0 }) {
        return "+\(formatPhoneNumberToMask(number, mask: pattern))"
    } else {
        do {
            let number = try phoneNumberUtil.parse("+" + number, defaultRegion: nil)
            return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
        } catch _ {
            return number
        }
    }
}

/// The phone number to display for `peerId`. With Nerf Client's LARP Custom Number on, the account's
/// own number is shown as the custom number followed by the LARP mark; the real number is unchanged.
public func formatDisplayedPhoneNumber(context: AccountContext, peerId: EnginePeer.Id, number: String) -> String {
    if peerId == context.account.peerId, let larpNumber = NerfClient.shared.larpNumber {
        return "\(formatPhoneNumber(context: context, number: cleanPhoneNumber(larpNumber, removePlus: true))) \(NerfClient.larpMark)"
    }
    return formatPhoneNumber(context: context, number: number)
}

private func removePlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c != "+" {
                result += String(c)
            }
        }
    }
    return result
}

public func lookupCountryIdByNumber(_ number: String, configuration: CountriesConfiguration) -> (Country, Country.CountryCode)? {
    let number = removePlus(number)
    var results: [(Country, Country.CountryCode)]? = nil
    for i in 0 ..< number.count {
        let prefix = String(number.prefix(number.count - i))
        if let country = configuration.countriesByPrefix[prefix] {
            if var currentResults = results {
                if let result = currentResults.first, result.1.code.count > country.1.code.count {
                    break
                } else {
                    currentResults.append(country)
                }
            } else {
                results = [country]
            }
        }
    }
    return results?.first
}

private func lookupPatternByNumber(_ number: String, configuration: CountriesConfiguration) -> String? {
    let number = removePlus(number)
    if let (_, code) = lookupCountryIdByNumber(number, configuration: configuration), !code.patterns.isEmpty {
        var prefixes: [String: String] = [:]
        for pattern in code.patterns {
            let cleanPattern = pattern.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "X", with: "")
            let cleanPrefix = "\(code.code)\(cleanPattern)"
            prefixes[cleanPrefix] = pattern
        }
        for i in 0..<number.count {
            let prefix = String(number.prefix(number.count - i))
            if let pattern = prefixes[prefix] {
                return "\(String(repeating: "X", count: code.code.count)) \(pattern)"
            }
        }
        if let pattern = code.patterns.first {
            return "\(String(repeating: "X", count: code.code.count)) \(pattern)"
        } else {
            return nil
        }
    }
    return nil
}

public func formatPhoneNumberToMask(_ string: String, mask: String) -> String {
    let replacementCharacter: Character = "X"
    let pattern = mask.replacingOccurrences( of: "[0-9]", with: "X", options: .regularExpression)
    var pureNumber = string.replacingOccurrences( of: "[^0-9]", with: "", options: .regularExpression)
    for index in 0 ..< pattern.count {
        guard index < pureNumber.count else { return pureNumber }
        let stringIndex = pattern.index(pattern.startIndex, offsetBy: index)
        let patternCharacter = pattern[stringIndex]
        guard patternCharacter != replacementCharacter else { continue }
        pureNumber.insert(patternCharacter, at: stringIndex)
    }
    return pureNumber
}

public func isViablePhoneNumber(_ string: String) -> Bool {
    return phoneNumberUtil.isViablePhoneNumber(string)
}
