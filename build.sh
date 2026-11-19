#!/bin/bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="${1:-$source_dir/build/FtoA.app}"
mkdir -p "$(dirname -- "$output")"
output_dir="$(cd -- "$(dirname -- "$output")" && pwd)"
output="$output_dir/$(basename -- "$output")"

if [[ -e "$output" || -L "$output" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$output/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -L "$output" || "$existing_id" != "com.github.teodorik.figmatoaffinity" ]]; then
        printf 'Refusing to replace an unrelated path: %s\n' "$output" >&2
        exit 1
    fi
fi

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
app="$scratch/FtoA.app"
mkdir -p "$app/Contents/MacOS"

for architecture in arm64 x86_64; do
    xcrun swiftc -O -swift-version 6 \
        -default-isolation MainActor \
        -enable-upcoming-feature NonisolatedNonsendingByDefault \
        -target "${architecture}-apple-macos13.0" \
        "$source_dir/main.swift" "$source_dir/ClipboardTransfer.swift" \
        -o "$scratch/$architecture"
done

cp -X "$source_dir/Info.plist" "$app/Contents/Info.plist"
xcrun lipo -create "$scratch/arm64" "$scratch/x86_64" -output "$app/Contents/MacOS/FtoA"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"

# Keep the previous build until the replacement has passed signature verification.
if [[ -e "$output" ]]; then
    mv -- "$output" "$scratch/previous.app"
fi
if mv -- "$app" "$output"; then
    # A synced Documents folder can add Finder metadata as the bundle arrives.
    if xattr -p com.apple.FinderInfo "$output" >/dev/null 2>&1; then
        xattr -d com.apple.FinderInfo "$output"
    fi
    if /usr/bin/codesign --verify --strict "$output"; then
        printf 'Built %s\n' "$output"
        exit 0
    fi
    mv -- "$output" "$scratch/failed.app"
fi
if [[ -e "$scratch/previous.app" ]]; then
    mv -- "$scratch/previous.app" "$output"
fi
exit 1
