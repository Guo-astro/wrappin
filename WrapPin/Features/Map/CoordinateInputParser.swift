import Foundation

/// Recognises coordinates typed or pasted into the search field. Accepts the
/// common copy formats: `35.6586, 139.7454`, full-width commas, spaces,
/// degree signs with N/S/E/W or 北纬/东经 labels, and degrees-minutes-seconds.
/// Anything that does not clearly read as a coordinate pair stays a place search.
enum CoordinateInputParser {
    enum Result: Equatable {
        case notCoordinates
        case invalid
        case coordinate(latitude: Double, longitude: Double)
    }

    private enum Axis {
        case latitude
        case longitude
    }

    private struct Component {
        var value: Double
        var axis: Axis?
    }

    private static let component =
        #"(N|S|E|W|北纬|南纬|东经|西经)?\s*(-?\d+(?:\.\d+)?)\s*(?:°\s*(?:(\d+(?:\.\d+)?)\s*'\s*(?:(\d+(?:\.\d+)?)\s*"\s*)?)?)?(N|S|E|W)?"#
    private static let pair = try! NSRegularExpression(
        pattern: #"^\s*"# + component + #"\s*(,|\s)\s*"# + component + #"\s*$"#,
        options: [.caseInsensitive]
    )

    static func parse(_ text: String) -> Result {
        let normalized = normalize(text)
        let range = NSRange(normalized.startIndex..., in: normalized)
        guard let match = pair.firstMatch(in: normalized, range: range) else {
            return .notCoordinates
        }

        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: normalized) else { return nil }
            return String(normalized[range])
        }

        let separatedByComma = group(6) == ","
        guard
            let first = component(prefix: group(1), degrees: group(2), minutes: group(3), seconds: group(4), suffix: group(5)),
            let second = component(prefix: group(7), degrees: group(8), minutes: group(9), seconds: group(10), suffix: group(11))
        else { return .invalid }

        // Two bare whole numbers separated by a space ("350 5") are far more
        // likely part of an address than a coordinate pair.
        let hasSymbols = normalized.contains("°") || first.axis != nil || second.axis != nil
        let bothDecimal = group(2)?.contains(".") == true && group(8)?.contains(".") == true
        if !separatedByComma, !hasSymbols, !bothDecimal {
            return .notCoordinates
        }

        let latitude: Double
        let longitude: Double
        switch (first.axis, second.axis) {
        case (.longitude, .latitude), (.longitude, nil), (nil, .latitude):
            latitude = second.value
            longitude = first.value
        case (.latitude, .latitude), (.longitude, .longitude):
            return .invalid
        default:
            latitude = first.value
            longitude = second.value
        }

        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            return .invalid
        }
        return .coordinate(latitude: latitude, longitude: longitude)
    }

    private static func normalize(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacements: [(String, String)] = [
            ("，", ","), ("−", "-"), ("－", "-"), ("º", "°"),
            ("′", "'"), ("’", "'"), ("″", "\""), ("”", "\""), ("''", "\"")
        ]
        for (target, replacement) in replacements {
            result = result.replacingOccurrences(of: target, with: replacement)
        }
        let brackets = CharacterSet(charactersIn: "()[]（）")
        return result.trimmingCharacters(in: .whitespacesAndNewlines.union(brackets))
    }

    private static func component(
        prefix: String?,
        degrees: String?,
        minutes: String?,
        seconds: String?,
        suffix: String?
    ) -> Component? {
        guard let degrees, var value = Double(degrees) else { return nil }
        let isNegative = degrees.hasPrefix("-")
        value = abs(value)

        if let minutes {
            guard let minuteValue = Double(minutes), minuteValue < 60 else { return nil }
            value += minuteValue / 60
        }
        if let seconds {
            guard let secondValue = Double(seconds), secondValue < 60 else { return nil }
            value += secondValue / 3600
        }

        // A hemisphere may appear before or after the number, but only once,
        // and it replaces a minus sign rather than combining with one.
        if prefix != nil, suffix != nil { return nil }
        let hemisphere = (prefix ?? suffix)?.uppercased()
        if hemisphere != nil, isNegative { return nil }

        let axis: Axis?
        var sign = isNegative ? -1.0 : 1.0
        switch hemisphere {
        case "N", "北纬":
            axis = .latitude
        case "S", "南纬":
            axis = .latitude
            sign = -1
        case "E", "东经":
            axis = .longitude
        case "W", "西经":
            axis = .longitude
            sign = -1
        default:
            axis = nil
        }

        return Component(value: sign * value, axis: axis)
    }
}
