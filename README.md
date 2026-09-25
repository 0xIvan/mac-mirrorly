# MacMirrorly

A small native macOS menu bar app for reading selected Mirrorly copytraders' equity and open copied positions.

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

## Verification limits

The macOS GitHub Actions workflow builds and runs contract-decoding tests. A real account is needed to verify login, session persistence, and live copytrader data in the running app.
