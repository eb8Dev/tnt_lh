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
- [x] 1.6 Backend: user-visible strings — live 2026-10-13; (outlet name, portal messages, coupon message) — coded on branch `cnc-rebrand` (`0f69bda`); **not live until merged and pushed to `main`**
- [x] 1.7 Web app (`tnt-lh-customer`): visible wording and logo — live on teasntrees.in 2026-10-13 (owner ran the upload; live bundle matches the local build). Commit `aad3218` is still only on the local `cnc-rebrand` branch; owner to push
- [ ] 1.8 Replace the stopgap PNG with the final SVG logo when it arrives
- [ ] 1.9 Play listing text — drafted in `docs/PLAY_LISTING.md` with the BrewCrust name; owner updates Play Console in the next release
- [x] 1.10 Admin panels: bakery wording and logo are Cream N Crust (2026-10-15)

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
- [x] 2.6 Push notifications on iOS
  - [x] Entitlements in both apps (development for Debug/Profile, production for Release), same layout as the Conclave project
  - [x] APNs key uploaded to Firebase for both iOS apps (owner, 2026-10-14)
  - [x] Push capability on both App IDs (signing succeeds with aps-environment)
  - [x] A real push received on a real iPhone (2026-10-15)
- [x] 2.12 App Store Connect: both bundle IDs registered and both app records created by the owner — customer "Teas n Trees | Cream n Crust" (`6821685979`), rider "TnT CnC | Rider" (`6821686237`), both at version 1.0
- [x] 2.7 Signing and archive (fastlane beta, team 3PH4PG45KG)
  - [x] Customer project: development team set to `3PH4PG45KG` (same team as Conclave and Sujatha)
  - [x] Rider project moved to team `3PH4PG45KG`
  - [x] fastlane pipeline ported from Sujatha Caterers into both apps (`ios/fastlane`): `status`, `beta`, `wait_build`, `submit`, `review_status`, `cancel_review`
  - [x] App Store prerequisites: iPhone-only and portrait-only (as the other apps), Android icon used as the iOS icon with no alpha, export-compliance flag, `ExportOptions.plist`
  - [x] Archive both apps (signed and exported through the pipeline)
- [ ] 2.8 Sign in with Apple — in BrewCrust 1.0.0 (7), Apple provider enabled in Firebase (2026-10-14); not yet tried on a real iPhone
- [x] 2.9 In-app account deletion (deactivate + anonymise) — backend live, both apps have the button (customer 1.0.0 (7), rider 1.0.0 (9)); tested on a throwaway database, not yet by hand in the apps
- [x] 2.10 TestFlight build of both apps
  - [x] Customer `1.0.0+4` uploaded 2026-10-11 — **crashed on launch on iOS 27**; replaced by `1.0.0+5` (processed 2026-10-12)
  - [x] Rider `1.0.0+5` uploaded 2026-10-11 — **crashed on launch on iOS 27**; replaced by `1.0.0+6` (processed 2026-10-12)
  - [x] Owner confirmed both replacement builds open on a real iPhone (2026-10-12); phone OTP login works with a test number
