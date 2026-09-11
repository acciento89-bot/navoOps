# NavoOps

NavoOps is the private Kamilunavo operations control center for iPhone and iPad. It combines portfolio state, live Apple and Google Play release data, release readiness, GitHub health and deterministic operational intelligence in one native SwiftUI app designed for Apple Business Manager Custom App distribution.

## Current 1.2 scope

- Premium dark Kamilunavo dashboard with adaptive iPhone/iPad layout
- Persistent Kamilunavo product portfolio
- Live App Store Connect version, build and review/distribution state through the Kamilunavo bridge
- Live Google Play release state through GitHub OIDC, Google Workload Identity Federation and the Android Publisher API
- No long-lived Google service-account private key stored in GitHub or in the iOS app
- Prioritized Operations Inbox for build failures, store reviews/rejections and release work
- **Ops Intelligence** with deterministic portfolio and per-product operations scores
- Prioritized next-action recommendations derived from real store, release and GitHub signals
- Apple/Google platform parity detection and version-drift detection
- Store-source coverage and per-provider freshness monitoring
- Missing store-to-portfolio mapping detection
- Release-readiness risk detection for Apple and Google Play
- Review/processing aging signals based on locally observed state history
- Local store status/version transition history retained for up to 120 days
- Platform matrix showing Apple and Google Play side by side for dual-platform products
- Repository health rollup for passing, failed, running and unknown CI state
- Apple- and Google-specific store-readiness checklists
- Release Center driven by live store snapshots when available
- Store inventory with untracked-app detection
- GitHub repository inventory, open PRs and open issues
- Latest commit and latest GitHub Actions health per tracked repository
- GitHub issue creation directly from a product detail screen
- GitHub Quick Action to re-run failed workflow jobs
- Fine-grained GitHub token stored only in iOS Keychain
- Optional Face ID / Touch ID / device-passcode lock
- Local notifications for newly detected failed GitHub Actions workflows
- Local notifications for relevant Apple/Google store-state transitions
- Opportunistic iOS background refresh
- German UI on German devices, English UI everywhere else
- Privacy manifest with no tracking or collected-data declarations
- Deterministic, opaque Kamilunavo app icon generated during the build

## Ops Intelligence

Ops Intelligence does not invent analytics, revenue or store data. It evaluates data already available to NavoOps and derives operational signals from it.

The score is a transparent deterministic heuristic, not an App Store/Google Play ranking and not an AI-generated prediction. Critical signals such as failed builds and store rejections reduce the score more heavily than warnings such as platform drift or incomplete release readiness.

Examples of generated insights:

- Apple live while Google Play is still in review
- Google Play rejection requiring a release fix
- Apple/Google versions do not match
- Store record cannot be mapped to the configured product
- Apple or Google bridge snapshot is stale
- release checklist is incomplete before the next submission
- internal build is ready for the next production/review step
- review/processing state has remained unchanged for an extended observed period
- open pull requests may affect the next release

Store history is intentionally local. NavoOps records only meaningful state/version/build transitions from the sanitized bridge snapshots and retains them for up to 120 days.

## Store bridge

NavoOps deliberately does not contain App Store Connect or Google Play private credentials. GitHub Actions bridges produce sanitized JSON snapshots:

- Apple: `acciento89-bot/onemorefloor/generated/navoops/store-status.json`
- Google Play: `acciento89-bot/maengelfix/generated/navoops/google-store-status.json`

The app reads those snapshots using the GitHub token already stored in Keychain. Both bridges can refresh automatically and can also be requested manually from NavoOps.

### Google authentication

The Google bridge is keyless:

`GitHub Actions OIDC -> Google Workload Identity Federation -> NavoOps service account -> Google Play Android Developer API`

The Workload Identity provider is restricted to the designated Kamilunavo bridge repository. No downloadable service-account JSON private key is required.

## Stack

- SwiftUI
- iOS/iPadOS 17+
- Foundation URLSession
- Security / Keychain
- LocalAuthentication
- UserNotifications
- BackgroundTasks
- UserDefaults for small local operational state and status history
- XcodeGen
- GitHub Actions
- Google Workload Identity Federation for the Google Play bridge

No third-party runtime dependency is required.

## Build locally

```bash
brew install xcodegen
xcrun swift scripts/generate_app_icon.swift
xcodegen generate
open NavoOps.xcodeproj
```

Bundle ID: `com.kamilunavo.NavoOps`

The project is configured for Apple Team `TKG684N5GL` with automatic signing. If Xcode cannot resolve signing on a new Mac, select the Kamilunavo development team once in Signing & Capabilities.

## GitHub access

NavoOps ships without credentials. Add a fine-grained GitHub token in Settings. Read-only repository metadata, contents, pull requests and Actions permissions are sufficient for monitoring and loading store snapshots. Issue creation needs Issues write permission. Re-running workflows or manually dispatching a store bridge needs Actions write permission.

## Custom App distribution

See `docs/APPLE_BUSINESS_CUSTOM_APP.md`. The Apple Business Manager Organization ID is configured in App Store Connect and is deliberately not embedded in source code.

## CI

The workflow validates the privacy manifest, generates the deterministic AppIcon, generates the Xcode project and runs the unit-test target on an available iPhone simulator.
