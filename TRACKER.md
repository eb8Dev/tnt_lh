# Tracker: Cream N Crust rebrand, iOS, foldables

Started 2026-10-11. Covers the customer app (`flutter_tnt_lh`), rider app
(`tnt_rider`), backend (`teasntrees_backend`) and web app (`tnt-lh-customer`).

**Rule:** every box here gets ticked, whatever detours happen along the way.
Detours go in the Deviations log at the bottom; they never replace an item.

Work branch in both app repos: `cnc-ios-foldable`.

## Phase 0 — Baseline

- [x] 0.1 Commit the uncommitted July work in both apps (customer `9fabedb`, rider `2f9a31b`)

## Phase 1 — Little H → Cream N Crust (what the public sees)

Decision 2026-10-11: change only what users see for now. The internal brand
key stays `littleh` (API URLs, database, code identifiers) until Phase 4.

- [x] 1.1 Customer app: all visible wording says Cream N Crust (`e0b6669`; names live in `lib/core/brand.dart`)
- [x] 1.2 Customer app: logo swapped (PNG from the supplied image for now)
- [x] 1.3 Customer app: bakery theme colours retuned to the logo (chocolate brown `#63290C`, strawberry pink `#E56B8F`) — owner to eyeball
- [x] 1.4 Customer app: app name on the home screen (Android "Teas n Trees / Cream N Crust", iOS "TNT & CNC") — owner to confirm the names
- [x] 1.5 Rider app: store name, bakery detection, app name (`c7a2c54`; Android label "TNT - CNC Riders")
- [ ] 1.6 Backend: user-visible strings (outlet name, portal messages, coupon message) — coded on branch `cnc-rebrand` (`0f69bda`); **not live until merged and pushed to `main`**
- [ ] 1.7 Web app (`tnt-lh-customer`): visible wording and logo — coded on branch `cnc-rebrand` (`aad3218`), builds; **not yet checked in a browser or deployed to the VM**
- [ ] 1.8 Replace the stopgap PNG with the final SVG logo when it arrives
- [ ] 1.9 Store listings: Play listing text and screenshots (owner, in Play Console)
- [ ] 1.10 Admin panels: visible wording (their team; separate repos)

Must not change: app IDs (`com.manuen.tnt_lh`, `com.manuen.tntLh`,
`com.teasntrees.tnt_rider`, `com.teasntrees.tntRider`), Firebase project
`tnt-lh`, keystore aliases, Dart package name `tnt_lh`.

## Phase 2 — iOS

- [x] 2.1 Customer app builds and launches on the iOS simulator (iPhone 17 Pro Max, iOS 26.5; onboarding renders)
- [ ] 2.2 Customer app core flow on iOS: login, menu, cart, checkout, order tracking map, address picker, profile photo
  - [x] Phone-login crash fixed: Firebase phone-auth URL scheme was missing, and the Google sign-in scheme was the literal placeholder `REVERSED_CLIENT_ID`
  - [x] Notification prompt no longer blocks the first frame; asked on the signed-in home screen, and the push token is now registered right after login
  - [ ] Each step of the flow confirmed by hand on the simulator
