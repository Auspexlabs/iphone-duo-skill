# iphone-duo — an agent skill for building iPhone Duo apps

English · [中文](README.zh-CN.md)

A coding-agent skill (a `SKILL.md` with references and scripts) for designing and building SwiftUI apps
for the iPhone Duo, Apple's foldable iPhone (iOS 27.1+). Everything in it was measured on the iOS 27.1 SDK and
the iPhone Duo simulator with the lab app in this repository.

## The model

Three screens: the **cover** (单屏) outside; inside, the **main panel** (主屏, the back of the cover) and the
**split panel** (分屏) around the hinge. Three parts of an app: **Main**, the complete phone app the cover
shows; **Fold**, the page that opens on the other panel when unfolded; **Bar**, the vertical bar where the
controls live.

Two arrangements for the unfolded display — pick one per app:

| | 固定式 · fixed | 混合式 · joined |
|---|---|---|
| Main | locked to the main panel, whatever way the phone is turned | beside the Bar, relative to the window |
| Fold | always on the other panel | a sidebar on the leading side |
| Turning the phone | panes stay on their glass, only the content re-orients | the whole picture turns, like an iPad app |
| After 180° | Main on the same glass (user's left) | Main on the other glass (user's right) |
| Code | orientation table + a small UIKit probe | plain SwiftUI |
| For | content tied to a hand or a side of the table | browsing, reading, reference + content |

Folded, both show Main. Main keeps its state through every fold and turn in both.

The skill also covers what the Bar does with every toolbar construct (grouping, pinning, square buttons,
overflow, tab bars), the Xcode/SDK setup that stops the app from being letterboxed, which Duo APIs really exist
(`ArrangementView`, `onHingeChange` and `toolbarVerticalEdge` live in SwiftUICore — and why the skill does not
use `ArrangementView`), orientation and folding without a flash, and how to verify all of it in the simulator.

## Screenshots

All taken on the iPhone Duo simulator (iOS 27.1) from the sample app in this repository.

| Cover: Main alone | Cover, running: Lap in the Bar, Pause + Stop pinned at the bottom |
|---|---|
| ![cover](docs/images/cover-main.png) | ![cover running](docs/images/cover-running.png) |

Unfolded, in the unfold pose (both arrangements look the same here): Fold on the left, Main on the right beside the Bar.

![unfold pose](docs/images/inner-unfold-pose.png)

| 固定式 fixed, phone turned 180°: Main stays on its glass (now on the left) | 混合式 joined, phone turned 180°: Main stays beside the Bar (the other glass) |
|---|---|
| ![fixed 180](docs/images/inner-fixed-turned-180.png) | ![joined 180](docs/images/inner-joined-turned-180.png) |

Unfolded, running:

![running](docs/images/inner-running.png)

The Start button sliding into the Bar and becoming Stop:

![slide](docs/images/start-slides-into-bar.gif)

The Bar with different toolbar constructs (`references/bar.md`): grouping and pinning · button styles · content kinds · placements · a tab bar. And square buttons: default, `.bordered` with a rounded shape (inside the bubble), custom solid, custom glass.

| ![bar gallery](docs/images/bar-gallery.png) | ![square](docs/images/bar-square-buttons.png) |
|---|---|

## Install

Copy the `iphone-duo` folder into your agent's skills directory (`~/.claude/skills/` for a personal install, or `.claude/skills/` inside a project).

## Contents

- `iphone-duo/SKILL.md` — the model, the two arrangements, the Bar, toolchain, orientation, checklist
- `iphone-duo/references/code.md` — the patterns, all taken from the sample app
- `iphone-duo/references/bar.md` — what each toolbar construct does in the vertical bar
- `iphone-duo/references/api.md` — every Duo API in the 27.1 SDK, exercised vs. declared
- `iphone-duo/references/simulator.md` — building, folding, screenshots, video, reading app state
- `iphone-duo/scripts/` — `find-xcode.sh`, `check-api.sh`, `duo-sim.sh`, `record-frames.sh`
- `example/DuoStopwatch` — a small, complete sample app (stopwatch with lap history) with both arrangements.
  `xcodegen` in that folder, build with Xcode 27.1 for the iPhone Duo simulator.
- `example/DuoLab` — the lab app behind the measurements (needs Xcode 27.1).
