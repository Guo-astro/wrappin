import Foundation

@main
enum TunnelHandoffCheck {
    static func main() {
        let choices = TunnelHandoffApp.allCases
        precondition(choices == [
            .localDevVPN, .shadowrocket, .surge, .loon, .stash, .egern, .quantumultX, .singBox
        ])
        precondition(choices.map(\.launchURL.scheme) == [
            "localdevvpn", "shadowrocket", "surge", "loon", "stash", "egern", "quantumult-x", "sing-box"
        ])
        precondition(choices.map(\.appURL.scheme) == choices.map(\.launchURL.scheme))
        precondition(TunnelHandoffApp.localDevVPN.launchURL.host == "enable")
        precondition(TunnelHandoffApp.localDevVPN.launchURL.query == "scheme=wrappin")
        precondition(TunnelHandoffApp.shadowrocket.launchURL.host == "connect")
        precondition(TunnelHandoffApp.shadowrocket.launchURL.query == nil)
        precondition(TunnelHandoffApp.surge.launchURL.path == "/start")
        precondition(TunnelHandoffApp.surge.launchURL.host == nil)
        precondition(TunnelHandoffApp.loon.launchURL.host == "on")
        precondition(TunnelHandoffApp.stash.launchURL.host == "start")
        // Egern documents a single-slash form, so "start" is the path, not the host.
        precondition(TunnelHandoffApp.egern.launchURL.absoluteString == "egern:/start")
        precondition(TunnelHandoffApp.egern.launchURL.host == nil)
        precondition(TunnelHandoffApp.egern.launchURL.path == "/start")
        // Quantumult X and sing-box document no start action, so they only open.
        precondition(TunnelHandoffApp.quantumultX.launchURL == TunnelHandoffApp.quantumultX.appURL)
        precondition(TunnelHandoffApp.singBox.launchURL == TunnelHandoffApp.singBox.appURL)

        let stored = TunnelHandoffApp.shadowrocket.rawValue
        precondition(TunnelHandoffApp(rawValue: stored) == .shadowrocket)
        precondition(TunnelHandoffApp(rawValue: "unknown") ?? .localDevVPN == .localDevVPN)

        precondition(TunnelHandoffPolicy.offersMobileDataWorkaround(for: .localDevVPN))
        precondition(!TunnelHandoffPolicy.offersMobileDataWorkaround(for: .shadowrocket))
        precondition(!TunnelHandoffPolicy.offersMobileDataWorkaround(for: .surge))
        for app in choices where app != .localDevVPN {
            precondition(!TunnelHandoffPolicy.offersMobileDataWorkaround(for: app))
            precondition(TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: app))
        }
        precondition(!TunnelHandoffPolicy.offersMobileDataWorkaround(for: .loon))
        precondition(TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: .shadowrocket))
        precondition(TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: .surge))
        precondition(TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: .loon))
        precondition(!TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: .localDevVPN))
        precondition(TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
            app: .localDevVPN, isWiFiPathKnown: true, isWiFiSatisfied: false
        ))
        precondition(!TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
            app: .localDevVPN, isWiFiPathKnown: true, isWiFiSatisfied: true
        ))
        precondition(!TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
            app: .shadowrocket, isWiFiPathKnown: true, isWiFiSatisfied: false
        ))
        precondition(!TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
            app: .surge, isWiFiPathKnown: true, isWiFiSatisfied: false
        ))
        precondition(!TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
            app: .loon, isWiFiPathKnown: true, isWiFiSatisfied: false
        ))
        precondition(!TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
            app: .localDevVPN, isWiFiPathKnown: false, isWiFiSatisfied: false
        ))

        print("Tunnel handoff: LocalDevVPN callback, Shadowrocket connect, Surge start, Loon start, Stash start, Egern start, Quantumult X and sing-box open, selection and mobile guidance passed")
    }
}
