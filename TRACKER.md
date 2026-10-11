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

- [ ] 2.1 Customer app builds and launches on the iOS simulator
- [ ] 2.2 Customer app core flow on iOS: login, menu, cart, checkout, order tracking map, address picker, profile photo
- [ ] 2.3 Rider app builds and launches on the iOS simulator (first ever iOS build)
- [ ] 2.4 Rider app core flow on iOS: login, go online, accept, navigate, proof photo, complete; background location
- [ ] 2.5 Align iOS deployment target (Xcode project says 13.0, Podfiles say 15.6 / 14.0)
- [ ] 2.6 Push notifications: entitlements in both apps + APNs key in Firebase (owner: Apple Developer account)
- [ ] 2.7 Signing: development team on the customer project; archive both apps
- [ ] 2.8 App Store rules: Sign in with Apple (required alongside Google sign-in) — check and add
- [ ] 2.9 App Store rules: in-app account deletion — check and add
- [ ] 2.10 TestFlight build of both apps
- [ ] 2.11 Run both apps on a real iPhone

## Phase 3 — Foldables

- [ ] 3.1 Foldable emulator set up; capture what breaks folded and unfolded (customer app)
- [ ] 3.2 Cap the scaling so wide screens show more content, not bigger content
- [ ] 3.3 Adaptive layouts: grid columns by width; max content width for forms, sheets, checkout; onboarding and login
- [ ] 3.4 Fold/unfold while running: state survives, nothing important under the hinge
- [ ] 3.5 Rider app pass on the foldable emulator

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
