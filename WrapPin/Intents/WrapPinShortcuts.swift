import AppIntents

// Ready-made shortcuts that appear under WrapPin in the Shortcuts app, Spotlight
// and Siri without any setup. Chinese phrases are in AppShortcuts.strings.
struct WrapPinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFavouriteSimulationIntent(),
            phrases: [
                "Simulate a favourite with \(.applicationName)",
                "Simulate \(\.$place) with \(.applicationName)"
            ],
            shortTitle: "Simulate Favourite",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: RestoreRealLocationIntent(),
            phrases: [
                "Restore my real location with \(.applicationName)",
                "Stop \(.applicationName) simulation"
            ],
            shortTitle: "Restore Real Location",
            systemImageName: "location.slash"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
