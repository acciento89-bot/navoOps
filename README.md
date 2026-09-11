# NavoOps

NavoOps is the private Kamilunavo operations control center for iPhone and iPad. It combines portfolio state, release readiness and GitHub health in one native SwiftUI app designed for Apple Business Manager Custom App distribution.

## Current 1.0 scope

- Premium dark Kamilunavo dashboard with adaptive iPhone/iPad layout
- Persistent Kamilunavo product portfolio
- Apple and Google release states per product
- Apple- and Google-specific store-readiness checklists
- Release Center filters for attention, review and live products
- GitHub repository inventory, open PRs and open issues
- Latest commit and latest GitHub Actions health per tracked repository
- GitHub issue creation directly from a product detail screen
- Fine-grained GitHub token stored only in iOS Keychain
- Optional Face ID / Touch ID / device-passcode lock
- Local notifications for newly detected failed GitHub Actions workflows
- Opportunistic iOS background refresh
- German UI on German devices, English UI everywhere else
- Privacy manifest with no tracking or collected-data declarations
- Deterministic, opaque Kamilunavo app icon generated during the build

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

NavoOps ships without credentials. Add a fine-grained GitHub token in Settings. Read-only repository metadata, contents, pull requests and Actions permissions are sufficient for monitoring. Issue creation additionally requires Issues write permission.

## Custom App distribution

See `docs/APPLE_BUSINESS_CUSTOM_APP.md`. The Apple Business Manager Organization ID is configured in App Store Connect and is deliberately not embedded in source code.

## CI

The workflow validates the privacy manifest, generates the deterministic AppIcon, generates the Xcode project and runs the unit-test target on an available iPhone simulator.
