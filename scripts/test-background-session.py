#!/usr/bin/env python3
"""Exercise the production background keep-alive with offline platform fakes."""

from pathlib import Path
import plistlib
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
KEEP_ALIVE = ROOT / "WrapPin/Services/BackgroundLocationKeepAlive.swift"
PAIRING = ROOT / "WrapPin/Services/Pairing/OnDevicePairingCoordinator.swift"
SESSION = ROOT / "WrapPin/Services/Tunnel/LocalDeviceSessionCoordinator.swift"
INFO = ROOT / "Configuration/WrapPin-Info.plist"


def method_block(source: str, marker: str) -> str:
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        depth += (source[index] == "{") - (source[index] == "}")
        if depth == 0:
            return source[start:index + 1]
    raise AssertionError(f"unterminated block: {marker}")


keep_alive = KEEP_ALIVE.read_text(encoding="utf-8")
keep_alive = (
    keep_alive
    .replace("import CoreLocation\n", "")
    .replace("import Observation\n", "")
    .replace("@Observable\n", "")
    .replace("@preconcurrency ", "")
)

fakes = r'''
import Foundation
let kCLLocationAccuracyKilometer = 1000.0
let kCLDistanceFilterNone = -1.0
enum CLAuthorizationStatus {
    case notDetermined, denied, restricted, authorizedAlways, authorizedWhenInUse
}
struct CLLocation {}
struct CLError: Error {
    enum Code { case locationUnknown, denied, other }
    let code: Code
}
protocol CLLocationManagerDelegate: AnyObject {}
final class CLLocationManager {
    weak var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy = 0.0
    var distanceFilter = 0.0
    var pausesLocationUpdatesAutomatically = true
    var showsBackgroundLocationIndicator = false
    var allowsBackgroundLocationUpdates = false
    var authorizationStatus = CLAuthorizationStatus.notDetermined
    static var enabled = true
    static func locationServicesEnabled() -> Bool { enabled }
    var starts = 0
    var stops = 0
    var requests = 0
    func startUpdatingLocation() { starts += 1 }
    func stopUpdatingLocation() { stops += 1 }
    func requestWhenInUseAuthorization() { requests += 1 }
}
'''

checks = r'''
@main struct Tests {
    @MainActor static func main() {
        let manager = CLLocationManager()
        let keepAlive = BackgroundLocationKeepAlive(
            manager: manager,
            hasBackgroundMode: true
        )

        keepAlive.start()
        keepAlive.start()
        precondition(manager.requests == 1)
        precondition(manager.starts == 0)
        precondition(keepAlive.status == .awaitingAuthorization)

        manager.authorizationStatus = .authorizedWhenInUse
        keepAlive.locationManagerDidChangeAuthorization(manager)
        precondition(manager.starts == 1)
        precondition(keepAlive.started)
        precondition(manager.allowsBackgroundLocationUpdates)
        precondition(!manager.pausesLocationUpdatesAutomatically)
        keepAlive.locationManager(manager, didUpdateLocations: [CLLocation()])
        precondition(keepAlive.status == .receivingUpdates)

        keepAlive.locationManager(
            manager,
            didFailWithError: CLError(code: .locationUnknown)
        )
        precondition(keepAlive.started)
        precondition(keepAlive.status == .locationUnavailable)

        let stopsBeforeError = manager.stops
        keepAlive.locationManager(manager, didFailWithError: CLError(code: .other))
        precondition(keepAlive.status == .locationUnavailable)
        precondition(keepAlive.started && manager.allowsBackgroundLocationUpdates)
        precondition(manager.stops == stopsBeforeError)
        keepAlive.locationManager(manager, didUpdateLocations: [CLLocation()])
        precondition(keepAlive.status == .receivingUpdates)

        keepAlive.reconcile()
        precondition(manager.starts == 1) // No duplicate active update request.
        manager.authorizationStatus = .denied
        keepAlive.reconcile() // No authorization callback: reconcile must notice it.
        precondition(!keepAlive.started && !manager.allowsBackgroundLocationUpdates)
        precondition(keepAlive.status == .denied)
        manager.authorizationStatus = .authorizedWhenInUse
        keepAlive.reconcile()
        precondition(keepAlive.started && manager.starts == 2)
        CLLocationManager.enabled = false
        manager.authorizationStatus = .denied
        keepAlive.reconcile()
        precondition(!keepAlive.started && keepAlive.status == .servicesDisabled)
        CLLocationManager.enabled = true
        manager.authorizationStatus = .authorizedWhenInUse
        keepAlive.reconcile()
        precondition(keepAlive.started && manager.starts == 3)

        keepAlive.locationManager(manager, didFailWithError: CLError(code: .denied))
        precondition(!keepAlive.started && !manager.allowsBackgroundLocationUpdates)
        keepAlive.reconcile()
        precondition(keepAlive.started && manager.starts == 4)

        keepAlive.stop()
        precondition(!keepAlive.started)
        precondition(!manager.allowsBackgroundLocationUpdates)
        precondition(keepAlive.status == .stopped)
        keepAlive.reconcile()
        precondition(!keepAlive.started && manager.starts == 4)

        for authorization: CLAuthorizationStatus in [.denied, .restricted] {
            let deniedManager = CLLocationManager()
            deniedManager.authorizationStatus = authorization
            let deniedKeepAlive = BackgroundLocationKeepAlive(
                manager: deniedManager,
                hasBackgroundMode: true
            )
            deniedKeepAlive.start()
            precondition(!deniedKeepAlive.started)
            precondition(deniedManager.starts == 0)
        }

        let missing = BackgroundLocationKeepAlive(
            manager: manager,
            hasBackgroundMode: false
        )
        missing.start()
        precondition(missing.status == .missingBackgroundMode)
        precondition(!missing.started)
        print("Background keep-alive lifecycle checks passed")
    }
}
'''

with tempfile.TemporaryDirectory() as temporary_directory:
    temporary = Path(temporary_directory)
    source = temporary / "tests.swift"
    binary = temporary / "tests"
    source.write_text(fakes + keep_alive + checks, encoding="utf-8")
    subprocess.run(
        [
            "xcrun", "swiftc", "-parse-as-library",
            "-module-cache-path", str(temporary / "cache"),
            str(source), "-o", str(binary),
        ],
        check=True,
    )
    subprocess.run([str(binary)], check=True)

pairing = PAIRING.read_text(encoding="utf-8")
session = SESSION.read_text(encoding="utf-8")
info = plistlib.loads(INFO.read_bytes())

assert "BGTaskScheduler.shared" not in pairing
assert "runNativePairing()" in method_block(pairing, "    func start(")
assert "beginBackgroundAssertion()" in method_block(pairing, "    func start(")
assert "submitTaskRequest" not in session
assert "BGTaskScheduler.shared" not in session
assert "runNativeLocationSession()" in method_block(session, "    private func submitLocationTask()")
assert "backgroundKeepAlive.start()" in method_block(session, "    fileprivate func nativeLocationStarted()")
for marker in [
    "    func stop()",
    "    private func nativeLocationFinished(",
    "    private func fail(",
    "    private func clearPendingSession()",
]:
    assert "backgroundKeepAlive.stop()" in method_block(session, marker)
assert info.get("UIBackgroundModes") == ["location"]
assert "BGTaskSchedulerPermittedIdentifiers" not in info
print("Pairing and location sessions are independent of BGTaskScheduler")
