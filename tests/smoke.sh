#!/bin/bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

xcrun swiftc -swift-version 6 -default-isolation MainActor \
    "$root/ClipboardTransfer.swift" "$root/tests/main.swift" -o "$scratch/clipboard-test"
"$scratch/clipboard-test"

# Rebuild over an app with Finder metadata, which a signing-in-place build rejects.
app="$scratch/FtoA.app"
mkdir -p "$app/Contents"
cp "$root/Info.plist" "$app/Contents/Info.plist"
xattr -wx com.apple.FinderInfo 0000000000000000040000000000000000000000000000000000000000000000 "$app"
"$root/build.sh" "$app"
/usr/bin/codesign --verify --strict "$app"
xcrun lipo "$app/Contents/MacOS/FtoA" -verify_arch arm64 x86_64
printf 'Universal build and signing checks passed\n'
