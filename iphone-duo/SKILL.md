---
name: iphone-duo
description: Design and build SwiftUI apps for the iPhone Duo, Apple's foldable iPhone (iOS 27.1+). Covers the three screens (cover, main panel, split panel), the two arrangements for the unfolded display (fixed — Main locked to its panel; joined — one iPad-like picture), the vertical bar and what every toolbar construct does in it, folding without losing state, orientation, the Xcode/SDK setup that makes the app render natively instead of letterboxed, which Duo APIs really exist, and how to check it all in the simulator. Use this skill whenever the user mentions iPhone Duo, a foldable iPhone, the cover or inner display, unfolding/folding, the vertical bar or "right-side bar", hinge/posture, axisBehavior, verticalBarEdge, ArrangementView, or reports that their app looks small/letterboxed/"not filling the screen" on a Duo — even if they only ask for a layout tweak.
---

# iPhone Duo

The iPhone Duo folds. Outside, a 5.4" **cover display**; inside, a 7.6" display made of two panels around the
hinge. It shipped with iOS 27; its layout APIs arrived in the **iOS 27.1 SDK**. It is a phone, not an iPad: the
app's complete phone UI is what the cover shows, and unfolding adds a second panel to it.

Everything here was measured on the iOS 27.1 SDK and the iPhone Duo simulator with the lab app in
`example/DuoLab`. The platform is young: confirm any API name with `scripts/check-api.sh` before using it.

## 1. Vocabulary: three screens, three parts

Physical screens:

- **单屏 / cover** — the outside display, 466 × 678 pt, compact width, portrait only. Folded = this.
- **主屏 / main panel** — the inner half that is the back of the cover. When you unfold, it is the half that
  carries the vertical bar (the right half, in landscape).
- **分屏 / split panel** — the other inner half. Unfolded, the two panels make one 951 × 669 pt window.

Parts of the app:

- **Main** — the page the cover shows. The whole phone app. Design it first, complete on its own.
- **Fold** — the page that opens on the other panel when unfolded. Complements Main, never repeats it: a
  library when Main is a task, the notes or detail of what Main is doing, a reference panel.
- **Bar** — the vertical bar on the trailing edge where the system puts the status items and your toolbar
  items. Main's controls live there on every page.

Rules that hold in both arrangements below:

- Unfolding never changes Main: same content, same scroll position, same controls in the Bar. Keep Main in
  the **same slot of one layout** in every pose (slot 0 of the `JoinLayout` in `references/code.md`); swapping
  it between two container views loses its state. Lift navigation and selection above both panes.
- Folded shows Main alone, in every arrangement.
- The split line is the hinge: 50 % of the whole window (including the Bar), so draw the layout with
  `ignoresSafeArea()` and re-read the real insets outside it when you need them.
- Inner display in portrait has no Bar; toolbar items move to a horizontal bar at the top of Main.

## 2. Pick an arrangement

Two ways to use the unfolded display. Pick one per app; both are in the sample (`example/DuoStopwatch`,
`arrangement` constant).

### 固定式 — fixed: Main is locked to its panel

Main stays on the main panel whatever way the phone is turned, like a layout painted on the glass: turn the
phone and Main's panel moves with it; only what is drawn inside each pane is re-laid out upright. Fold is
always on the other panel.

- Use when content belongs to a hand or a side of the table: a recorder under the thumb, a translation page
  facing the person opposite, controls that must not jump.
- iOS does not track panels: the Bar stays on the trailing edge in every pose, `ArrangementView` keeps its
  primary on the leading edge. The only signal for where the main panel went is the **interface
  orientation**, read in `viewWillTransition(to:with:)` so the arrangement changes in the same frame as the
  size (a post-layout reader lags a frame and shows the old arrangement squeezed into the new window):

  | interfaceOrientation | Main | Fold joins from |
  |---|---|---|
  | landscapeLeft (the unfold pose) | right | leading |
  | portraitUpsideDown | bottom | top |
  | landscapeRight | left | trailing |
  | portrait | top | bottom |

