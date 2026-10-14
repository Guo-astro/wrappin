/// Pure recovery decisions shared by every location-session startup path.
/// A saved location describes an unconfirmed previous operation, not proof
/// that the device is still applying that location.
enum SessionRecoveryPolicy {
    static func shouldPreserveRecord(
        failureStage: FailureStage?,
        hasUnconfirmedRecord: Bool,
        isStoppingOrRestoring: Bool,
        didConfirmLocationClear: Bool = false
    ) -> Bool {
        if didConfirmLocationClear { return false }
        if hasUnconfirmedRecord { return true }
        switch failureStage {
        case .locationInitialWrite, .locationActiveWrite, .locationRestore:
            return true
        case nil:
            // An unclassified stop failure cannot confirm that a write was cleared.
            return isStoppingOrRestoring
        default:
            return false
        }
    }

    static func recordAfterFailure(
        failureStage: FailureStage?,
        existingUnconfirmedRecord: SessionRecoveryRecord?,
        activeRecord: SessionRecoveryRecord?,
        pendingRecord: SessionRecoveryRecord?,
        isStoppingOrRestoring: Bool,
        didConfirmLocationClear: Bool = false
    ) -> SessionRecoveryRecord? {
        guard shouldPreserveRecord(
            failureStage: failureStage,
            hasUnconfirmedRecord: existingUnconfirmedRecord != nil || activeRecord != nil,
            isStoppingOrRestoring: isStoppingOrRestoring,
            didConfirmLocationClear: didConfirmLocationClear
        ) else { return nil }
        // Never replace a previous unconfirmed record with a failed new attempt.
        return existingUnconfirmedRecord ?? activeRecord ?? pendingRecord
    }
}
