import CoreLocation
import Foundation
import Observation

enum BackgroundKeepAliveStatus: String, Sendable {
    case idle
    case awaitingAuthorization
    case starting
    case receivingUpdates
    case denied
    case restricted
    case servicesDisabled
    case missingBackgroundMode
    case locationUnavailable
    case failed
    case stopped

    var title: String {
        switch self {
        case .idle, .stopped: String(localized: "Inactive")
        case .awaitingAuthorization: String(localized: "Waiting for permission")
        case .starting: String(localized: "Starting")
        case .receivingUpdates: String(localized: "Active")
        case .denied: String(localized: "Location permission denied")
        case .restricted: String(localized: "Location access restricted")
        case .servicesDisabled: String(localized: "Location Services off")
        case .missingBackgroundMode: String(localized: "Background mode missing")
        case .locationUnavailable: String(localized: "Temporarily unavailable")
        case .failed: String(localized: "Failed")
        }
    }
}

/// Receives Core Location updates only to keep the native device session alive
/// while WrapPin is in the background. Coordinates are never stored, injected,
/// compared, or sent to analytics; the native DVT service remains the source.
@MainActor
@Observable
final class BackgroundLocationKeepAlive: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var status: BackgroundKeepAliveStatus = .idle
    private(set) var started = false
    private(set) var reducesBackgroundLocationIndicator = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var showsBackgroundLocationIndicator = true

    var isBackgroundIndicatorHidden: Bool { !showsBackgroundLocationIndicator }

    var authorizationTitle: String {
        switch authorizationStatus {
        case .notDetermined: String(localized: "Not requested")
        case .authorizedWhenInUse: String(localized: "While Using the App")
        case .authorizedAlways: String(localized: "Always")
        case .denied: String(localized: "Denied")
        case .restricted: String(localized: "Restricted")
        @unknown default: String(localized: "Unknown")
        }
    }

    private let manager: CLLocationManager
    private var requested = false
    private let hasBackgroundMode: Bool
    // In-memory intent for the When In Use -> Always flow started by the toggle.
    // It is never restored from preferences or created by session startup.
    private var pendingAlwaysAuthorizationUpgrade = false

    init(
        manager: CLLocationManager = CLLocationManager(),
        hasBackgroundMode: Bool = (Bundle.main.object(
            forInfoDictionaryKey: "UIBackgroundModes"
        ) as? [String])?.contains("location") == true,
        reducesBackgroundLocationIndicator: Bool = false
    ) {
        self.manager = manager
        self.hasBackgroundMode = hasBackgroundMode
        self.reducesBackgroundLocationIndicator = reducesBackgroundLocationIndicator
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        applyIndicatorPreference()
    }

    /// Loads a stored choice without requesting either form of authorization.
    func restoreIndicatorPreference(_ enabled: Bool) {
        reducesBackgroundLocationIndicator = enabled
        pendingAlwaysAuthorizationUpgrade = false
        applyIndicatorPreference()
    }

    /// Only a new, explicit off -> on toggle may request an authorization upgrade.
    func setIndicatorPreferenceFromUserAction(_ enabled: Bool) {
        guard enabled != reducesBackgroundLocationIndicator else { return }
        reducesBackgroundLocationIndicator = enabled
        pendingAlwaysAuthorizationUpgrade = false
        applyIndicatorPreference()
        guard enabled else { return }

        switch manager.authorizationStatus {
        case .notDetermined:
            pendingAlwaysAuthorizationUpgrade = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            // Denied/restricted access requires Settings. Always is already granted.
            break
        }
    }

    private func applyIndicatorPreference() {
        authorizationStatus = manager.authorizationStatus
        showsBackgroundLocationIndicator = !(reducesBackgroundLocationIndicator
            && authorizationStatus == .authorizedAlways)
        manager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator
    }

    func start() {
        guard !requested else { return }
        requested = true
        reconcileAuthorization()
    }

    func stop() {
        guard requested || started else { return }
        requested = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        status = .stopped
        started = false
    }

    /// Recheck an already requested keep-alive on foreground activation.
    /// This never starts or reconnects a developer location session.
    func reconcile() {
        reconcileAuthorization()
    }

    private func unavailable(_ status: BackgroundKeepAliveStatus) {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        self.status = status
        started = false
    }

    private func reconcileAuthorization() {
        applyIndicatorPreference()
        guard requested else { return }
        guard hasBackgroundMode else {
            unavailable(.missingBackgroundMode)
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .awaitingAuthorization
            started = false
            manager.requestWhenInUseAuthorization()
        case .denied:
            unavailable(CLLocationManager.locationServicesEnabled() ? .denied : .servicesDisabled)
        case .restricted:
            unavailable(.restricted)
        case .authorizedAlways, .authorizedWhenInUse:
            guard !started else { return }
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
            status = .starting
            started = true
        @unknown default:
            unavailable(.failed)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if pendingAlwaysAuthorizationUpgrade, reducesBackgroundLocationIndicator {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                pendingAlwaysAuthorizationUpgrade = false
                manager.requestAlwaysAuthorization()
            case .notDetermined:
                break
            default:
                pendingAlwaysAuthorizationUpgrade = false
            }
        }
        reconcileAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard requested, started, !locations.isEmpty else { return }
        status = .receivingUpdates
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard requested else { return }
        if (error as? CLError)?.code == .denied {
            unavailable(CLLocationManager.locationServicesEnabled() ? .denied : .servicesDisabled)
        } else {
            // Core Location may resume delivery after a transient error.
            // Keep the update request and background permission in place.
            status = .locationUnavailable
        }
    }
}
