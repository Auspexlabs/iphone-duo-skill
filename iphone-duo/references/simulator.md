# Checking an iPhone Duo app in the simulator

Observed with Xcode 27.1 and the "iPhone Duo" simulator (iOS 27.1 runtime). The scripts in `scripts/` wrap
the commands below.

## Contents
- Building for it
- Folding and rotating: by hand only
- Two viewers, one truth
- Screenshots: pick the display
- Video: physical frames vs. viewer frames
- Reading app state without screenshots
- Measuring what the app actually gets
- Reaching states without hardware

## Building for it

```bash
scripts/find-xcode.sh                 # every Xcode on the Mac, its iOS SDK, which can build for the Duo
X=$(scripts/find-xcode.sh --best)     # DEVELOPER_DIR of the newest release Xcode with an iOS 27.1+ SDK

scripts/duo-sim.sh udid               # boots the iPhone Duo simulator if needed, prints its UDID
APP=$(scripts/duo-sim.sh build App.xcodeproj App)      # builds with $X, prints the .app path
scripts/duo-sim.sh run "$APP" -SomeLaunchArg           # install + launch
scripts/duo-sim.sh shot out/prefix    # screenshots every display that is on: prefix-<id>-<w>x<h>.png
```

Build once with the older Xcode too, to prove the `#if compiler(>=6.4)` gates hold.

## Folding and rotating: by hand only

`simctl` has no fold command, the Simulator's menus have none, and rotation sent by script (clicking
*Device ▸ Rotate Left* or sending ⌘← via System Events) is ignored by the Duo simulator. Fold, unfold and
rotate by hand in the Simulator window; the hinge angle animates over ~0.5 s and the hinge status reads
`closed` below ~85°, `partiallyOpen` up to 179°, `fullyOpen` at 180°.

Known poses (interface orientation → what it is): `landscapeLeft` is the pose you get by unfolding (bar on the
right); each ⌘← goes landscapeLeft → portraitUpsideDown → landscapeRight → portrait.

The cover window becomes active while the hinge is still closing (from ~85°, over ~0.5 s) and the simulator
reports its orientation as one landscape during the swing and the opposite one at exactly 0° (and flips again
the moment the hinge opens). A portrait-only cover is unaffected; a landscape-capable cover turns once at the
end of every fold. On the cover in landscape the vertical bar sits on the **leading** edge.

## Two viewers, one truth

The two displays are **two windows** titled the same in Simulator.app; the inactive one is black. Xcode's
Device Hub can show the same simulator too. They differ in what they animate:

- **Simulator.app** turns the device picture when the interface orientation changes.
- **Device Hub** never turns the device picture: it shows the screen buffer re-oriented to be upright. A
  window whose orientation is locked therefore looks "unchanged" there even though the device turned.
- Neither shows what iOS draws *during* a transition faithfully. For transitions, record video (below) and
  read frames.

Judge final layouts in either viewer; judge transitions only from recorded frames.

## Screenshots: pick the display

```bash
xcrun simctl io $U screenshot --display <id> shot.png
```

Cover = 1398 × 2034 px, inner display = 2007 × 2853 px (2853 × 2007 in landscape); the IDs were 1 and 3 but are
not guaranteed — identify by size. A display that is off returns a black image; some IDs hang instead of
failing, so wrap the call in a timeout (`scripts/duo-sim.sh shot` does). A shutdown device fails with
"Unable to lookup in current state: Shutdown".

Set the appearance for consistent documentation shots: `xcrun simctl ui $U appearance light`.

## Video: physical frames vs. viewer frames

Screenshots (~0.4 s each) are too slow for a 0.5 s animation; and only video shows what happens physically.

```bash
scripts/record-frames.sh <display-id> <seconds> out/ --launch com.example.App -DemoArg --crop x,y,w,h
# → out/run.mp4, out/f_###.png (12 fps, 640 px wide), out/sheet.png (frames where the crop changed)
```

- Only **one recording at a time** per simulator ("A recording is already in progress").
- The file is the display's **native** buffer (the inner display: 2006 × 2852, portrait) with a
  `rotation=±90` metadata tag. Players and `ffmpeg` auto-rotate it. To see the **physical** frame — which
  panel a pane is on, regardless of how the device is held — extract with `ffmpeg -noautorotate`. That is how
  the fixed arrangement's orientation table was verified (`docs/images/fixed-physical-frames.png`: Main stays
  on the top panel of the native frame through all four poses).
- Recording can start while the display is off; frames are black until it turns on.

## Reading app state without screenshots

Give the app a line-per-change log in its Documents directory and read it from the Mac:

```bash
cat "$(xcrun simctl get_app_container $U com.example.App data)/Documents/log.txt"
```

The lab app (`example/DuoLab`, `-fold`) logs orientation, bar edge, size class, window size, hinge status and
angle on every change. Two things it showed that screenshots cannot: the size class flickers to `compact`
mid-rotation, and the hinge status changes a frame before the window moves between displays.

## Measuring what the app actually gets

Overlay a debug label for one build:

```swift
.overlay(alignment: .top) {
    GeometryReader { g in
        let i = g.safeAreaInsets, s = UIScreen.main
        Text("view \(Int(g.size.width))×\(Int(g.size.height)) safe L\(Int(i.leading)) R\(Int(i.trailing)) | screen \(Int(s.bounds.width))×\(Int(s.bounds.height)) @\(s.scale)")
            .font(.caption2).background(.yellow)
    }
}
```

`screen 375×667` = compatibility mode (built with a pre-27.1 SDK). Measured on 27.1: cover 466 × 678 pt
(content 382 × 644, bar ≈ 84 pt trailing), inner landscape 951 × 669 (content 867 × 635), inner portrait
669 × 951 (no bar). Remove the overlay afterwards.

## Reaching states without hardware

`simctl` cannot tap. Give the app debug-only launch arguments that fill sample data or put it straight into
the state you need (e.g. `-demoRunning` in the sample starts the stopwatch two seconds after launch), compiled
only in `#if DEBUG`, and launch with `xcrun simctl launch $U <bundle-id> -Arg`.

GPU-heavy code may not run in the simulator at all. MLX, for example, aborts on the simulator's Metal device
(`mlx::core::metal::Device::Device()`). Guard such paths with `#if targetEnvironment(simulator)` and show the UI
without the model. Crash reports from the simulator land in `~/Library/Logs/DiagnosticReports/<App>-*.ips`.
