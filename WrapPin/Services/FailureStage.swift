enum FailureStage: String, CaseIterable {
    case pairingRecord
    case discovery
    case vpnConnection
    case pairVerification
    case tunnelCreation
    case tunnelConnection
    case tunnelSecurity
    case serviceDirectory
    case serviceHandshake
    case locationService
    case locationInitialWrite
    case locationActiveWrite
    case locationEngine
    case schedulerRegistration
    case schedulerSubmission
    case pairingAdvertisement
    case pairingConnection
    case pairingAuthentication
    case pairingExpired
    case pairingEngine
    case pairingStorage
    case pairingImport
    case pairingRead
    case locationPreparation
    case locationRestore
    case pairingUnknown
    case locationUnknown

    /// Maps the stage code reported by the native location engine
    /// (`LocationStage` in Native/WrapPinPairingFFI/src/lib.rs). Unknown,
    /// cancelled and unrecognised codes have no stage of their own.
    init?(nativeLocationStage code: Int32) {
        switch code {
        case 1: self = .pairingRecord
        case 2: self = .discovery
        case 3: self = .vpnConnection
        case 4: self = .pairVerification
        case 5: self = .tunnelCreation
        case 6: self = .tunnelConnection
        case 7: self = .tunnelSecurity
        case 8: self = .serviceDirectory
        case 9: self = .serviceHandshake
        case 10: self = .locationService
        case 11: self = .locationInitialWrite
        case 12: self = .locationActiveWrite
        case 13: self = .locationEngine
        case 14: self = .locationRestore
        default: return nil
        }
    }

    static let nativeLocationCancelledCode: Int32 = 15

    /// Classifies the pairing engine's English error text. Pass the original
    /// message, never a localized one. Location sessions report a stage code
    /// instead; see `init(nativeLocationStage:)`.
    static func classify(_ message: String, fallback: FailureStage) -> FailureStage {
        switch message {
        case "WrapPin could not securely store the new pairing.": return .pairingStorage
        case "iOS could not prepare the location session. Close WrapPin, reopen it, and try again.",
             "iOS could not register the secure pairing task. Close WrapPin, reopen it, and try again.": return .schedulerRegistration
        case "iOS could not keep pairing active in the background. Keep WrapPin open and try again.": return .schedulerSubmission
        case "Local Network access is required. Enable it in Settings › Apps › WrapPin, then try again.": return .pairingAdvertisement
        case "WrapPin could not open a local pairing connection.",
             "WrapPin could not determine its pairing port.",
             "The iPhone could not connect to WrapPin.",
             "The iPhone ended the pairing connection. Start pairing again when you are ready.": return .pairingConnection
        case "The code was not accepted. Start pairing again and enter the new code.": return .pairingAuthentication
        case "Pairing took too long. Return to WrapPin and try again.": return .pairingExpired
        case "WrapPin could not start its pairing engine.",
             "The pairing engine returned an empty record.": return .pairingEngine
        default: return fallback
        }
    }
}
