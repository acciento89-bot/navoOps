# NavoOps

NavoOps is the private Kamilunavo operations control center for iPhone and iPad. It combines portfolio state, live Apple and Google Play release data, release readiness, GitHub health, deterministic operational intelligence and source-backed business/release analytics in one native SwiftUI app designed for Apple Business Manager Custom App distribution.

## Current 1.3 scope

### Operations
- Premium dark Kamilunavo dashboard with adaptive iPhone/iPad layout
- Persistent Kamilunavo product portfolio
- Live App Store Connect version, build and review/distribution state through the Kamilunavo bridge
- Live Google Play release state through GitHub OIDC, Google Workload Identity Federation and the Android Publisher API
- Prioritized Operations Inbox for build failures, store reviews/rejections and release work
- Apple- and Google-specific store-readiness checklists
- Release Center driven by live store snapshots when available
- Store inventory with untracked-app detection
- Local notifications for failed GitHub Actions workflows and relevant Apple/Google store transitions
- Opportunistic iOS background refresh

### Ops Intelligence
- Deterministic portfolio and per-product operations scores
- Prioritized next-action recommendations derived from real store, release and GitHub signals
- Apple/Google platform parity and semantic version-drift detection
- Store-source coverage and per-provider freshness monitoring
- Missing store-to-portfolio mapping detection
- Review/processing aging signals based on locally observed state history
- Local store status/version/build transition history retained for up to 120 days
- Platform matrix showing Apple and Google Play side by side
- CI/build-health rollup and open-PR context

### Business & Release Intelligence
- Dedicated Analytics tab
- Release velocity over the last 30 and 90 days from observed store transitions
- Average completed Apple and Google review duration from local history
- Current-review aging per app
- 30-day GitHub engineering telemetry: commit volume, merged pull requests and CI success rate
- Apple and Google monetization inventory counts when APIs permit access
- Apple Sales & Trends units/proceeds when an authorized vendor number is configured
- Multi-currency proceeds aggregation without converting currencies using invented FX rates
- Google Play Vitals adapter for crash rate, user-perceived crash rate, ANR rate and user-perceived ANR rate
- 180-day local analytics history with trend charts when historical points exist
- Explicit source-coverage diagnostics: unavailable data remains unavailable instead of being estimated

### GitHub and security
- Repository inventory, open PRs and open issues
- Latest commit and latest GitHub Actions health per tracked repository
- GitHub issue creation directly from product details
- Quick Action to re-run failed workflow jobs
- Fine-grained GitHub token stored only in iOS Keychain
- Optional Face ID / Touch ID / device-passcode lock
- No App Store Connect private key or Google long-lived service-account key embedded in the iOS app
- Google bridge uses GitHub OIDC -> Workload Identity Federation -> service account
- German UI on German devices, English UI everywhere else
- Privacy manifest with no tracking or collected-data declarations
- Deterministic opaque Kamilunavo app icon generated during build

## Analytics data policy

NavoOps does **not** fabricate downloads, revenue, subscribers, rankings, store performance or predictive metrics. Every displayed commercial/reliability value must come from a connected source. Missing permission or unavailable reporting data is surfaced as unavailable.

Current sources:

- Apple release status: `acciento89-bot/onemorefloor/generated/navoops/store-status.json`
- Google Play release status: `acciento89-bot/maengelfix/generated/navoops/google-store-status.json`
- Apple analytics/monetization: `acciento89-bot/onemorefloor/generated/navoops/apple-analytics.json`
- Google analytics/monetization/Vitals: `acciento89-bot/maengelfix/generated/navoops/google-analytics.json`

### Apple analytics bridge

The Apple analytics workflow reads App Store Connect app inventory, in-app purchases and subscription configuration. If the bridge repository also contains an authorized `ASC_VENDOR_NUMBER` secret and the App Store Connect API role can access Sales & Trends, the workflow additionally downloads the sanitized daily SALES/SUMMARY report and aggregates units/proceeds by Apple Identifier and currency.

`ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY_B64` and `ASC_VENDOR_NUMBER` remain server-side GitHub secrets. The generated JSON contains no private key or JWT.

### Google analytics bridge

The Google analytics workflow authenticates keylessly through GitHub OIDC and requests both:

- `https://www.googleapis.com/auth/androidpublisher`
- `https://www.googleapis.com/auth/playdeveloperreporting`

The Android Publisher API supplies subscription and one-time-product inventory. The Play Developer Reporting API supplies crash/ANR Vitals when the service account has the required Play Console app-information/reporting permission. If Reporting access is unavailable, NavoOps keeps Vitals empty and records that limitation in the feed instead of estimating it.

Aggregate Google Play revenue/download totals are intentionally not shown until a dedicated reporting-export source is connected.

## Store bridge

NavoOps deliberately does not contain App Store Connect or Google Play private credentials. GitHub Actions bridges produce sanitized JSON snapshots, and the app reads those snapshots using the GitHub token stored in Keychain. Store and analytics bridges refresh on schedules and can be requested manually from NavoOps when the token has Actions write permission.

## Stack

- SwiftUI + Swift Charts
- iOS/iPadOS 17+
- Foundation URLSession
- Security / Keychain
- LocalAuthentication
- UserNotifications
- BackgroundTasks
- UserDefaults/Codable for small local operational and analytics history
- XcodeGen
- GitHub Actions
- App Store Connect API
- Google Play Android Developer API
- Google Play Developer Reporting API
- Google Workload Identity Federation

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

NavoOps ships without credentials. Add a fine-grained GitHub token in Settings. Read-only repository metadata, contents, pull requests and Actions permissions are sufficient for monitoring and loading sanitized snapshots. Issue creation needs Issues write permission. Re-running workflows or manually dispatching a bridge needs Actions write permission.

## Custom App distribution

See `docs/APPLE_BUSINESS_CUSTOM_APP.md`. The Apple Business Manager Organization ID is configured in App Store Connect and is deliberately not embedded in source code.

## CI

The workflow validates the privacy manifest, generates and validates the deterministic AppIcon, generates the Xcode project and runs the complete unit-test target on an available iPhone simulator.