- During the system's rotation the pane frames must **not** animate (SwiftUI would slide Main from "right"
  to "top" on screen); strip the transaction's animation only while rotating, or you also kill Main's own
  animations. What remains is the system's crossfade per pane — the price of going against Apple's
  window-relative model. This is Apple's design language, not a bug you can fix: the whole-picture turn an
  iPad shows cannot keep a pane on its panel.
- The fold line can be dragged; persist the fraction.
- After a 180° turn the Bar is beside Fold; Main's toolbar items then render in Main's own vertical column at
  the hinge, and animations aimed at the window Bar (a button sliding into it) must be skipped.

### 混合式 — joined: one iPad-like picture

Main and Fold form one picture placed relative to the window: Fold is a sidebar on the leading side (half
the width when wide — the hinge; ~40 % when tall), Main on the trailing side beside the Bar. The picture
rotates with the system as a whole, like any iPad app; after a 180° turn Main is on the other panel.

- Use when nothing is tied to a hand: browsing, reading, reference + content.
- Plain SwiftUI: no orientation code, no transaction tricks. Same `JoinLayout`, `side` always `.leading`.
- Folded: Main alone.

Not an arrangement: a separate portrait design and landscape design with no Main (plain adaptive layout).
It was tried and dropped; the cover page is the app, and the unfolded display should extend it, not replace it.

## 3. The Bar

Place controls in it through the toolbar, with `.axisBehavior(.verticalPreferred)` on each item
(`ToolbarContent`, iOS 27.1). Read `references/bar.md` for what every construct does; the short version:

- Adjacent items share one glass bubble; `ToolbarSpacer(.fixed)` splits bubbles; `ToolbarSpacer(.flexible)`
  does **not** push items to the bottom — `ToolbarItem(placement: .bottomBar)` pins them there.
- Bubbles are circles. `.buttonBorderShape` is ignored; for a square, hide the shared background
  (`.sharedBackgroundVisibility(.hidden)`) and draw your own shape, solid or `glassEffect`.
- `.glassProminent` / `.borderedProminent` items become their own filled circle and leave the group.
- Color an icon with `.tint`; the Bar ignores `.opacity` and `.foregroundStyle` on item content. To hide an
  item temporarily use `.tint(.clear)`.
- Status readouts: `Text` + `.sharedBackgroundVisibility(.hidden)`. Keep Bar text short.
- ~8 items fit on the cover; the rest go to a "⋯" overflow. A `TabView`'s tab bar lives at the bottom of the
  Bar, under your `.bottomBar` items.
- Pushed destinations must repeat the same `.toolbar { … }` or the Bar loses the persistent controls.
- Is there a Bar? `@Environment(\.toolbarVerticalEdge)` (`HorizontalEdge?`, SwiftUICore): `.trailing` on the
  cover and in landscape, `nil` on the inner display in portrait.

Animating a content button into the Bar: a toolbar item's frame is in another coordinate space, so aim at the
Bar's column from the window's trailing safe-area inset (`maxX - inset / 2`), slide along the button's own
row, narrow into the round Bar button and cross-fade. Code in `references/code.md`.

## 4. Toolchain: why an app looks letterboxed on the Duo

An app built with an SDK older than iOS 27.1 runs in compatibility mode: a virtual 375 × 667 pt screen,
black bars, no Bar. `UIScreen.main.bounds` reports 375 × 667. No layout change can fix it — rebuild.

- `scripts/find-xcode.sh` lists every Xcode on the Mac (including ones outside `/Applications`) with its iOS
  SDK and whether it can build for the Duo; `--best` prints the `DEVELOPER_DIR` to use. A 27.x *simulator
  runtime* can be installed without the SDK, so "the Duo simulator runs" does not mean "this Xcode can build
  for it".
- Build with `DEVELOPER_DIR=… xcodebuild …` and a separate `-derivedDataPath` per Xcode. Projects that compile
  Metal need `xcodebuild -downloadComponent MetalToolchain` once per Xcode.
