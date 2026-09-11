# NavoOps

NavoOps is the private Kamilunavo operations control center for iPhone and iPad. It combines portfolio state, release readiness, live App Store state and GitHub health in one native SwiftUI app designed for Apple Business Manager Custom App distribution.

## Current 1.1 scope

- Premium dark Kamilunavo dashboard with adaptive iPhone/iPad layout
- Persistent Kamilunavo product portfolio
- Live App Store Connect version, build and review/distribution state through the Kamilunavo bridge
- Store bridge architecture that keeps App Store Connect credentials outside the iOS app
- Google Play feed model and UI fallback, ready for the Google Publisher bridge
- Prioritized Operations Inbox for build failures, store reviews/rejections and release work
- Apple- and Google-specific store-readiness checklists
- Release Center driven by live store snapshots when available
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

## Store bridge

NavoOps deliberately does not contain App Store Connect or Google Play service-account private keys. A GitHub Actions bridge produces a sanitized JSON snapshot at:

`acciento89-bot/onemorefloor/generated/navoops/store-status.json`

The app reads that snapshot using the GitHub token already stored in Keychain. The Apple bridge currently refreshes automatically every hour and can also be requested manually from NavoOps Settings. Google Play remains on the local fallback until its Publisher API bridge reports `googleAvailable: true`.

## Stack

- SwiftUI
- iOS/iPadOS 17+
- Foundation URLSession
- Security / Keychain
- LocalAuthentication
- UserNotifications
- BackgroundTasks
- UserDefaults for small local operational state
- XcodeGen
- GitHub Actions

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

NavoOps ships without credentials. Add a fine-grained GitHub token in Settings. Read-only repository metadata, contents, pull requests and Actions permissions are sufficient for monitoring and loading the store snapshot. Issue creation needs Issues write permission. Re-running workflows or manually dispatching the store bridge needs Actions write permission.

## Custom App distribution

See `docs/APPLE_BUSINESS_CUSTOM_APP.md`. The Apple Business Manager Organization ID is configured in App Store Connect and is deliberately not embedded in source code.

## CI

The workflow validates the privacy manifest, generates the deterministic AppIcon, generates the Xcode project and runs the unit-test target on an available iPhone simulator.
