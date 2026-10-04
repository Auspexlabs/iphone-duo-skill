#!/bin/bash
# Record a display of the iPhone Duo simulator while something animates, then build a contact sheet of the
# frames where a region changes. Screenshots (~0.4 s each) are too slow to judge a 0.5 s animation.
# Usage: record-frames.sh <display-id> <seconds> <out-dir> [--launch <bundle-id> [args...]] [--crop x,y,w,h]
#   --launch   relaunches the app right after recording starts (use a DEBUG launch argument that triggers the
#              animation a moment after launch).
#   --crop     region to watch, in 640-px-wide frame coordinates (default: whole frame).
# Output: <out-dir>/run.mp4, <out-dir>/f_###.png, <out-dir>/sheet.png
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
disp="$1"; secs="$2"; out="$3"; shift 3
bid=""; largs=(); crop=""
while [ $# -gt 0 ]; do
  case "$1" in
    --launch) bid="$2"; shift 2; while [ $# -gt 0 ] && [ "$1" != "--crop" ]; do largs+=("$1"); shift; done ;;
    --crop) crop="$2"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
done
command -v ffmpeg >/dev/null || { echo "needs ffmpeg (brew install ffmpeg)" >&2; exit 1; }
u=$("$here/duo-sim.sh" udid)
mkdir -p "$out"; rm -f "$out"/f_*.png "$out/run.mp4"
xcrun simctl io "$u" recordVideo --display "$disp" --force "$out/run.mp4" >/dev/null 2>&1 &
rec=$!
sleep 1
[ -n "$bid" ] && xcrun simctl launch --terminate-running-process "$u" "$bid" ${largs[@]+"${largs[@]}"} >/dev/null
sleep "$secs"
kill -INT "$rec"; wait "$rec" 2>/dev/null || true
ffmpeg -loglevel error -i "$out/run.mp4" -vf "fps=12,scale=640:-1" "$out/f_%03d.png"
python3 "$here/contact_sheet.py" "$out" ${crop:+--crop "$crop"}
