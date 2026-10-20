import AppIntents
import SwiftUI

struct ShortcutsGuideView: View {
    var body: some View {
        List {
            Section {
                Label {
                    Text("WrapPin adds two ready-made shortcuts to the Shortcuts app. Nothing needs to be installed.")
                } icon: {
                    Image(systemName: "square.2.layers.3d.fill")
                        .foregroundStyle(.blue)
                }
            }

            Section("Shortcuts") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Simulate Favourite")
                        Text("Choose a saved favourite when it runs. WrapPin opens and starts simulating that place with the coordinate mode last used there.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                }

                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restore Real Location")
                        Text("Stops the running simulation, or restores the real location after an interrupted one, and reports the result.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "location.slash")
                }
            }

            Section("Before You Start") {
                Text("Pair this iPhone and save at least one favourite place.")
                Text("WrapPin opens while a shortcut runs. If the device connection is unavailable, it may also open the selected tunnel app.")
                Text("If a simulation was interrupted, choose to restore or continue it in WrapPin before starting a new one.")
            }
            .foregroundStyle(.secondary)

            Section("Automation") {
                Text("In the Shortcuts app, open Automation, create a personal automation such as Arrive, Leave or Time of Day, then add a WrapPin action.")
                    .foregroundStyle(.secondary)
            }

            Section("Siri") {
                Text(String(
                    format: NSLocalizedString(
                        "Say “Simulate a favourite with %@” or “Restore my real location with %@”.",
                        comment: ""
                    ),
                    appName,
                    appName
                ))
                .foregroundStyle(.secondary)
            }

            Section {
                ShortcutsLink()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } footer: {
                Text("Opens WrapPin's page in the Shortcuts app, where both shortcuts can be run or added to an automation.")
            }
        }
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "WrapPin"
    }
}

#Preview {
    NavigationStack {
        ShortcutsGuideView()
    }
}
