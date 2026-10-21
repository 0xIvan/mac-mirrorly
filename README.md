# MacMirrorly

A small native macOS menu bar app for reading selected Mirrorly copytraders' equity and open copied positions.

## Install

Download the DMG from [GitHub Releases](https://github.com/0xIvan/mac-mirrorly/releases/latest).

Requires macOS 14 or newer. The universal DMG supports Apple silicon and Intel Macs.
Open the DMG, drag **MacMirrorly** into **Applications**, eject the image, then open the app.
It runs in the menu bar without a Dock icon. Sign in with your own Mirrorly email and password.
Google, Web3, and two-factor sign-in are not supported.

The download contains no account credentials or sessions. Passwords are sent over HTTPS to
Mirrorly and are not saved by the app. “Stay signed in” stores a session cookie in this app's
macOS cookie store, outside the app bundle. Sign out to clear the local session.
Copytrader selections and value visibility preferences are saved locally. No analytics SDK
is included. Updates require downloading and installing a newer DMG.

## Features

- Menu bar M and combined equity for selected copytraders
- Account-wide 24h PnL from the same account statistics endpoint as the Mirrorly portal
- One-minute refresh while the app is running, with a warning when the last update is delayed or fails
- Open copied positions grouped by copytrader: direction, symbol, trader, notional size, status, and unrealized PnL
- Active copytrader alarms and non-enabled modes in the menu
- Settings window with per-user copytrader selection, total and selected equity, exchange, mode, and unrealized PnL
- Direct link to the Mirrorly portal

The menu bar, window, and app icon use the Mirrorly mark from `Mirrorly-UI/public/favicon.svg`. The app icon places the primary-color mark on a warm ivory, standard-radius background matching Hago's icon.

The app uses only `https://portal.mirrorly.xyz/api/account/me`, `/account/statistics/pnl`, `/auth/login`, `/auth/logout`, `/copytrader`, and `/copytrader/{id}/position/open`. It signs in with email and password. Google, Web3, and two-factor sign-in are not implemented. The password is not stored. Choosing “Stay signed in” asks the server for a persistent cookie; macOS keeps it in the app's cookie store. An expired or revoked session requires signing in again.

## Build

Requires macOS 14 or newer, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open MacMirrorly.xcodeproj
```

Select the `MacMirrorly` scheme and run. For a command-line check:

```sh
xcodebuild test -project MacMirrorly.xcodeproj -scheme MacMirrorly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

The app is a menu bar accessory (`LSUIElement`) and uses the macOS App Sandbox outgoing-network entitlement. It makes native `URLSession` requests to the portal's HTTPS `/api` route; browser CORS origin policies do not apply to those requests.

## DMG distribution

The app builds for both Apple silicon and Intel Macs. A DMG contains `MacMirrorly.app` and an `Applications` shortcut so users can drag the app into Applications. To make a local packaging preview from an already signed app:

```sh
scripts/package-dmg.sh /Applications/MacMirrorly.app dist/MacMirrorly-local-preview.dmg
```

This local preview is not a public release. A build signed with a local development certificate will be rejected by Gatekeeper on another Mac. For direct distribution, install a **Developer ID Application** certificate, save notarization credentials in a `notarytool` keychain profile, and run:

```sh
xcrun notarytool store-credentials macmirrorly-release --apple-id 'you@example.com' --team-id 'TEAMID'
export MAC_MIRRORLY_DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'
export MAC_MIRRORLY_NOTARY_PROFILE=macmirrorly-release
scripts/release-dmg.sh
```

The release script builds a universal Release app, signs it with the hardened runtime and a secure timestamp, notarizes and staples the app, then creates, signs, notarizes, and staples the DMG. It validates both tickets and Gatekeeper acceptance, checks image integrity, and writes a SHA-256 checksum. Publish only the completed `dist/MacMirrorly-<version>-universal.dmg` and its `.sha256` file to a stable GitHub Release whose tag matches the version, such as `v1.0.1`. Failed signing or notarization does not produce a final distribution image. Each new release should increment the version and build number in `Resources/Info.plist` and be tested after drag-installing on a separate Mac. Direct downloads do not include automatic updates.

Mirrorly sign-in currently supports email and password only. Accounts requiring Google, Web3, or two-factor sign-in cannot use this companion yet.

## Verification limits

The macOS GitHub Actions workflow builds and runs contract-decoding tests. A real account is needed to verify login, session persistence, and live copytrader data in the running app. A Developer ID-signed and notarized drag-install still needs testing on another Mac before public release.
