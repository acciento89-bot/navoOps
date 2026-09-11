# Security

## GitHub token

NavoOps never ships a GitHub credential. The user supplies a fine-grained personal access token on-device. The token is stored using the iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so background refresh can access it after the device has been unlocked once.

Recommended minimum repository permissions:

- Metadata: Read
- Contents: Read
- Pull requests: Read
- Actions: Read
- Issues: Read and write only when issue creation from NavoOps is desired

Do not grant Administration, Secrets or repository deletion permissions.

## Local data

Product states, store-readiness flags, package identifiers and internal notes are stored locally. They are not uploaded by NavoOps.

## Device lock

The optional NavoOps lock uses `deviceOwnerAuthentication`, allowing the platform to use Face ID, Touch ID or the configured device passcode. NavoOps never receives biometric templates.

## Notifications

Local notifications are generated only for newly detected failed GitHub Actions runs. There is currently no remote push provider and no APNs device token is uploaded anywhere.