- [x] 2.13 App Store listing for both apps: description, keywords, support and privacy URLs, 6.9" screenshots (1320×2868), review notes with a test login the reviewer can use without an Indian SMS — done 2026-10-15 (BrewCrust names, text, 6.9" screenshots, reviewer logins)
- [x] 2.14 App Store Connect forms only the owner can answer: age rating, content rights, App Privacy (and press Publish) — owner done 2026-10-15
- [x] 2.15 Submit both apps for review (needs the owner's explicit go-ahead; blocked until 2.8, 2.9, 2.13 and 2.14 are done) — submitted 2026-10-15: BrewCrust 1.0.0 (7), BrewCrust Rider 1.0.0 (9), WAITING_FOR_REVIEW; price set to Free
- [ ] 2.16 New BrewCrust icon and SVG logo — three concepts in `docs/brand/` (icon-concepts.png); owner to choose
- [ ] 2.11 Run both apps on a real iPhone

## Phase 3 — Foldables

- [x] 3.1 Foldable emulator `Pixel_10_Pro_Fold` (Android 17; set to stay awake on fold) — customer app walked folded and unfolded
- [x] 3.2 Scaling capped at 1.15x on wide screens (`lib/core/responsive.dart`)
- [x] 3.3 Grids 2–6 columns by width; detail, bag, checkout, orders, profile and sign-in pages in a centred 640dp column
- [x] 3.4 Fold/unfold while running: the manifest already handles size changes without restarting the activity; the Pixel Fold's hinge does not cover content
- [ ] 3.5 Rider app pass on the foldable emulator — owner: later

## Backend changes waiting to go live

Branch `cnc-rebrand` in `teasntrees_backend`. Nothing here is on production
until it is merged to `main` and pushed (which deploys).

- [x] B.1 Cream N Crust wording — live 2026-10-13
- [x] B.2 (live 2026-10-13; VM logs not checked, access was blocked) Stale orders: flag after 24h without activity, cancel 24h after the flag (`src/services/staleOrderService.js`). On first deploy every order abandoned before now gets flagged at once and cancelled a day later
- [x] B.3 Admin panels: 'Needs attention' filter, auto-cancel badges, live pop-up for stale orders — live 2026-10-15, checked locally with the real job

## Phase 5 — Requests from the business (2026-10-13)

- [x] 5.1 Rider self-service PIN reset with admin alert — backend live, rider 1.0.0 (9) on Play beta and in App Store review, admin panels alert (2026-10-15)
  - [x] Backend endpoint `POST /rider/auth/reset-pin` — branch `rider-pin-reset` (`dea1546`), tested against a throwaway local database
  - [x] Rider app screen (SMS code → new PIN) — committed on `cnc-ios-foldable`; builds on Android and iOS; step 1 checked on the Android emulator
  - [x] Backend merged to `main` and live in production (2026-10-13)
  - [ ] Full flow with a real SMS code (owner: no registered test rider on a test number; later)
  - [x] Rider app's Android SHA fingerprints in Firebase (owner confirmed 2026-10-13)
  - [x] Admin panel shows the alert (`rider:pin-reset` event, `pinResetAt` / `pinResetCount` on the rider) — panel repos; owner: later — pushed to both panels 2026-10-15 (toast + card line); event path verified locally
  - [x] New rider builds shipped (Play + TestFlight) — rider 1.0.0 (9): Play beta + App Store review
- [x] 5.2 Admin panel menu management — both panels already meet the requirement incl. dish photo upload (checked in code 2026-10-15); the gap is data: most dishes have no photo

## Phase 7 — Design polish (2026-10-15)

- [x] 7.1 Customer app: spacing on the 4/8/12/16/24 scale, tighter item page, checkout, bag; empty sections hidden; customer-facing order status names; '1 item'; before/after in `docs/design/polish-before-after.png`
- [ ] 7.2 Ship it: the polish and foldable work are in neither the build under App Store review (1.0.0 (7)) nor Play beta (7); next release

## Phase 8 — Tablets and iPad, portrait and landscape (2026-10-30, branch `tablets`)

Every screen gets a designed layout in both orientations; none left out. Landscape = width >= 840 (`Responsive.isExpanded`).

- [x] 8.1 Shell: side rail in landscape, bottom bar otherwise
- [x] 8.2 Home: category sidebar + wide grid (landscape); 3–4 columns (portrait); no Menu button where the sidebar shows
- [x] 8.3 Item details: photo left, details right (landscape)
- [x] 8.4 Bag: items left, total right (landscape)
- [x] 8.5 Checkout: form left, summary + place order right (landscape)
- [x] 8.6 Orders: list left, selected order right (landscape)
- [x] 8.7 Order details: status left, items + bill right whenever it has >= 760 of width
- [x] 8.8 Profile: you left, addresses and settings right (landscape)
- [x] 8.9 Address picker: map left, form right (landscape)
- [x] 8.10 Onboarding (picture beside text), login, code entry, register (stores left, form right) — landscape
- [x] 8.11 Bottom sheets capped at 640 wide
- [x] 8.12 Every screen checked by screenshot: customer (11 screens + onboarding/login) and rider (4 screens) on a Pixel Tablet in both orientations, customer on iPhone 17; no layout errors (sheets in `docs/design/tablets/`). Not seen: rider live map during a delivery
- [x] 8.12b Rider app tablet layouts (rail, two-column dashboard and profile, map corner card, centred forms; iPad enabled) — branch `tablets` in tnt_rider
- [x] 8.13 iPad: enabled in both apps; 13" iPad screenshots in both listings (2026-10-30). iPad: enabled (all four orientations, iPhone stays portrait); needs 13" iPad App Store screenshots and a build
- [x] 8.14 Shipped as 1.1.0: Play beta (customer 9, rider 10); App Store review (customer 1.1.0 (9) replaced the withdrawn 1.0.0 (8); rider 1.1.0 (10) as an update, rider 1.0.0 is live). Was: Ship as the next version after 1.0.0 (8) is approved

## Phase 6 — Deployment and operations (stays on the Windows VM; no Linux VM available)

- [ ] 6.1 Rotate the credentials exposed in the public backend repo — owner: leave while all users are testers (2026-10-14); do before real customers
- [x] 6.2 Backend: check job before deploy (parse every file, boot against a throwaway MongoDB, hit six endpoints) — live on GitHub 2026-10-13; first run failed and skipped the deploy as designed, second passed and deployed
- [x] 6.3 Website deploys from GitHub on push to main (own deploy key; `C:\Users\tntadmin\deploy-web.ps1` keeps the previous version) — live 2026-10-15
- [x] 6.4 Error alerts (Sentry, org manuen-infotech-opc-private-li): backend (every logger.error + unhandled Express errors, production only) and website (production builds) — live 2026-10-15; test events sent to both projects
- [ ] 6.5 Staging copy on the same VM (second checkout, own port, own subdomain, the clone database)
- [x] 6.6 Rollback — backend: deploy.ps1 health-checks and restores the previous commit on failure; Run workflow with a commit hash deploys that commit (tested back and forward 2026-10-15). Website: Run workflow with 'rollback'
- [x] 6.7 Nightly backup of uploaded files to Firebase Storage (task TnT-Backup, 3 AM) — first run 264 files, second run 0 changed (2026-10-15)
- [x] 6.8 Uptime check every 10 min from GitHub (`uptime.yml`), emails connect@manuen.com from manueninfotech@gmail.com — test alert sent 2026-10-15
- [x] 6.9 Android releases uploaded by command (Play service-account key) — done 2026-10-15 (`android/fastlane`, key in ~/.tnt-secrets); both apps on Play beta: customer 7, rider 9

- [x] 6.10 Dead push tokens cleared instead of retried hourly — live 2026-10-15
- [x] 6.11 Remote Desktop (3389) open to the internet — client's server and setting; owner decided to leave it (2026-10-15)

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
- 2026-10-13 — Backend deployed to production: Cream N Crust wording, stale-order job, rider PIN reset, account deletion, and a fix to social sign-in (the email was trusted from the request body; it now comes from the verified token).
- 2026-10-13 — Client wants a shorter umbrella app name ("Duobite"-style); name ideas requested. Play/App Store listing text waits on the name.
- 2026-10-15 — Umbrella name BrewCrust adopted (home screen: BrewCrust / BC Rider). Screenshot runs found and fixed three customer-app bugs (loading placeholder layout, missing Poppins Extra Bold, bag header overflow). Test push to iPhone confirmed.
- 2026-10-30 — App Review rejected 1.0.0 (7): Sign in with Apple failed. Two backend causes (null-indexed unique keys; Apple's email-only-once), both fixed and deployed; owner confirmed Apple sign-in on an iPhone 16 Plus; 1.0.0 (8) resubmitted.
