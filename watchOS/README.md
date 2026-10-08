# AERTEX watchOS companion — first development milestone

This is a **separate watchOS app prototype**. It is not included in the
iPhone `iOS重构版/Package.swift` target and will not be installed by
`xtool dev run` for the phone.

## Architecture

- `AERTEXWatch/AERTEXWatchApp.swift`: watch-native SwiftUI status/dashboard
  and `WCSession` message client.
- iPhone is the trusted AERTEX ID authentication holder, and will provide a
  vetted WatchConnectivity reply for `type = aertex.watch.status.v1`.
- Watch should not receive, store or display Supabase access/refresh tokens,
  provider API keys or ActivityWatch device-upload tokens.
- The current watch screen safely presents 'waiting for iPhone' until an
  authenticated and paired phone bridge is available. No fake data.
- This first revision does **not** stream Intelligence chats or access HealthKit.

## Remaining before shipping

1. Set up a watchOS App executable target and a companion bundle identifier
   tied to the iPhone app; configure signing/provisioning for the actual Watch.
2. Implement the authenticated iPhone `WCSessionDelegate` response and test
   serialization/foreground + background reachability. Never copy bearer tokens.
3. Build for watchOS SDK (not the iPhone SDK) and deploy to a physical Watch.
4. Add accessibility, reduced-motion, wrist-size UI and explicit session errors.
5. Consider a separate watch-native Intelligence compose/send path only after
   rate-limit/authentication and microphone/dictation flows are validated.

The watchOS project remains isolated on the iOS development PR until these
steps succeed.
