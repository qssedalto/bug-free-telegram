# AERTEX Watch — watchOS 10+ companion (AERTEX 2.2)

The Apple Watch companion is now part of the **same Xcode project** as the
native AERTEX iPhone app, while the Linux/xtool SwiftPM build remains available.

## Implemented

- Native SwiftUI Watch UI, with a cloud ActivityWatch source count, last
  computer name, last sync time, status refresh and clear error states.
- WatchConnectivity `sendMessage` when the paired iPhone app is reachable.
- Coalesced, sanitized `updateApplicationContext` snapshots for background
  delivery when the Watch app next opens.
- Watch shows cached-snapshot labeling instead of pretending old data is live.
- The iPhone keeps **all** AERTEX ID tokens in its own secure store. No bearer
  token, provider API key, or ActivityWatch upload token is transferred.
- Signed-out state clears the Watch status sent by the iPhone.
- Single-target watchOS `AERTEXWatch` app embedded in the iPhone app at
  `AERTEX.app/PlugIns/AERTEXWatch.app`.

The Watch screen shows **computer ActivityWatch data synced to the AERTEX
cloud**. It does not collect Apple Watch Activity rings, health, or workouts.

## Build

`iOS重构版/project.yml` contains both `AERTEX` (iOS) and `AERTEXWatch`
(watchOS) targets. The GitHub Actions workflow
`.github/workflows/aertex-ios-build.yml` uses a standard `macos-26` runner
with Xcode 26.6, builds both targets against their own Apple SDKs, checks that
the Watch app is embedded in the iPhone product, and publishes an **unsigned**
`AERTEX-unsigned.ipa`.

Combined cloud build verified on 2026-10-09:
https://github.com/qssedalto/bug-free-telegram/actions/runs/37946720598

## Real device testing is still required

- Sign the iOS app **and the nested watchOS app**, using matching identifiers
  and suitable Apple provisioning profiles/entitlements.
- Install the properly signed iOS companion on an iPhone paired with an
  eligible Apple Watch. The unsigned IPA cannot be installed directly.
- Open AERTEX on the iPhone, sign in, then open AERTEX Watch and refresh.
- Test foreground/background connectivity, sign-out clearing, accessibility,
  small Watch displays, and actual installation before calling this a release.

This is **not** a standalone Watch app: the current data path intentionally
relies on the signed-in iPhone.
