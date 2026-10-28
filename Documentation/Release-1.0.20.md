# WrapPin 1.0.20 (Build 66)

[简体中文](Release-1.0.20.zh-CN.md)

## Main changes

This release adds overseas place search, accepts more pasted coordinate formats and records more detail when a location session fails.

- **Overseas search:** Apple Maps data on iPhones in mainland China has few overseas places, so searching for Tokyo Tower or the Eiffel Tower finds same-named places in China. Tap **Domestic** at the end of the search box to switch to **Overseas** and search with Geoapify (OpenStreetMap data). Up to five candidates appear, each with a precision label; an orange label means only an approximate position was found. A query starting with a Chinese country name, such as 法国巴黎, is limited to that country. For a house-number query only a result at that house number is shown as exact.
- **Pasted coordinates:** besides `35.6586, 139.7454`, the search box accepts full-width commas, spaces, degree signs with N/S/E/W, 北纬/东经 and degrees-minutes-seconds, in both Domestic and Overseas modes. When a search finds nothing, WrapPin suggests pasting coordinates.
- **Map messages:** error messages on the map fade after a few seconds, can be tapped away and animate in and out instead of staying on screen.
- **Diagnostics:** when a location session fails, Copy Diagnostics now includes the underlying error kind and code (no device text or location), to help investigate reports such as pairing verification failures. The connection check no longer says the pairing is valid; the iPhone verifies it when a session starts.

## Overseas search limits

- In mainland China Geoapify may not be reachable without a proxy. The connection message suggests a proxy or pasted coordinates.
- Results come from OpenStreetMap. Landmarks are usually found; many street addresses are not, especially in Japan. Check orange results before simulating, or paste coordinates.
- Searches run only when you tap Search. Each iPhone may run 50 overseas searches a day, and repeated searches within seven days use the result saved on the iPhone. All installations share one free Geoapify quota; if it is suspended, overseas search shows an unavailable message and coordinate input still works.
- Only the search text is sent to Geoapify, and only in Overseas mode. See [Privacy](Privacy.md).

## Download and installation

- Standard: `WrapPin-Standard-1.0.20-build66-unsigned.ipa`, for SideStore or other self-signing methods.
- Tunnel: `WrapPin-Tunnel-1.0.20-build66-unsigned.ipa`, requiring a certificate and profiles with Packet Tunnel permission.
- Both files are unsigned and require iOS 27.0 or later. Use Standard with a free Apple account or SideStore.

SHA-256:

- Standard: `7e2065489239572d983ebd08588d75e05d99221ba9e6f5ed32837f2b2dd4fb0b`
- Tunnel: `427d0d4b995ce49dbd6aa092d24e554719fe76aae7fc622cd571d93aba273322`

Both packages were built from commit `917bccd66392ca91180f8c412ad685cb6351f488` with Xcode 27.0 (`27A266a`). Later release-documentation changes do not alter the packaged source. The release is [v1.0.20](https://github.com/suversal/WrapPin/releases/tag/v1.0.20).

## Verification and limits

- The maintainer installed the Build 64 test package on a physical iPhone and used overseas search; this found that Geoapify was not reachable without a proxy in mainland China and that map messages stayed on screen, both addressed in this release. Builds 65 and 66 have not been installed on a device, and the new diagnostics detail has not yet been observed on a device.
- Both schemes passed Debug and Release builds, all ten check scripts passed, and all twelve Rust unit tests passed. Both IPA files passed package identity, version, extension presence or absence and ZIP-integrity checks.
- Overseas search results for a test set of Chinese and English queries were checked against the production Geoapify API through a proxy before release.
- Overseas points inside the mainland coordinate-mode envelope, such as Seoul, are still recommended GCJ-02; switch them to WGS-84 manually.
- No statistics event was added. No TelemetryDeck identifiers were configured for this build, so it sends no usage statistics.