- Keep older Xcode building: wrap Duo code in `#if compiler(>=6.4)` (Swift 6.4 = Xcode 27.x) **and**
  `if #available(iOS 27.1, *)`. `#available` alone does not help when the SDK lacks the symbol.
- Check API names in the SDK with `scripts/check-api.sh <name>`; it searches SwiftUI, **SwiftUICore** and
  UIKit — most new SwiftUI symbols (`ArrangementView`, `onHingeChange`, `toolbarVerticalEdge`) live in
  SwiftUICore and a search of SwiftUI alone wrongly reports them missing. The verified list, with what was
  exercised, is `references/api.md`.

## 5. Orientation

- `UISupportedInterfaceOrientations~iphone`: all four. Decide at runtime in
  `application(_:supportedInterfaceOrientationsFor:)`. The one rule that matters: **the answer must be the
  same before and after the window moves between displays**, or the cover lands in one orientation and
  turns to another (seen in the log: 594×432 → 382×644 → 594×432, "Main flips and flips back").
  - Inner display: `.all` — identified by the window's screen (`window.screen.bounds` long side 951) **and**
    the hinge being open. During a fold iOS asks while the window is still on the inner screen; the hinge
    already reads `closed` at that moment (`onHingeChange`), so answer for the cover right away.
  - Cover, portrait-only app (most phone UIs): `.portrait`.
  - Cover, app whose Main works in landscape (video, games): `.allButUpsideDown`. Known, and not fixable by
    the app: at the end of every fold the simulator reports the cover in one landscape while the hinge swings
    and the opposite one at 0°, so the cover turns once when it settles. iOS never displays an orientation
    the device is not in, so predicting the settled one makes iOS fall back to portrait instead (tried);
    blanking the content mid-swing was tried and dropped. Keep the cover portrait-only unless Main really
    needs landscape.
  - Never decide by size class: it is still the old one when iOS asks.
- Re-ask with `setNeedsUpdateOfSupportedInterfaceOrientations()` on every hinge change and size-class change.
- Folded/unfolded gate for the layout: the window's long side (> 800 pt = inner display). The size class
  flickers to compact mid-rotation; the hinge status is stable through rotation but *leads* the display
  switch by a frame.
- On the cover in landscape the Bar moves to the **leading** edge; animations aimed at a trailing Bar must
  check which edge it is on.

## 6. Checking it in the simulator

Read `references/simulator.md` first. The essentials: `simctl` can neither fold nor rotate the device (menu
clicks and ⌘← sent by script are ignored); the two displays are two windows and two display IDs; judge
rotation and fold transitions in **Simulator.app or from `recordVideo`**, never in Xcode's Device Hub (it
never turns the device picture); record video with `scripts/record-frames.sh` and read frames; give the app
debug launch arguments that put it straight into a state; log state to `Documents/log.txt` and read it with
`simctl get_app_container`.

## Checklist for a Duo pass

1. Built with the iOS 27.1+ SDK (`UIScreen.main.bounds` not 375 × 667).
2. Main complete on its own on the cover; controls in the Bar, grouped deliberately, pinned where needed.
3. Arrangement chosen (fixed or joined) and written down; Fold complements Main, never repeats it.
4. Main in one layout slot in every pose; one navigation/selection state above both panes; fold, unfold,
   turn — same page, same controls, same scroll position.
5. Fixed only: orientation read in `viewWillTransition`; pane frames not animated while rotating; 180° pose
   handled (Bar beside Fold).
6. Split on the hinge (50 % of the whole window); fold line draggable where it makes sense.
7. Orientation rule answers the same before and after a fold (hinge + screen); inner all four ways; cover
   portrait or allButUpsideDown by what Main supports; no flip when folding from a portrait pose.
8. Older Xcode still builds (`#if compiler(>=6.4)`).
9. Verified with screenshots of the cover, inner landscape and inner portrait, and frames of every animation.
