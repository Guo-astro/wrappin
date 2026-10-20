import Foundation

// A request from App Shortcuts. AppModel checks preconditions and waits for the
// outcome; HomeView performs the request with the same code as its buttons.
struct ShortcutRequest: Equatable {
    enum Action: Equatable {
        case start(LocationTarget)
        case stop
        case restoreInterruptedSession
    }

    let id = UUID()
    let action: Action
}

enum ShortcutStopOutcome {
    case stopped
    case restored
    case nothingToStop
}

enum ShortcutFailure: Error, CustomLocalizedStringResourceConvertible {
    case notSetUp
    case notPaired
    case favouriteMissing
    case interruptedSessionPending
    case routeActive
    case busy
    case stopFailed(String)
    case stillRunning

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSetUp:
            LocalizedStringResource("Open WrapPin and finish setup first.")
        case .notPaired:
            LocalizedStringResource("Pair this iPhone in WrapPin first.")
        case .favouriteMissing:
            LocalizedStringResource("This favourite place is no longer saved in WrapPin.")
        case .interruptedSessionPending:
            LocalizedStringResource("A simulation was interrupted. Choose to restore or continue it in WrapPin first.")
        case .routeActive:
            LocalizedStringResource("A route simulation is running. Stop it in WrapPin first.")
        case .busy:
            LocalizedStringResource("WrapPin is busy with another location action. Try again when it finishes.")
        case .stopFailed(let message):
            // The message is already localized by the session coordinator.
            LocalizedStringResource(stringLiteral: message)
        case .stillRunning:
            LocalizedStringResource("Restoring is still in progress. Check WrapPin for the result.")
        }
    }
}

extension AppModel {
    /// Checks that a favourite can start and hands it to HomeView. It does not wait
    /// for the connection, which may still need the tunnel app.
    func requestShortcutStart(favouriteID: String) async throws -> LocationTarget {
        try await waitForShortcutReadiness()
        guard interruptedSession == nil else { throw ShortcutFailure.interruptedSessionPending }
        guard let target = favouriteLocations.first(where: { $0.id == favouriteID }) else {
            throw ShortcutFailure.favouriteMissing
        }
        guard !isRunningRouteSession else { throw ShortcutFailure.routeActive }
        guard !isStartingLocationSession, !isRestoringInterruptedSession, !deviceSession.isBusy else {
            throw ShortcutFailure.busy
        }

        shortcutRequest = ShortcutRequest(action: .start(target))
        return target
    }

    /// Stops the running simulation, or restores the real location after an
    /// interrupted one, and waits until the device answers.
    func performShortcutStop() async throws -> ShortcutStopOutcome {
        try await waitForShortcutReadiness()

        if interruptedSession != nil, !hasLiveLocationSession {
            guard !isRestoringInterruptedSession else { throw ShortcutFailure.busy }
            shortcutRequest = ShortcutRequest(action: .restoreInterruptedSession)
            await waitForShortcut(upTo: .seconds(3)) {
                self.isRestoringInterruptedSession || self.interruptedSessionError != nil
            }
            await waitForShortcut(upTo: Self.shortcutStopTimeout) { !self.isRestoringInterruptedSession }
            if isRestoringInterruptedSession { throw ShortcutFailure.stillRunning }
            guard interruptedSession == nil else {
                throw ShortcutFailure.stopFailed(
                    interruptedSessionError ?? String(localized: "The real location could not be restored. Check WrapPin for details.")
                )
            }
            return .restored
        }

        guard hasLiveLocationSession else { return .nothingToStop }
        shortcutRequest = ShortcutRequest(action: .stop)
        await waitForShortcut(upTo: Self.shortcutStopTimeout) { !self.hasLiveLocationSession }

        switch deviceSession.phase {
        case .idle:
            // An unconfirmed clear keeps a recovery record for the user to resolve.
            guard interruptedSession == nil else {
                throw ShortcutFailure.stopFailed(
                    interruptedSessionError ?? String(localized: "The real location could not be restored. Check WrapPin for details.")
                )
            }
            return .stopped
        case .failed(let message):
            throw ShortcutFailure.stopFailed(message)
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            throw ShortcutFailure.stillRunning
        }
    }

    func takeShortcutRequest() -> ShortcutRequest? {
        defer { shortcutRequest = nil }
        return shortcutRequest
    }

    // Native writes and clears each have a 15-second deadline; leave room for both.
    private static var shortcutStopTimeout: Duration { .seconds(60) }

    private var hasLiveLocationSession: Bool {
        if isStartingLocationSession { return true }
        switch deviceSession.phase {
        case .idle, .failed:
            return false
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            return true
        }
    }

    private func waitForShortcutReadiness() async throws {
        guard hasCompletedOnboarding else { throw ShortcutFailure.notSetUp }
        // A cold launch reads the pairing record from the keychain first.
        await waitForShortcut(upTo: .seconds(10)) {
            switch self.pairingStatus {
            case .checking, .importing: false
            case .paired, .notPaired, .failed: true
            }
        }
        guard case .paired = pairingStatus else { throw ShortcutFailure.notPaired }
    }

    private func waitForShortcut(upTo timeout: Duration, until condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }
        }
    }
}
