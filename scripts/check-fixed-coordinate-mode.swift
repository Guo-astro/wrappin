import Foundation

// Minimal route mode for compiling the persisted recovery model outside Xcode.
enum RouteMode: String, Codable {
    case walking
    case driving
}

@main
struct FixedCoordinateModeCheck {
    static func main() {
        let suzhou = LocationTarget(
            name: "苏州中心广场",
            subtitle: "苏州市星港街 167 号",
            latitude: 31.316633,
            longitude: 120.677664
        )
        let converted = FixedCoordinateTransform.coordinates(for: suzhou, mode: .gcj02)
        precondition(abs(converted.latitude - 31.318719) < 0.000005)
        precondition(abs(converted.longitude - 120.673397) < 0.000005)
        precondition(FixedCoordinateMode.recommended(for: suzhou) == .gcj02)
        precondition(FixedCoordinateTransform.coordinates(for: suzhou, mode: .wgs84) == SimulationCoordinates(suzhou))

        let overseas = LocationTarget(
            name: "海外对照点",
            subtitle: "",
            latitude: 48.8584,
            longitude: 2.2945
        )
        precondition(FixedCoordinateMode.recommended(for: overseas) == .wgs84)
        precondition(FixedCoordinateTransform.coordinates(for: overseas, mode: .wgs84) == SimulationCoordinates(overseas))

        let recovery = SessionRecoveryRecord.fixed(at: suzhou, mode: .gcj02)
        let encoded = try! JSONEncoder().encode(recovery)
        precondition(try! JSONDecoder().decode(SessionRecoveryRecord.self, from: encoded).fixedCoordinateMode == .gcj02)
        var oldPayload = try! JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        oldPayload.removeValue(forKey: "fixedCoordinateMode")
        let oldData = try! JSONSerialization.data(withJSONObject: oldPayload)
        precondition(try! JSONDecoder().decode(SessionRecoveryRecord.self, from: oldData).fixedCoordinateMode == nil)

        let route = SessionRecoveryRecord.route(
            from: suzhou,
            to: overseas,
            mode: .driving,
            coordinateMode: .gcj02,
            speedMetresPerSecond: 20
        )
        let restoredRoute = try! JSONDecoder().decode(
            SessionRecoveryRecord.self,
            from: JSONEncoder().encode(route)
        )
        precondition(restoredRoute.fixedCoordinateMode == .gcj02)

        checkCoordinateModeMemory(suzhou: suzhou, overseas: overseas)

        print(String(format: "Suzhou GCJ-02 mode: %.6f, %.6f", converted.latitude, converted.longitude))
        print("WGS84 mode preserves numeric coordinates")
        print("Fixed and route recovery modes round-trip; legacy recovery still decodes")
        print("Coordinate mode memory keeps saved places and nearby manual choices")
    }

    private static func checkCoordinateModeMemory(suzhou: LocationTarget, overseas: LocationTarget) {
        let tokyo = LocationTarget(name: "东京站", subtitle: "", latitude: 35.6812, longitude: 139.7671)
        let shinjuku = LocationTarget(name: "新宿", subtitle: "", latitude: 35.6896, longitude: 139.7006)
        let yokohama = LocationTarget(name: "横滨", subtitle: "", latitude: 35.4437, longitude: 139.6380)
        let osaka = LocationTarget(name: "大阪", subtitle: "", latitude: 34.7025, longitude: 135.4959)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        var memory = CoordinateModeMemory()
        precondition(memory.mode(for: suzhou) == .gcj02)
        precondition(memory.mode(for: tokyo) == .wgs84)

        // A session for a saved place remembers that exact place only.
        memory.recordUse(.wgs84, for: tokyo, at: start)
        precondition(memory.mode(for: tokyo) == .wgs84)

        // A newer manual choice nearby applies to new points and to older saved places.
        memory.recordManualChoice(.gcj02, for: shinjuku, at: start.addingTimeInterval(60))
        precondition(memory.mode(for: shinjuku) == .gcj02)
        precondition(memory.mode(for: yokohama) == .gcj02)
        precondition(memory.mode(for: tokyo) == .gcj02)
        precondition(memory.mode(for: osaka) == .wgs84)
        precondition(memory.mode(for: overseas) == .wgs84)

        // A later choice for the place itself wins over the older nearby choice.
        memory.recordUse(.wgs84, for: tokyo, at: start.addingTimeInterval(120))
        precondition(memory.mode(for: tokyo) == .wgs84)
        precondition(memory.mode(for: yokohama) == .gcj02)

        let restored = try! JSONDecoder().decode(
            CoordinateModeMemory.self,
            from: JSONEncoder().encode(memory)
        )
        precondition(restored == memory)

        memory.retainPlaces(withIDs: [])
        precondition(memory.placeChoices.isEmpty)
        precondition(memory.mode(for: tokyo) == .gcj02)

        memory.forgetManualChoice()
        precondition(memory.mode(for: tokyo) == .wgs84)
        precondition(memory.mode(for: yokohama) == .wgs84)
        precondition(memory.mode(for: suzhou) == .gcj02)
    }
}
