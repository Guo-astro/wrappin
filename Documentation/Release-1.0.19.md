# WrapPin 1.0.19 (Build 63)

[简体中文](Release-1.0.19.zh-CN.md)

## Main changes

This release adds Shortcuts support, four more tunnel handoff apps and coordinate mode memory.

- **Shortcuts:** two actions, **Simulate Favourite Place** and **Stop and Restore Real Location**, appear in the Shortcuts app, Spotlight and Siri after installation and can be used in automations. Both open WrapPin. Starting does not wait for the connection; stopping waits for the device and reports a failure when clearing is unconfirmed. Settings → Shortcuts explains them and opens WrapPin in the Shortcuts app.
- **More tunnel handoff apps:** Stash, Egern, Quantumult X and sing-box. Stash and Egern are asked to start their tunnel; Quantumult X and sing-box are opened, and their tunnel is turned on manually. WrapPin never reads or changes their configuration.
- **Coordinate mode memory:** saved and recent places use the coordinate mode last used there. A new place within 100 km of the last manual change uses that choice. Reset WrapPin clears this memory.

## Download and installation

- Standard: `WrapPin-Standard-1.0.19-build63-unsigned.ipa`, for SideStore or other self-signing methods.
- Tunnel: `WrapPin-Tunnel-1.0.19-build63-unsigned.ipa`, requiring a certificate and profiles with Packet Tunnel permission.
- Both files are unsigned and require iOS 27.0 or later. Use Standard with a free Apple account or SideStore.

SHA-256:

- Standard: `09cb9d4dc9754a5f41ebc55d6dd325356dc38006126ff9e3683d90330e5dcf10`
- Tunnel: `b47260db83b7bcbbe1b67554856209ea1984b0147803e74b766d0572b284db76`

Both packages were built from commit `81c70a4b8cfe33e412a90b22d9d06cdf5a594795` with Xcode 27.0 (`27A266a`). Later release-documentation changes do not alter the packaged source. The release is [v1.0.19](https://github.com/suversal/WrapPin/releases/tag/v1.0.19).

## Verification and limits

- The maintainer reported that the 1.0.18 Build 62 test package, with the same feature code, worked on a physical device, including both shortcuts, without recording individual cases. Build 63 changes only the version and has not itself been installed on a device.
- Both schemes passed Debug and Release builds, all eight check scripts passed, and all ten Rust unit tests passed. Both IPA files passed package identity, App Shortcuts metadata, extension and ZIP-integrity checks.
- Shortcuts provide favourite names and descriptions to Shortcuts and Siri on the device; coordinates are not provided. No statistics event was added.
- Shortcuts do not start a session while an interrupted simulation is pending, while a route simulation is running, or before setup and pairing are complete. Recovery remains a manual choice.
- The existing mobile-data limitation applies to third-party tunnel apps; use Wi-Fi with them.
