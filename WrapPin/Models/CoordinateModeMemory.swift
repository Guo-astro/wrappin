import CoreLocation

// Remembers coordinate-mode choices so users need not switch again for a
// saved place, or for nearby points after switching manually. The newer of
// the place's own choice and a nearby manual choice wins.
struct CoordinateModeMemory: Codable, Equatable, Sendable {
    struct Choice: Codable, Equatable, Sendable {
        let mode: FixedCoordinateMode
        let latitude: Double
        let longitude: Double
        let date: Date

        init(mode: FixedCoordinateMode, target: LocationTarget, date: Date) {
            self.mode = mode
            self.latitude = target.latitude
            self.longitude = target.longitude
            self.date = date
        }
    }

    static let nearbyRadiusMetres: CLLocationDistance = 100_000

    private(set) var placeChoices: [String: Choice] = [:]
    private(set) var lastManualChoice: Choice?

    func mode(for target: LocationTarget) -> FixedCoordinateMode {
        let placeChoice = placeChoices[target.id]
        let nearbyChoice = lastManualChoice.flatMap { choice in
            Self.distance(from: choice, to: target) <= Self.nearbyRadiusMetres ? choice : nil
        }

        switch (placeChoice, nearbyChoice) {
        case let (place?, nearby?):
            return nearby.date > place.date ? nearby.mode : place.mode
        case let (place?, nil):
            return place.mode
        case let (nil, nearby?):
            return nearby.mode
        case (nil, nil):
            return .recommended(for: target)
        }
    }

    mutating func recordManualChoice(
        _ mode: FixedCoordinateMode,
        for target: LocationTarget,
        at date: Date = .now
    ) {
        let choice = Choice(mode: mode, target: target, date: date)
        placeChoices[target.id] = choice
        lastManualChoice = choice
    }

    // Records the mode a session actually started with for this place.
    mutating func recordUse(
        _ mode: FixedCoordinateMode,
        for target: LocationTarget,
        at date: Date = .now
    ) {
        placeChoices[target.id] = Choice(mode: mode, target: target, date: date)
    }

    // Keeps per-place choices only for places still saved in favourites or history.
    mutating func retainPlaces(withIDs ids: Set<String>) {
        placeChoices = placeChoices.filter { ids.contains($0.key) }
    }

    mutating func forgetManualChoice() {
        lastManualChoice = nil
    }

    private static func distance(from choice: Choice, to target: LocationTarget) -> CLLocationDistance {
        CLLocation(latitude: choice.latitude, longitude: choice.longitude)
            .distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
    }
}
