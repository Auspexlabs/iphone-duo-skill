# iPhone Duo APIs in the iOS 27.1 SDK

Every name below was found in the SDK shipped with Xcode 27.1 (`iPhoneOS27.1.sdk`): UIKit headers, and the
`arm64e-apple-ios.swiftinterface` of SwiftUI **and SwiftUICore**. Most of the new SwiftUI symbols live in
SwiftUICore; a search of SwiftUI alone wrongly reports them missing. Check any name with
`scripts/check-api.sh <name>`.

"Exercised" = used in the sample or the probe app and seen working on the iPhone Duo simulator.
"Declared" = present in the SDK, not run by us.

## Contents
- Vertical bar
- Hinge
- Arrangement (two-pane container) — and why the skill does not use it
- Orientation and geometry (existing APIs you need)

## Vertical bar

| API | Module | Status | Notes |
|---|---|---|---|
| `ToolbarContent.axisBehavior(_:)` / `CustomizableToolbarContent.axisBehavior(_:)` | SwiftUI | exercised | `.automatic`, `.horizontalOnly`, `.verticalPreferred` (`ToolbarItemAxisBehavior`). `.automatic` already put a plain icon button in the bar; `.horizontalOnly` kept it in a horizontal bar at the top. |
| `EnvironmentValues.toolbarVerticalEdge: HorizontalEdge?` | SwiftUICore | exercised | `.trailing` whenever the bar exists (cover; inner display in landscape, both directions), `nil` on the inner display in portrait. Pure-SwiftUI replacement for the UIKit trait below. |
| `UITraitCollection.verticalBarEdge: UIVerticalBarEdge` | UIKit | exercised | `.unspecified` / `.leading` / `.trailing`. Same values as above; a UIKit probe is only needed below iOS-27.1-SwiftUI code paths. |
| `UITraitCollection.systemTraitsAffectingVerticalBarEdge` | UIKit | exercised | Pass to `registerForTraitChanges` to be told when the edge may change. |
| `UIViewController.preferredVerticalBarBehavior: UIVerticalBarBehavior` | UIKit | declared | `.automatic` / `.disabled`. Override to opt a screen out of the bar (fullscreen video, calculator). Apple's header: treat it as a stable choice, don't toggle per state. |
| `UIViewController.childForPreferredVerticalBarBehavior` | UIKit | declared | Containers forward to their active child by default. |
| `UIViewController.setNeedsUpdateOfVerticalBarConfiguration()` | UIKit | declared | Call after the preference changes. |
| `UIBarButtonItem.axisBehavior: UIBarButtonItem.AxisBehavior` | UIKit | declared | UIKit twin of `axisBehavior(_:)`. |
| `UINavigationItem.verticalBarCompressionBehavior: UIVerticalBarCompressionBehavior` | UIKit | declared | `.automatic` (prefers the tab bar) / `.prefersBarItems` / `.prefersTabBar`: which compresses first when a tab bar and bar items share the vertical bar. No SwiftUI equivalent found. |

## Hinge

| API | Module | Status | Notes |
|---|---|---|---|
| `View.onHingeChange(isEnabled:_:)` | SwiftUICore | exercised | Closure gets `(old: DeviceHingeContext, new: DeviceHingeContext)`. |
| `DeviceHingeContext.hinge: DeviceHinge?` | SwiftUICore | exercised | `nil` when the view is not in a hierarchy that reports a hinge. |
| `DeviceHinge.status: DeviceHinge.Status`, `DeviceHinge.angle: Angle` | SwiftUICore | exercised | Seen: `closed 0°` on the cover, `fullyOpen 180°` unfolded. `.partiallyOpen` exists (laptop pose) — not reproducible in the simulator. |
| `UIHingeInteraction(updateHandler:)`, `UIHingeInteraction.Update.hinge`, `UIHinge.status` / `.angle`, `UIHinge.Status` (`.unknown/.closed/.partiallyOpen/.fullyOpen`) | UIKit | declared | Add the interaction to a view; the handler is called with the initial state and on every change. Apple's header: prefer `status` over `angle` unless you need the angle; update rate is system policy. |

The hinge status is stable through a rotation (the size class is not), but it **leads** the display switch
by a frame: `partiallyOpen 173°` arrives while the window is still the cover's, and `closed 82°` while it is
still the inner display's. Use it to know the device is a foldable and what pose it is in; gate the layout on
the window size (long side > 800 pt = inner display), as the sample does.

