import Foundation

// Compile the production policy and record outside AppModel/Xcode.
enum RouteMode: String, Codable { case walking, driving }
enum FixedCoordinateMode: String, Codable { case gcj02, wgs84 }
struct LocationTarget: Codable, Equatable { let name: String }

@main
struct SessionRecoveryPolicyCheck {
    static func main() throws {
        let pending = SessionRecoveryRecord.fixed(at: LocationTarget(name: "New place"), mode: .wgs84)
        var active = SessionRecoveryRecord.route(
            from: LocationTarget(name: "Start"), to: LocationTarget(name: "End"),
            mode: .driving, coordinateMode: .gcj02, speedMetresPerSecond: 20
        )
        active.lastReportedLocation = LocationTarget(name: "Latest unsaved route point")
        active.updatedAt = Date(timeIntervalSinceReferenceDate: 123)

        let writingStages: [FailureStage] = [.locationInitialWrite, .locationActiveWrite, .locationRestore]
        for stage in writingStages {
            let kept = SessionRecoveryPolicy.recordAfterFailure(
                failureStage: stage, existingUnconfirmedRecord: nil,
                activeRecord: nil, pendingRecord: pending, isStoppingOrRestoring: false
            )
            precondition(kept == pending)
        }
        for stage in FailureStage.allCases where !writingStages.contains(stage) {
            for stopping in [false, true] {
                let freshFailure = SessionRecoveryPolicy.recordAfterFailure(
                    failureStage: stage, existingUnconfirmedRecord: nil,
                    activeRecord: nil, pendingRecord: pending, isStoppingOrRestoring: stopping
                )
                precondition(freshFailure == nil) // No previous record and no possible write.
            }
            let retryFailure = SessionRecoveryPolicy.recordAfterFailure(
                failureStage: stage, existingUnconfirmedRecord: active,
                activeRecord: nil, pendingRecord: pending, isStoppingOrRestoring: false
            )
            precondition(retryFailure == active) // Includes a different newly selected location.
        }

        let latest = SessionRecoveryPolicy.recordAfterFailure(
            failureStage: .locationActiveWrite, existingUnconfirmedRecord: nil,
            activeRecord: active, pendingRecord: pending, isStoppingOrRestoring: false
        )
        precondition(latest == active)
        let saved = try JSONEncoder().encode(latest!)
        let decoded = try JSONDecoder().decode(SessionRecoveryRecord.self, from: saved)
        precondition(decoded == active)

        let stopped = SessionRecoveryPolicy.recordAfterFailure(
            failureStage: .locationRestore, existingUnconfirmedRecord: nil,
            activeRecord: active, pendingRecord: nil, isStoppingOrRestoring: true
        )
        precondition(stopped != nil && stopped == active) // Supplies the in-process recovery view.
        let restoreRetry = SessionRecoveryPolicy.recordAfterFailure(
            failureStage: .tunnelConnection, existingUnconfirmedRecord: stopped,
            activeRecord: nil, pendingRecord: pending, isStoppingOrRestoring: true
        )
        precondition(restoreRetry == active)
        let initialRetry = SessionRecoveryPolicy.recordAfterFailure(
            failureStage: .locationInitialWrite, existingUnconfirmedRecord: active,
            activeRecord: nil, pendingRecord: pending, isStoppingOrRestoring: false
        )
        precondition(initialRetry == active) // Only reaching .active may replace it.
        for stage in FailureStage.allCases {
            let clearedAfterFailure = SessionRecoveryPolicy.recordAfterFailure(
                failureStage: stage, existingUnconfirmedRecord: active,
                activeRecord: active, pendingRecord: pending,
                isStoppingOrRestoring: true, didConfirmLocationClear: true
            )
            precondition(clearedAfterFailure == nil) // A confirmed clear overrides every failure stage.
        }
        precondition(!SessionRecoveryPolicy.shouldPreserveRecord(
            failureStage: nil, hasUnconfirmedRecord: true,
            isStoppingOrRestoring: true, didConfirmLocationClear: true
        ))
        print("Session recovery policy passed: write stages, fresh failures, retry/new-place failures, route progress, failed stops and confirmed clears")
    }
}
