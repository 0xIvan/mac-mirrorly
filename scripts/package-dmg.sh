#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 APP_PATH OUTPUT_DMG [DEVELOPER_ID_APPLICATION]" >&2
  exit 2
fi

app_path="$1"
output_dmg="$2"
sign_identity="${3:-}"

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path" >&2
  exit 1
fi
if [[ "$output_dmg" != *.dmg ]]; then
  echo "Output must end in .dmg: $output_dmg" >&2
  exit 1
fi
if [[ -e "$output_dmg" ]]; then
  echo "Output already exists: $output_dmg" >&2
  exit 1
fi

codesign --verify --strict "$app_path"
mkdir -p "$(dirname "$output_dmg")"
output_dmg="$(cd "$(dirname "$output_dmg")" && pwd)/$(basename "$output_dmg")"
staging_dir="$(mktemp -d)"
trap 'rm -rf "$staging_dir"' EXIT
chmod 755 "$staging_dir"

ditto "$app_path" "$staging_dir/MacMirrorly.app"
codesign --verify --strict "$staging_dir/MacMirrorly.app"
ln -s /Applications "$staging_dir/Applications"
diskutil image create from --volumeName MacMirrorly --format UDZO "$staging_dir" "$output_dmg"

if [[ -n "$sign_identity" ]]; then
  codesign --sign "$sign_identity" --timestamp \
    --identifier com.ivan.macmirrorly.dmg "$output_dmg"
fi

hdiutil verify "$output_dmg"
echo "Created $output_dmg"
