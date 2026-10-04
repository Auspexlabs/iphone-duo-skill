#!/bin/bash
# Build, install and screenshot an app on the iPhone Duo simulator.
# Usage:
#   duo-sim.sh udid                                   -> UDID of the iPhone Duo simulator (boots it if needed)
#   duo-sim.sh build <project|workspace> <scheme>     -> builds with the newest iOS 27.1+ Xcode, prints .app path
#   duo-sim.sh run <App.app> [launch args...]         -> installs + launches (terminates a running copy first)
#   duo-sim.sh shot <out-prefix>                      -> screenshots every display: <prefix>-<id>-<w>x<h>.png
#   duo-sim.sh displays                               -> lists display ids and sizes
# simctl cannot fold the device: fold/unfold by hand in the Simulator window, then run `shot` again.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

udid() {
  local u
  u=$(xcrun simctl list devices available | grep -m1 "iPhone Duo" | grep -oE '[0-9A-F-]{36}' || true)
  [ -n "$u" ] || { echo "no iPhone Duo simulator; install the iOS 27.1+ runtime" >&2; exit 1; }
  if ! xcrun simctl list devices | grep "$u" | grep -q Booted; then
    xcrun simctl boot "$u" >/dev/null 2>&1 || true; open -a Simulator; xcrun simctl bootstatus "$u" -b >/dev/null
  fi
  echo "$u"
}

case "${1:-}" in
  udid) udid ;;
  build)
    proj="$2"; scheme="$3"; flag=-project; [[ "$proj" == *.xcworkspace ]] && flag=-workspace
    export DEVELOPER_DIR="${DEVELOPER_DIR:-$("$here/find-xcode.sh" --best)}"
    dd="${DERIVED_DATA:-DerivedData-duo}"
    xcodebuild $flag "$proj" -scheme "$scheme" -sdk iphonesimulator -configuration Debug \
      -destination "id=$(udid)" -derivedDataPath "$dd" -quiet build >&2
    find "$dd/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "*.app" | head -1 ;;
  run)
    app="$2"; shift 2; u=$(udid)
    bid=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app/Info.plist")
    xcrun simctl install "$u" "$app"
    xcrun simctl launch --terminate-running-process "$u" "$bid" "$@" ;;
  displays)
    xcrun simctl io "$(udid)" enumerate 2>/dev/null | grep -E "Display|Port|Size|ID|Class" || true ;;
  shot)
    prefix="$2"; u=$(udid)
    for id in 1 2 3 4; do
      f="$prefix-$id.png"
      # Some display ids hang instead of failing; give each one 8 s.
      xcrun simctl io "$u" screenshot --display "$id" "$f" >/dev/null 2>&1 & pid=$!
      for _ in $(seq 80); do kill -0 $pid 2>/dev/null || break; sleep 0.1; done
      if kill -0 $pid 2>/dev/null; then kill $pid 2>/dev/null; wait $pid 2>/dev/null; rm -f "$f"; echo "display $id: no answer"; continue; fi
      wait $pid 2>/dev/null || { rm -f "$f"; continue; }
      [ -s "$f" ] || { rm -f "$f"; continue; }
      w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}'); h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')
      # An inactive display returns a black frame, not an error.
      dark=$(python3 -c "from PIL import Image,ImageStat;print(int(ImageStat.Stat(Image.open('$f').convert('L')).mean[0]<3))" 2>/dev/null || echo 0)
      if [ "$dark" = 1 ]; then rm -f "$f"; echo "display $id: off"; continue; fi
      mv "$f" "$prefix-$id-${w}x$h.png"; echo "display $id: $prefix-$id-${w}x$h.png"
    done ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
