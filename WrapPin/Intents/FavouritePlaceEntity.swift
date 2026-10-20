import AppIntents

// Exposes saved favourites to Shortcuts. Only the name and place description are
// shown; coordinates stay inside WrapPin.
struct FavouritePlaceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favourite Place")
    static let defaultQuery = FavouritePlaceQuery()

    let id: String
    let name: String
    let subtitle: String

    init(_ target: LocationTarget) {
        id = target.id
        name = target.name
        subtitle = target.subtitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

struct FavouritePlaceQuery: EntityQuery {
    @AppDependency private var appModel: AppModel

    @MainActor
    func entities(for identifiers: [String]) async throws -> [FavouritePlaceEntity] {
        appModel.favouriteLocations
            .filter { identifiers.contains($0.id) }
            .map(FavouritePlaceEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [FavouritePlaceEntity] {
        appModel.favouriteLocations.map(FavouritePlaceEntity.init)
    }
}
