# WrapPin 1.0.18 (Build 61)

[简体中文](Release-1.0.18.zh-CN.md)

## Main changes

This release improves interrupted-session recovery and stop handling, and adds an optional background location indicator preference.

- **Recover after an interruption:** coordinate-write failures and stops without device confirmation retain the last location and route progress. Continue simulation or restore the real location without restarting the app.
- **Bounded stop waiting:** coordinate writes and location clearing have deadlines, preventing an unresponsive device from leaving the app waiting indefinitely. The recovery entry remains when clearing is unconfirmed.
- **Improved background keep-alive handling:** temporary location errors retain update requests. Returning to the foreground rechecks authorization and keep-alive state; the home screen warns when keep-alive is unavailable.
- **Optional Reduce background location indicator:** off by default. Explicitly enabling it requires Always location authorization. Without that authorization, the existing display behavior remains. Turning the preference off does not revoke authorization; change it in system Settings.
- **Clearer tunnel handoff guidance:** the list selects the app to open and does not limit compatible software. Other proxy or VPN apps with a correctly configured compatible device tunnel can be enabled manually.

## Download and installation

- Standard: `WrapPin-Standard-1.0.18-build61-unsigned.ipa`, for SideStore or other self-signing methods.
- Tunnel: `WrapPin-Tunnel-1.0.18-build61-unsigned.ipa`, requiring a certificate and profiles with Packet Tunnel permission.
- Both files are unsigned and require iOS 27.0 or later. Use Standard with a free Apple account or SideStore.

SHA-256:

- Standard: `a897774a0dee14f8c2c7a24a9c97eaa041d281c441f116d1613f5164d92aaa57`
- Tunnel: `62e66c1036d1046532e30ed1d3e604f06403d8f01afa85988ad40e1d5d037ff2`

Both packages were built from commit `cd7a9ddca43320715b48a85e6c7832b1c79644a4` with Xcode 27.0 (`27A266a`). Later release-documentation changes do not alter the packaged source. The release is [v1.0.18](https://github.com/suversal/WrapPin/releases/tag/v1.0.18).

## Verification and limits

- The maintainer reported that the main features passed physical-device testing with Build 60, without recording individual cases. Build 61 has the same feature code and has not itself been installed on a device.
- Both schemes passed Debug and Release builds, all eight check scripts passed, and all ten Rust unit tests passed. Both IPA files passed package identity, resource, architecture, extension and ZIP-integrity checks.
- Recovery after an interruption is manual. There is no automatic reconnection or guarantee of uninterrupted background connectivity.
- Coordinate writes and location clearing each have a 15-second deadline. Stop can approach 30 seconds when a write completes near its deadline and clearing then times out. These deadlines depend on iOS allowing the app to execute.
- iOS controls the final indicator display and may periodically remind the user about background location use. Coordinates received for keep-alive are neither saved nor uploaded.
- Force-quitting WrapPin ends the simulation connection. A connected VPN does not mean simulation remains active.
- The existing mobile-data limitation is unchanged: the device connection through Shadowrocket, Surge or Loon remains unreliable; use Wi-Fi with these apps.
