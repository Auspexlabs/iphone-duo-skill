#!/bin/bash
# Check whether API names exist in the iOS SDK: SwiftUI + SwiftUICore Swift interfaces and UIKit headers.
# Many Duo API names live in SwiftUICore, not SwiftUI — searching only SwiftUI gives false "doesn't exist".
# Usage: check-api.sh <name> [<name> ...]     e.g. check-api.sh onHingeChange ArrangementView toolbarVerticalEdge
# Env:   DEVELOPER_DIR (defaults to find-xcode.sh --best)
set -euo pipefail
[ $# -gt 0 ] || { sed -n '2,5p' "$0"; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
export DEVELOPER_DIR="${DEVELOPER_DIR:-$("$here/find-xcode.sh" --best)}"
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
echo "SDK: $sdk ($(xcrun --sdk iphoneos --show-sdk-version))"
fw="$sdk/System/Library/Frameworks"
files=()
for m in SwiftUI SwiftUICore UIKit; do
  f=$(ls "$fw/$m.framework/Modules/$m.swiftmodule/"arm64e-apple-ios.swiftinterface 2>/dev/null || true)
  [ -n "$f" ] && files+=("$f")
done
missing=0
for name in "$@"; do
  hits=$( { grep -n -w -- "$name" "${files[@]}" 2>/dev/null; grep -rn -w -- "$name" "$fw/UIKit.framework/Headers" 2>/dev/null; } \
          | grep -v '@_spi' | head -8 || true)
  if [ -z "$hits" ]; then
    echo "MISSING  $name"; missing=1
  else
    echo "FOUND    $name"
    echo "$hits" | sed -E "s#$fw/##; s#^#         #" | cut -c1-220
  fi
done
exit $missing
