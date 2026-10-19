# Jector

An iPhone remote for Android projectors: on-device English/Russian speech, a local tool-calling model, direct app search, and ADB over Wi-Fi. Currently validated on the Formovie S5 (Peppa, Android 9); other devices are rejected by the device check.

## Features

- **Remote:** navigation, absolute volume with readback, playback and Home.
- **Apps:** launch YouTube, Jellyfin TV, Rutube and VK Video; inline English/Russian searches open results on the projector. ATV Search is optional and off by default.
- **Voice:** Apple on-device speech → local Qwen3-1.7B → validated actions → review → projector. No model server or cloud speech fallback.
- **Settings:** LAN discovery/manual connection, Home launcher selection, model download/delete/load/unload, a collapsible ADB command reference, and diagnostics.

The app connects directly to network ADB. No Mac bridge is needed at runtime. Approve the phone's debugging key on the projector on first connection.

## Install

[Releases](https://github.com/tumpaksewu/jector/releases) contain an **unsigned IPA for re-signing**, not an App Store or directly installable build. Sign it with your own Apple provisioning profile using your preferred signing workflow, or build from source in Xcode.

No model weights are bundled. After installation, open **Settings → Models** and download Qwen3-1.7B Q4_K_M (1.28 GB). Q8_0 (2.17 GB) is also offered. Downloads are pinned and SHA-256 verified. Backgrounding unloads the model and disconnects ADB; reconnect when returning.

The internal bundle ID remains `app.aleko.ProjectorRemote` so existing development installations retain their app data when updated with the same signing identity. The display name, product, Xcode project and ADB device name are Jector. Re-signing under a different bundle ID/team can create a separate installation and key.

## Build

Requirements: macOS, Xcode 26 or newer, XcodeGen, and uv. Minimum iOS: 17. On-device recognition depends on the phone and installed language assets.

```sh
./Inference/prepare-runtime.sh
xcodegen generate
open Jector.xcodeproj
```

In Xcode, select the **Jector** target and your development team. Alternatively, create an ignored `Signing.xcconfig` containing `DEVELOPMENT_TEAM = YOUR_TEAM_ID`. The committed configuration contains no personal signing team.

Create an unsigned release archive:

```sh
./scripts/build-unsigned.sh
```

Output: `dist/Jector-v0.4.1-unsigned.ipa` and its SHA-256 checksum. The packaging script strips all embedded code signatures/provisioning and verifies every Mach-O binary has no signature load command. Temporary build products live under `work/`.

## Use

1. Put iPhone and projector on the same LAN; enable network ADB on the projector.
2. Tap **Connect**, discover the projector or enter its IPv4 address and ADB port, then approve its debugging prompt.
3. Use **Apps** to open an app or search within it. Results appear on the projector; select a result with **Remote**.
4. For voice, download/load a model, open **Voice**, choose English or Russian, record, finish, review, and run.

Examples: “Find space on YouTube”, “Найди космос в ВК Видео”, “Set volume to 28”, “Продолжи воспроизведение”. Search requires an explicit app and a query of 1–200 characters. The model has no raw shell access. Invalid plans are rejected in full; actions run in order and stop on error. Automatic execution is optional and off by default.

**Home:** Settings selects Projector default or a detected launcher; the preference is per projector and applies to both Home and voice. Explicit choices launch that activity directly. Existing projector accessibility overrides can still redirect FengOS to Projectivy. Disable Projectivy's “Override current launcher” if FengOS should remain visible. Jector does not change Android default-launcher or accessibility settings.

## Search routes and limits

- YouTube: `ACTION_VIEW` to `https://www.youtube.com/results?search_query=…`.
- Jellyfin: `ACTION_SEARCH` to `org.jellyfin.androidtv/.ui.startup.StartupActivity`, with a UTF-8 `query` extra.
- Rutube: `rutube://rutube.ru/search?query=…`.
- VK Video: `vkvideo://vk.com/search?query=…` (no root).
- Optional ATV Search: its `OPEN_SEARCH_RESULTS` action; never an automatic fallback.

Search verifies that the target app reaches the foreground; it does not collect results or verify that a title exists. Playback/navigation report delivery. App updates can change deep links. Voice interpretation may be wrong even when structurally valid; review is the default.

Discovery supports IPv4 network ADB, scanning at most 1,022 peers; wider networks are limited to the phone's local /24. Android pairing-code workflows, arbitrary Android devices, cross-app result aggregation and exact-title playback are not implemented.

## Validation and development

```sh
swift test --package-path Core
```

The core has 16 tests for endpoints, volume, shell-response integrity, search escaping/validation and launcher selection. The physical iPhone 17/S5 setup was verified for EN/RU speech, all four direct search routes, Home, volume and app launching. The local Q4 model matched 29/32 exact plans in a small synthetic set; the other three were safely rejected. These are smoke/regression checks, not general accuracy guarantees.

**Settings → Diagnostics** includes speech probing and 32 model checks that send no projector actions. Raw local device reports, screenshots, build logs and signing files are excluded from Git.

- `App/`: SwiftUI, connection/model state and speech capture.
- `Core/`: shared ADB implementation, parsers, validation and Mac probes.
- `Inference/`: pinned llama.cpp runtime, model catalog, prompt and JSON grammar.
- `scripts/`: unsigned build and IPA packaging.

Dependency licenses/notices are in `THIRD_PARTY_NOTICES.txt` and `App/Resources/Licenses`. SwiftADB is pinned; model weights and the runtime XCFramework are downloaded separately, not committed.
