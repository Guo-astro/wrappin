import Foundation

// Compile with the production SessionRecoveryRecord.swift to verify persisted JSON compatibility.
enum RouteMode: String, Codable { case walking, driving }
enum FixedCoordinateMode: String, Codable { case gcj02, wgs84 }
struct LocationTarget: Codable, Equatable { let name: String }

@main
struct RouteRecoveryCheck {
    static func main() throws {
        let decoder = JSONDecoder()
        let legacy = """
        {"kind":"walkingRoute","lastReportedLocation":{"name":"Start"},"destination":{"name":"End"},"walkingPaceMetresPerSecond":1.4,"startedAt":0,"updatedAt":0}
        """.data(using: .utf8)!
        let oldWalk = try decoder.decode(SessionRecoveryRecord.self, from: legacy)
        precondition(oldWalk.isRoute && oldWalk.routeMode == .walking)
        precondition(oldWalk.savedRouteSpeed == 1.4)

        let customWalk = SessionRecoveryRecord.route(
            from: LocationTarget(name: "Start"),
            to: LocationTarget(name: "End"),
            mode: .walking,
            coordinateMode: .gcj02,
            speedMetresPerSecond: 7.5 / 3.6
        )
        let restoredCustom = try decoder.decode(
            SessionRecoveryRecord.self,
            from: JSONEncoder().encode(customWalk)
        )
        precondition(restoredCustom.kind == .walkingRoute)
        precondition(restoredCustom.fixedCoordinateMode == .gcj02)
        precondition(abs((restoredCustom.savedRouteSpeed ?? 0) * 3.6 - 7.5) < 0.0001)

        let driving = SessionRecoveryRecord.route(
            from: LocationTarget(name: "Start"),
            to: LocationTarget(name: "End"),
            mode: .driving,
            coordinateMode: .wgs84,
            speedMetresPerSecond: 100 / 3.6
        )
        let restored = try decoder.decode(
            SessionRecoveryRecord.self,
            from: JSONEncoder().encode(driving)
        )
        precondition(restored.kind == .drivingRoute && restored.routeMode == .driving)
        precondition(restored.fixedCoordinateMode == .wgs84)
        precondition(abs((restored.savedRouteSpeed ?? 0) * 3.6 - 100) < 0.0001)
        var progressed = driving
        progressed.lastReportedLocation = LocationTarget(name: "Mid-route")
        progressed.updatedAt = Date(timeIntervalSinceReferenceDate: 321)
        let savedProgress = try decoder.decode(
            SessionRecoveryRecord.self, from: JSONEncoder().encode(progressed)
        )
        precondition(savedProgress == progressed)
        precondition(savedProgress.destination == driving.destination)
        precondition(savedProgress.startedAt == driving.startedAt)
        precondition(savedProgress.lastReportedLocation.name == "Mid-route")
        print("Route recovery: legacy walking, custom walking, driving and latest route progress passed")
    }
}
