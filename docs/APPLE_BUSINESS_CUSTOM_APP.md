# NavoOps — Apple Business Custom App Distribution

NavoOps is intentionally configured as an internal Kamilunavo business app.

## App Store Connect configuration

1. Create the app with bundle ID `com.kamilunavo.NavoOps` and primary category **Business**.
2. Upload an archive signed by Apple Team `TKG684N5GL`.
3. Complete App Privacy using the repository privacy manifest and the statements in `Store/metadata.json`.
4. In **Pricing and Availability / Distribution Method**, choose private distribution as a **Custom App**.
5. Add the Kamilunavo Apple Business Manager organization by its exact Organization ID from Apple Business Manager.
6. Submit the build for Apple review.
7. After approval, open Apple Business Manager → Apps and Books → Custom Apps, acquire licenses and assign NavoOps through the configured MDM.

## Review behavior

The reviewer can inspect the portfolio, release center and local configuration without an account. GitHub is optional. No review credential or GitHub token is required to reach the core interface.

## Security model

- GitHub credentials are entered by the authorized user and stored only in iOS Keychain.
- Release state and checklists are persisted locally in UserDefaults.
- NavoOps sends GitHub API requests directly from the device to `api.github.com`.
- No analytics, advertising SDK or tracking SDK is included.
- Device authentication can be enabled to lock the internal dashboard whenever the app leaves the foreground.
- Background refresh is opportunistic and controlled by iOS.

The Apple Business Manager Organization ID is intentionally not stored in this repository because it is account configuration rather than application runtime data.
