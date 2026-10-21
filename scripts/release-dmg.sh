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
output_dmg="${1:-$root_dir/dist/MacMirrorly-$version-universal.dmg}"
mkdir -p "$(dirname "$output_dmg")"
output_dmg="$(cd "$(dirname "$output_dmg")" && pwd)/$(basename "$output_dmg")"
if [[ -e "$output_dmg" || -e "$output_dmg.sha256" ]]; then
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
staged_dmg="$build_dir/$(basename "$output_dmg")"
ditto "$built_app" "$app_path"
lipo "$app_path/Contents/MacOS/MacMirrorly" -verify_arch arm64
lipo "$app_path/Contents/MacOS/MacMirrorly" -verify_arch x86_64
codesign --force --sign "$sign_identity" --options runtime --timestamp \
  --entitlements "$root_dir/Resources/MacMirrorly.entitlements" "$app_path"
codesign --verify --strict --verbose=2 "$app_path"
codesign -d --entitlements :- "$app_path" > "$build_dir/entitlements.plist" 2>/dev/null
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$build_dir/entitlements.plist" 2>/dev/null || true)" == "true" ]]; then
  echo "Release app must not allow debugging." >&2
  exit 1
fi

notarize() {
  local artifact="$1"
  local result
  result="$(xcrun notarytool submit "$artifact" \
    --keychain-profile "$notary_profile" --wait --output-format json)"
  printf '%s\n' "$result"
  if [[ "$(printf '%s' "$result" | jq -r '.status')" != "Accepted" ]]; then
    echo "Apple did not accept the notarization request for $artifact." >&2
    exit 1
  fi
}

# Staple the app before packaging so its ticket survives copying off the DMG.
ditto -c -k --keepParent "$app_path" "$build_dir/notarize.zip"
notarize "$build_dir/notarize.zip"
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"

"$root_dir/scripts/package-dmg.sh" "$app_path" "$staged_dmg" "$sign_identity"
notarize "$staged_dmg"
xcrun stapler staple "$staged_dmg"
xcrun stapler validate "$staged_dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$staged_dmg"
hdiutil verify "$staged_dmg"
mv "$staged_dmg" "$output_dmg"
(cd "$(dirname "$output_dmg")" && shasum -a 256 "$(basename "$output_dmg")" > "$output_dmg.sha256")
cat "$output_dmg.sha256"
