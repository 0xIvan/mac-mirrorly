#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
sign_identity="${MAC_MIRRORLY_DEVELOPER_ID:-}"
notary_profile="${MAC_MIRRORLY_NOTARY_PROFILE:-}"

if [[ "$sign_identity" != "Developer ID Application:"* ]]; then
  echo "Set MAC_MIRRORLY_DEVELOPER_ID to a Developer ID Application signing identity." >&2
  exit 1
fi
if [[ -z "$notary_profile" ]]; then
  echo "Set MAC_MIRRORLY_NOTARY_PROFILE to a notarytool keychain profile." >&2
  exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$root_dir/Resources/Info.plist")"
output_dmg="${1:-$root_dir/dist/MacMirrorly-$version.dmg}"
mkdir -p "$(dirname "$output_dmg")"
output_dmg="$(cd "$(dirname "$output_dmg")" && pwd)/$(basename "$output_dmg")"
if [[ -e "$output_dmg" ]]; then
  echo "Output already exists: $output_dmg" >&2
  exit 1
fi

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

cd "$root_dir"
xcodegen generate
xcodebuild build -project MacMirrorly.xcodeproj -scheme MacMirrorly \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$build_dir/DerivedData" CODE_SIGNING_ALLOWED=NO -quiet

built_app="$build_dir/DerivedData/Build/Products/Release/MacMirrorly.app"
app_path="$build_dir/MacMirrorly.app"
ditto "$built_app" "$app_path"
lipo -verify_arch arm64 "$app_path/Contents/MacOS/MacMirrorly"
lipo -verify_arch x86_64 "$app_path/Contents/MacOS/MacMirrorly"
codesign --force --sign "$sign_identity" --options runtime --timestamp \
  --entitlements "$root_dir/Resources/MacMirrorly.entitlements" "$app_path"
codesign --verify --strict --verbose=2 "$app_path"

"$root_dir/scripts/package-dmg.sh" "$app_path" "$output_dmg" "$sign_identity"
notary_result="$(xcrun notarytool submit "$output_dmg" \
  --keychain-profile "$notary_profile" --wait --output-format json)"
printf '%s\n' "$notary_result"
if [[ "$(printf '%s' "$notary_result" | jq -r '.status')" != "Accepted" ]]; then
  echo "Apple did not accept the notarization request." >&2
  exit 1
fi
xcrun stapler staple "$output_dmg"
xcrun stapler validate "$output_dmg"
spctl --assess --type open --context context:primary-signature --verbose "$output_dmg"
shasum -a 256 "$output_dmg"