- [x] 2.3 Rider app builds and launches on the iOS simulator (first ever iOS build; login screen renders, API URL loads)
- [ ] 2.4 Rider app core flow on iOS: login, go online, accept, navigate, proof photo, complete; background location
- [x] 2.5 Align iOS deployment target (customer 15.6, rider 15.0, project and Podfile agree; both rebuilt)
- [ ] 2.6 Push notifications on iOS
  - [x] Entitlements in both apps (development for Debug/Profile, production for Release), same layout as the Conclave project
  - [ ] APNs key uploaded to Firebase project `tnt-lh` for both iOS apps: reuse the Conclave/Sujatha key, Key ID `YGC3BG873X`, Team ID `3PH4PG45KG`
  - [ ] Push Notifications capability enabled on both App IDs in the Apple Developer account
  - [ ] A real push received on a real iPhone (simulators can't get an APNs token)
- [x] 2.12 App Store Connect: both bundle IDs registered and both app records created by the owner — customer "Teas n Trees | Cream n Crust" (`6821685979`), rider "TnT CnC | Rider" (`6821686237`), both at version 1.0
- [ ] 2.7 Signing and archive
  - [x] Customer project: development team set to `3PH4PG45KG` (same team as Conclave and Sujatha)
  - [x] Rider project moved to team `3PH4PG45KG`
  - [x] fastlane pipeline ported from Sujatha Caterers into both apps (`ios/fastlane`): `status`, `beta`, `wait_build`, `submit`, `review_status`, `cancel_review`
  - [x] App Store prerequisites: iPhone-only and portrait-only (as the other apps), Android icon used as the iOS icon with no alpha, export-compliance flag, `ExportOptions.plist`
  - [x] Archive both apps (signed and exported through the pipeline)
- [ ] 2.8 App Store rules: Sign in with Apple (required alongside Google sign-in) — checked 2026-10-11: not present in the app; needs building
- [ ] 2.9 App Store rules: in-app account deletion — checked 2026-10-11: not present in either app or the backend; needs building (endpoint + UI)
- [x] 2.10 TestFlight build of both apps
  - [x] Customer `1.0.0+4` uploaded 2026-10-11 — **crashed on launch on iOS 27**; replaced by `1.0.0+5` (processed 2026-10-12)
  - [x] Rider `1.0.0+5` uploaded 2026-10-11 — **crashed on launch on iOS 27**; replaced by `1.0.0+6` (processed 2026-10-12)
  - [x] Owner confirmed both replacement builds open on a real iPhone (2026-10-12); phone OTP login works with a test number
- [ ] 2.13 App Store listing for both apps: description, keywords, support and privacy URLs, 6.9" screenshots (1320×2868), review notes with a test login the reviewer can use without an Indian SMS
- [ ] 2.14 App Store Connect forms only the owner can answer: age rating, content rights, App Privacy (and press Publish)
- [ ] 2.15 Submit both apps for review (needs the owner's explicit go-ahead; blocked until 2.8, 2.9, 2.13 and 2.14 are done)
- [ ] 2.16 New app icon art: both current icons still carry the Little H "H" (owner to supply, with the SVG logo)
- [ ] 2.11 Run both apps on a real iPhone

## Phase 3 — Foldables

- [ ] 3.1 Foldable emulator set up (only `Pixel_10_Pro_XL` exists today); capture what breaks folded and unfolded (customer app)
- [ ] 3.2 Cap the scaling so wide screens show more content, not bigger content
- [ ] 3.3 Adaptive layouts: grid columns by width; max content width for forms, sheets, checkout; onboarding and login
- [ ] 3.4 Fold/unfold while running: state survives, nothing important under the hinge
- [ ] 3.5 Rider app pass on the foldable emulator

## Backend changes waiting to go live

Branch `cnc-rebrand` in `teasntrees_backend`. Nothing here is on production
until it is merged to `main` and pushed (which deploys).

- [ ] B.1 Cream N Crust wording (same item as 1.6)
- [ ] B.2 Stale orders: flag after 24h without activity, cancel 24h after the flag (`src/services/staleOrderService.js`). On first deploy every order abandoned before now gets flagged at once and cancelled a day later
- [ ] B.3 Admin panel shows flagged orders (`order:stale` socket event, `staleFlaggedAt` field) — their team

## Phase 4 — Later (agreed to defer)

- [ ] 4.1 Backend: new brand key (`creamncrust`) with `littleh` kept as an alias
- [ ] 4.2 Production data migration of `brand: littleh`
- [ ] 4.3 Apps and web app switch to the new key; rename internal identifiers
- [ ] 4.4 Rotate the credentials exposed in the public backend repo (Atlas password, JWT secret, Firebase service-account key) and scrub `.env.example`

## Open questions for the owner

- App names under the icon: Android customer "Teas n Trees / Cream N Crust", iOS customer "TNT & CNC", Android rider "TNT - CNC Riders". OK, or different?
- Web app still shows `hello@littlehbakery.in` as the bakery contact email, and the About page still says "We believe in Little Happiness". New email / new line?
- Web URLs still contain `/littleh/...` (it is the brand key). Changes with Phase 4.

## Deviations log

- 2026-10-11 — Baseline was committed on a new branch `cnc-ios-foldable` rather than `main`, so the rebrand/iOS/foldable work can be reviewed as one unit. Nothing pushed.
- 2026-10-11 — Backend and web rebrand commits sit on a `cnc-rebrand` branch in each repo. Backend `main` auto-deploys to production on push, so going live is a deliberate step.
- 2026-10-11 — **Neither app could be built on the installed Flutter (3.47.6).** `phosphor_flutter` 2.1.0 (last release May 2024) subclasses `IconData`, which Flutter 3.47 made final. Vendored a patched copy at `packages/phosphor_flutter` in both apps, generated by `tool/vendor_phosphor.py`. Affects Android release builds too, so the next Play build needs a smoke test of icons (duotone ones especially).
- 2026-10-11 — Owner forgot the rider PIN for 9515409973. PINs are hashed, so it needs a reset on production. Added `scripts/reset_rider_pin.mjs` to the backend (branch `cnc-rebrand`); the SSH run was blocked by the permission checker, so the owner runs it. The proper fix is still the admin-panel PIN reset.
- 2026-10-11 — Found on the simulator: the active-order bar said "On the way to you" for an order left unfinished since July. The bar now flags an order as delayed after 3 hours without a status change and stops treating it as active after 24 hours. Still open: nothing on the backend closes or flags abandoned orders, and the Orders tab still lists them with their old live status.
- 2026-10-11 — Owner's decision on abandoned orders: flag, then cancel. Built as a backend job (B.2); tested against a throwaway in-memory database, not against production data.
- 2026-10-11 — Disk filled up mid-build (120 MB free). Freed about 10 GB by deleting today's iOS build outputs for the two apps, a test database download and Xcode's derived-data cache. Still tight: about 10 GB free on a 228 GB disk.
- 2026-10-11 — Owner asked for the other projects' fastlane pipeline to be used here; ported from `sujatha_caterers`. Its runbook (`sujatha_caterers/scripts/RELEASE_IOS_RUNBOOK.md`) is the reference for traps.
- 2026-10-12 — First TestFlight builds closed immediately on launch. Cause: apps built with the iOS 27 SDK must use the UIScene life cycle to launch on iOS 27; both apps still used the old one. Reproduced on an iOS 27 simulator, fixed in both, re-uploaded. Lesson: test on the newest iOS simulator, not only the one that happens to be booted. `ems/build` deleted with the owner's OK to make room.
