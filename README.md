# NavoOps

NavoOps is the private operations control center for Kamilunavo. The iPhone/iPad app centralizes product status, GitHub repositories, release health, open issues and store-readiness checklists in one native SwiftUI interface.

## Stack

- SwiftUI + SwiftData
- iOS/iPadOS 17+
- GitHub REST API
- GitHub token stored only in iOS Keychain
- XcodeGen for reproducible project generation
- No third-party runtime dependencies

## Features

- Portfolio dashboard with live/review/attention metrics
- Product catalog for Kamilunavo apps
- GitHub repository sync, including private repositories when a token is configured
- Per-product workflow status and open pull requests
- GitHub issue inbox and issue creation
- Editable Apple/Google release state
- Store-readiness checklist for Apple and Google
- Native German/English localization
- Dark Kamilunavo visual system, adaptive for iPhone and iPad

## Build

```bash
brew install xcodegen
xcodegen generate
open NavoOps.xcodeproj
```

The default bundle identifier is `com.kamilunavo.NavoOps`.

For CI or unsigned simulator builds:

```bash
xcodebuild -project NavoOps.xcodeproj -scheme NavoOps -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO build
```

## GitHub access

NavoOps does not ship with credentials. In Settings, add a fine-grained GitHub token with read access to the Kamilunavo repositories. Issue creation additionally requires Issues write permission. The token is persisted in Keychain and never written to source control or UserDefaults.

## Apple Business Manager

NavoOps is designed for Custom App distribution through App Store Connect / Apple Business Manager. Custom distribution is configured in App Store Connect; no special Apple Business Manager entitlement is required in the app binary.
