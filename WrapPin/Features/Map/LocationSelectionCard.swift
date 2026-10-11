import Foundation
import SwiftUI
import UIKit

struct LocationSelectionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let location: LocationTarget?
    let isFavourite: Bool
    let isResolvingAddress: Bool
    let isPaired: Bool
    let sessionPhase: DeviceSessionPhase
    let tunnelHandoffApp: TunnelHandoffApp
    let usesBuiltInTunnel: Bool
    let tunnelAppInstallURL: URL
    let previewingRouteMode: RouteMode?
    let routeError: String?
    let coordinateMode: FixedCoordinateMode
    let recommendedCoordinateMode: FixedCoordinateMode
    let onCoordinateModeChange: (FixedCoordinateMode) -> Void
    let onToggleFavourite: () -> Void
    let onClearSelection: () -> Void
    let onPreviewRoute: (RouteMode) -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    @AppStorage("isLocationCardCollapsed") private var isCollapsed = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.8)))
    private var dragOffset: CGFloat = 0
    @State private var didCopyCoordinates = false
    @State private var isConfirmingStop = false

    var body: some View {
        VStack(spacing: 2) {
            if location != nil {
                collapseHandle
            }

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent
                }
                .frame(maxHeight: 460)
            } else {
                cardContent
            }
        }
        .padding([.horizontal, .bottom], 18)
        .padding(.top, location == nil ? 18 : 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        .offset(y: dragOffset)
        .sensoryFeedback(.selection, trigger: isCollapsed)
        // The accessibility layout scrolls vertically, so it only collapses through the handle.
        .highPriorityGesture(collapseDrag, isEnabled: location != nil && !dynamicTypeSize.isAccessibilitySize)
        .confirmationDialog(
            "Stop the simulated location and restore your real location?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop & Restore", role: .destructive, action: onStop)
            Button("Keep Simulated Location", role: .cancel) {}
        } message: {
            Text("WrapPin will end the simulated location and restore this iPhone's real location.")
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let location {
                locationHeader(for: location)

                if !isCollapsed {
                    coordinateModeSelection
                        .transition(detailTransition)
                }

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: primarySymbol)
                        }
                        Text(primaryTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isShowingActiveTarget ? .red : .blue)
                .disabled(isPrimaryDisabled)

                if canPreviewRoute && !isCollapsed {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) {
                            routePreviewButton(for: .walking)
                            routePreviewButton(for: .driving)
                        }
                    } else {
                        HStack(spacing: 8) {
                            routePreviewButton(for: .walking)
                            routePreviewButton(for: .driving)
                        }
                        .transition(detailTransition)
                    }
                }

                if let routeError {
                    Text(routeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isActive && !isShowingActiveTarget {
                    Button("Stop & Restore", role: .destructive) {
                        isConfirmingStop = true
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)
                }

                if !isCollapsed || !isRoutineStatus {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(isFailure ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }

                if shouldOfferTunnelApp {
                    Link(destination: tunnelAppInstallURL) {
                        Label(
                            String(format: NSLocalizedString("Get %@", comment: ""), tunnelHandoffApp.title),
                            systemImage: "arrow.up.right.square"
                        )
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "hand.tap")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose a location")
                            .font(.headline)
                        Text("Search above or tap anywhere on the map.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var collapseHandle: some View {
        Button {
            setCollapsed(!isCollapsed)
        } label: {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollapsed ? "Expand location details" : "Collapse location details")
    }

    private var collapseDrag: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragOffset) { value, offset, _ in
                guard !reduceMotion else { return }
                // Follows the finger with resistance; pulling the "wrong" way barely moves.
                let vertical = value.translation.height
                let leadsToChange = isCollapsed ? vertical < 0 : vertical > 0
                let pull = vertical * (leadsToChange ? 0.35 : 0.12)
                offset = min(max(pull, -28), 28)
            }
            .onEnded { value in
                let vertical = value.translation.height
                guard abs(vertical) > abs(value.translation.width), abs(vertical) > 40 else { return }
                setCollapsed(vertical > 0)
            }
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard collapsed != isCollapsed else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82)) {
            isCollapsed = collapsed
        }
    }

    // Details fade and settle from slightly below while the card resizes around them.
    private var detailTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.97, anchor: .top))
    }

    private var coordinateModeBinding: Binding<FixedCoordinateMode> {
        Binding(
            get: { coordinateMode },
            set: { onCoordinateModeChange($0) }
        )
    }

    // Keeps the active mode visible and switchable while the full selector is collapsed.
    private var coordinateModeChip: some View {
        Menu {
            Picker("Simulation coordinate mode", selection: coordinateModeBinding) {
                Text("GCJ-02 correction").tag(FixedCoordinateMode.gcj02)
                Text("WGS84 unchanged").tag(FixedCoordinateMode.wgs84)
            }
        } label: {
            HStack(spacing: 3) {
                Text(verbatim: coordinateMode == .gcj02 ? "GCJ-02" : "WGS84")
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(minHeight: 30)
            .background(.blue.opacity(0.12), in: Capsule())
            .fixedSize()
        }
        .disabled(isWorking)
        .accessibilityLabel("Simulation coordinate mode")
        .accessibilityValue(coordinateMode == .gcj02 ? "GCJ-02" : "WGS84")
    }

    private var coordinateModeSelection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Simulation coordinate mode")
                .font(.subheadline.weight(.semibold))

            Picker("Simulation coordinate mode", selection: coordinateModeBinding) {
                Text("GCJ-02 correction").tag(FixedCoordinateMode.gcj02)
                Text("WGS84 unchanged").tag(FixedCoordinateMode.wgs84)
            }
            .pickerStyle(.segmented)
            .disabled(isWorking)

            Text(recommendedCoordinateMode == .gcj02
                ? String(localized: "For mainland China, try GCJ-02 first. If the position is off, switch to WGS84.")
                : String(localized: "Outside mainland China, try WGS84 first. If the position is off, switch to GCJ-02."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isShowingActiveTarget {
                Text("Switching modes updates the current simulated location immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func routePreviewButton(for mode: RouteMode) -> some View {
        Button { onPreviewRoute(mode) } label: {
            HStack(spacing: 6) {
                if previewingRouteMode == mode {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: mode.symbol)
                }
                Text(mode == .walking ? String(localized: "Preview Walk") : String(localized: "Preview Drive"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(previewingRouteMode != nil)
    }

    @ViewBuilder
    private func locationHeader(for location: LocationTarget) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                locationSummary(for: location)
                HStack(spacing: 4) {
                    Spacer()
                    locationActions
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                locationSummary(for: location)
                Spacer(minLength: 0)
                locationActions
            }
        }
    }

    private func locationSummary(for location: LocationTarget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                HStack(spacing: 7) {
                    if isResolvingAddress {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityHidden(true)
                    }

                    Text(locationDescription(for: location))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : (isCollapsed ? 1 : 2))

                    if isCollapsed {
                        coordinateModeChip
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    } else {
                        Button {
                            copyCoordinates(for: location)
                        } label: {
                            Label(
                                didCopyCoordinates ? "Coordinates copied" : "Copy coordinates",
                                systemImage: didCopyCoordinates ? "checkmark" : "doc.on.doc"
                            )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(didCopyCoordinates ? .green : .blue)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            didCopyCoordinates ? "Coordinates copied" : "Copy coordinates"
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var locationActions: some View {
        Button(action: onToggleFavourite) {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isFavourite ? .pink : .secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isResolvingAddress)
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")

        if canClearSelection {
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selected location")
        }
    }

    private func locationDescription(for location: LocationTarget) -> String {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return name }

        if subtitle.lowercased().hasPrefix(name.lowercased()) {
            let remainder = subtitle.dropFirst(name.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if !remainder.isEmpty {
                return remainder
            }
        }

        return subtitle
    }

    private func copyCoordinates(for location: LocationTarget) {
        UIPasteboard.general.string = String(
            format: "%.6f, %.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            location.latitude,
            location.longitude
        )
        didCopyCoordinates = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyCoordinates = false
        }
    }

    private var isActive: Bool {
        if case .active = sessionPhase { return true }
        return false
    }

    private var isShowingActiveTarget: Bool {
        guard
            let location,
            case .active(let activeTarget) = sessionPhase
        else { return false }
        return location.id == activeTarget.id
    }

    private var isWorking: Bool {
        switch sessionPhase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    private var isFailure: Bool {
        if case .failed = sessionPhase { return true }
        return false
    }

    // Status copy that only repeats what the buttons already say; hidden while collapsed.
    private var isRoutineStatus: Bool {
        switch sessionPhase {
        case .idle:
            isPaired
        case .active:
            isShowingActiveTarget
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var shouldOfferTunnelApp: Bool {
        guard case .failed(let message) = sessionPhase else { return false }
        return message == String(localized: "Could not open the selected tunnel app. Check that it is installed and supports app links.")
    }

    private var primaryTitle: String {
        switch sessionPhase {
        case .openingLocalDevVPN:
            usesBuiltInTunnel
                ? String(localized: "Starting built-in tunnel…")
                : String(format: NSLocalizedString("Opening %@…", comment: ""), tunnelHandoffApp.title)
        case .discovering:
            String(localized: "Finding This iPhone…")
        case .connecting:
            String(localized: "Starting Location…")
        case .active:
            isShowingActiveTarget
                ? String(localized: "Stop & Restore")
                : String(localized: "Update Location")
        case .stopping:
            String(localized: "Restoring Real Location…")
        case .failed:
            String(localized: "Try Again")
        case .idle:
            String(localized: "Start Location")
        }
    }

    private var primarySymbol: String {
        switch sessionPhase {
        case .active: isShowingActiveTarget ? "stop.circle.fill" : "location.fill"
        case .failed: "arrow.clockwise"
        case .idle: "location.fill"
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: "hourglass"
        }
    }

    private var isPrimaryDisabled: Bool {
        isResolvingAddress || isWorking || (!isPaired && !isActive)
    }

    private var canClearSelection: Bool {
        switch sessionPhase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var canPreviewRoute: Bool {
        guard !isResolvingAddress else { return false }
        return switch sessionPhase {
        case .idle, .active:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var statusMessage: String {
        switch sessionPhase {
        case .idle:
            return isPaired
                ? String(localized: "Start when ready. Stop restores this iPhone's real location.")
                : String(localized: "Pair this iPhone before starting location control.")
        case .openingLocalDevVPN:
            if usesBuiltInTunnel {
                return String(localized: "WrapPin is connecting its built-in device tunnel.")
            }
            return tunnelHandoffApp == .localDevVPN
                ? String(localized: "Wait for LocalDevVPN to connect and return. If it does not, return to WrapPin yourself.")
                : String(localized: "Turn on the tunnel in the selected app, then return to WrapPin.")
        case .discovering:
            return String(localized: "Finding the paired iPhone through the private local tunnel.")
        case .connecting:
            return String(localized: "Opening the secure location session.")
        case .active(let target):
            if !isShowingActiveTarget, let location {
                return String(
                    format: NSLocalizedString("Currently using %@. Update to move to %@.", comment: ""),
                    target.name,
                    location.name
                )
            }
            return String(
                format: NSLocalizedString(
                    "This iPhone is using %@. Stop & Restore ends the simulation and restores its real location.",
                    comment: ""
                ),
                target.name
            )
        case .stopping:
            return String(localized: "Restoring this iPhone's real location. Keep WrapPin open until this finishes.")
        case .failed(let message):
            return message
        }
    }

    private func primaryAction() {
        if isShowingActiveTarget {
            isConfirmingStop = true
        } else {
            onStart()
        }
    }
}
