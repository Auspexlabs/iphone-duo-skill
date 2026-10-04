#!/bin/bash
# List every Xcode on this Mac (including ones outside /Applications) with its iOS SDK version,
# and say which can build for the iPhone Duo (iOS 27.1+ SDK).
# Usage: find-xcode.sh            -> table
#        find-xcode.sh --best     -> prints DEVELOPER_DIR of the newest release (else beta) Xcode with an iOS 27.1+ SDK (exit 1 if none)
set -euo pipefail
best="" best_ver="0"
rows=()
while IFS= read -r app; do
  [ -d "$app/Contents/Developer" ] || continue
  dev="$app/Contents/Developer"
  xc=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null || echo "?")
  sdk=$(DEVELOPER_DIR="$dev" xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || echo "none")
  ok="no"
  if [ "$sdk" != "none" ] && printf '%s\n%s\n' "27.1" "$sdk" | sort -V -C; then
    ok="yes"
    # Prefer a release Xcode over a beta; among the same kind, the newest SDK.
    rank="1$sdk"; [[ "$app" == *[Bb]eta* ]] && rank="0$sdk"
    if printf '%s\n%s\n' "$best_ver" "$rank" | sort -V -C; then best="$dev"; best_ver="$rank"; fi
  fi
  rows+=("$xc|$sdk|$ok|$dev")
done < <(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null; ls -d /Applications/Xcode*.app 2>/dev/null)

if [ "${1:-}" = "--best" ]; then
  [ -n "$best" ] && { echo "$best"; exit 0; } || { echo "no Xcode with an iOS 27.1+ SDK found" >&2; exit 1; }
fi
printf '%-10s %-8s %-6s %s\n' XCODE IOS_SDK DUO DEVELOPER_DIR
printf '%s\n' "${rows[@]}" | sort -u | while IFS='|' read -r xc sdk ok dev; do
  printf '%-10s %-8s %-6s %s\n' "$xc" "$sdk" "$ok" "$dev"
done
[ -n "$best" ] && echo && echo "Build for the Duo with: DEVELOPER_DIR=$best"