## Arrangement (two-pane container)

| API | Module | Status | Notes |
|---|---|---|---|
| `ArrangementView(primary:secondary:)` | SwiftUICore | exercised | Generic over two views; also `init(_ configuration:)` for styles. |
| `View.arrangementViewStyle(_:)` with `.automatic`, `.split`, `.overlay` | SwiftUICore | exercised | `SplitArrangementViewStyle().axes(_:)`, `OverlayArrangementViewStyle().axes(_:)`. |
| `View.splitArrangementLayoutRatio(_:)` / `(minHorizontal:idealHorizontal:…)`, `splitArrangementLayoutSize(minWidth:idealWidth:…)`, `splitArrangementFixedLayoutSize(horizontal:vertical:)` | SwiftUICore | exercised (`LayoutSize`) | Put on a pane to size it; `idealWidth: 320` on the secondary gave a 320-pt pane. |
| `EnvironmentValues.splitArrangementAxis: Axis?`, `overlayArrangementZIndex: Int` | SwiftUICore | exercised | Read inside a pane: `.horizontal` side by side, `.vertical` stacked, `nil` when not split. |
| `View.overlayArrangementEdge(_:)` (`VerticalEdge?` or `HorizontalEdge?`) | SwiftUICore | declared | Edge a pane takes when an overlay arrangement becomes side-by-side. |
| `ArrangementViewStyle` protocol, `ArrangementViewStyleConfiguration.primary/.secondary` | SwiftUICore | declared | Custom styles. |
| `UIArrangementViewController`, `UIArrangement`, `UISplitArrangement` (+ `UISplitArrangementDimension`, `…DimensionRange`, `…ViewProperties`), `UIOverlayArrangement` (+ `…ViewProperties`), `UIArrangementViewState`, `UIViewController.arrangementViewController` | UIKit | declared | UIKit twin: `setViewController(_:forPlacement:)` with `.primary` / `.secondary`, `updateArrangement(_:animated:)`. |

What we measured on the iPhone Duo simulator with `ArrangementView(primary: Main, secondary: Fold)` (screens:
`docs/images/arrangementview-styles.png`):

| Style | Folded (cover) | Unfolded (inner, landscape) |
|---|---|---|
| `.automatic` | **both** shown, stacked: Main top, Fold bottom | Main left, Fold right |
| `.split.axes(.horizontal)` | Main only | Main left, Fold right |
| `.overlay` | Main only | Main only; Fold never appeared |
| `.split.axes(.horizontal)` + `layoutDirection = .rightToLeft` on the arrangement, `.leftToRight` on each pane | Main only | Fold left, Main right |

So the primary pane is the one the cover shows, and when unfolded it is always on the **leading** edge. The
skill's design wants the cover page on the trailing edge, beside the vertical bar (see SKILL.md); the only way
to get that from `ArrangementView` is the right-to-left trick, which is a hack. The sample uses a small custom
`Layout` instead (`references/code.md`). One more observation: when the pane with the toolbar was *not* the one
touching the vertical bar (`.split`, Main on the left), its `.verticalPreferred` items fell back to a horizontal
bar at the top.

## Orientation and geometry (existing APIs you need)

| API | Status | Notes |
|---|---|---|
| `UIWindowScene.effectiveGeometry.interfaceOrientation` | exercised | The only signal for "which way is the device turned" when the bar is on the trailing edge in both landscapes. Read it in `viewWillTransition(to:with:)` so the layout can change in the same frame as the size; a post-layout reader lags by a frame. |
| `UIViewControllerTransitionCoordinator.targetTransform` | exercised | Rotation delta of the upcoming transition; `atan2(t.b, t.a)`. |
| `UIApplicationDelegate.application(_:supportedInterfaceOrientationsFor:)` + `UIViewController.setNeedsUpdateOfSupportedInterfaceOrientations()` | exercised | Portrait-only on a compact window (cover, other iPhones), free rotation on a regular one (inner display). Re-ask after a fold. |
| `UIScreen.main.bounds` = 375 × 667 | exercised | Means the app was built with an SDK older than 27.1 and runs letterboxed. Rebuild. |
