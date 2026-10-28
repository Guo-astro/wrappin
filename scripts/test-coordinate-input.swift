import Foundation

// Compile with the production CoordinateInputParser.swift to verify which
// search-field text is treated as a coordinate pair.
@main
struct CoordinateInputCheck {
    static func main() {
        func expect(_ text: String, _ latitude: Double, _ longitude: Double, line: UInt = #line) {
            guard case .coordinate(let lat, let lon) = CoordinateInputParser.parse(text) else {
                preconditionFailure("\(text) was not read as a coordinate", line: line)
            }
            precondition(abs(lat - latitude) < 0.000_01 && abs(lon - longitude) < 0.000_01,
                         "\(text) read as \(lat), \(lon)", line: line)
        }
        func expect(_ text: String, _ result: CoordinateInputParser.Result, line: UInt = #line) {
            precondition(CoordinateInputParser.parse(text) == result,
                         "\(text) read as \(CoordinateInputParser.parse(text))", line: line)
        }

        // Formats that already worked keep working.
        expect("35.6586, 139.7454", 35.6586, 139.7454)
        expect("(35.6586,139.7454)", 35.6586, 139.7454)
        expect("-33.8568, 151.2153", -33.8568, 151.2153)
        expect("35, 139", 35, 139)
        expect("91, 0", .invalid)
        expect("0, 181", .invalid)

        // Full-width punctuation, spaces and Unicode minus signs.
        expect("35.6586，139.7454", 35.6586, 139.7454)
        expect("（35.6586，139.7454）", 35.6586, 139.7454)
        expect("35.6586 139.7454", 35.6586, 139.7454)
        expect("−33.8568, 151.2153", -33.8568, 151.2153)

        // Degree signs with hemispheres, in either order and either case.
        expect("35.6586° N, 139.7454° E", 35.6586, 139.7454)
        expect("35.6586°N 139.7454°E", 35.6586, 139.7454)
        expect("33.8568° S, 151.2153° E", -33.8568, 151.2153)
        expect("40.7484 n, 73.9857 w", 40.7484, -73.9857)
        expect("139.7454° E, 35.6586° N", 35.6586, 139.7454)
        expect("N 35.6586, E 139.7454", 35.6586, 139.7454)
        expect("北纬35.6586°，东经139.7454°", 35.6586, 139.7454)
        expect("南纬33.8568° 西经70.6693°", -33.8568, -70.6693)

        // Degrees, minutes and seconds.
        expect(#"35°39'31"N 139°44'43"E"#, 35 + 39.0 / 60 + 31.0 / 3600, 139 + 44.0 / 60 + 43.0 / 3600)
        expect("48°51′30″N, 2°17′40″E", 48 + 51.0 / 60 + 30.0 / 3600, 2 + 17.0 / 60 + 40.0 / 3600)
        expect("35°39'N, 139°44'E", 35 + 39.0 / 60, 139 + 44.0 / 60)
        expect(#"35°60'0"N, 139°44'43"E"#, .invalid)

        // Contradictory or impossible hemispheres are rejected, not guessed.
        expect("35.6586° N, 139.7454° N", .invalid)
        expect("-35.6586° S, 139.7454° E", .invalid)
        expect("N35.6586N, 139.7454E", .invalid)
        expect("139.7454° N, 35.6586° E", .invalid)

        // Ordinary searches stay searches.
        expect("350 5", .notCoordinates)
        expect("第五大道350号", .notCoordinates)
        expect("10 Downing Street", .notCoordinates)
        expect("东京塔", .notCoordinates)
        expect("35.6586", .notCoordinates)
        expect("35.6586, 139.7454, 20", .notCoordinates)
        expect("", .notCoordinates)

        print("Coordinate input checks passed")
    }
}
