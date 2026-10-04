# iPhone Duo — code patterns

Every snippet comes from the sample app in `example/DuoStopwatch` (a stopwatch with lap history). It builds with
Xcode 27.1 (iOS 27.1 SDK, Swift 6.4) and with Xcode 26.x, and was checked on the iPhone Duo simulator (cover,
inner display landscape and portrait, both arrangements). Duo code is wrapped in `#if compiler(>=6.4)` +
`@available(iOS 27.1, *)`, so older toolchains still build it.

| File | What it shows |
|---|---|
| `Sources/Duo.swift` | The two arrangements, `DuoCanvas`, `JoinLayout`, `RotationProbe`, the Bar items, the slide into the Bar |
| `Sources/App.swift` | Orientation rule by screen, root layout choice, fallback layout |
| `Sources/Views.swift` | Ordinary views shared by every layout (none of them knows about the Duo) |
| `Sources/Stopwatch.swift` | One `@Observable` model read by both panes, so folding loses nothing |

Run it: `xcodegen` in `example/DuoStopwatch`, build with Xcode 27.1, launch with `-demoRunning` (DEBUG) to
start the stopwatch two seconds after launch, `-arrangement joined` to see the other arrangement.

## Contents
- Choosing the arrangement
- The canvas: Main in slot 0, Fold where the arrangement says
- JoinLayout
- Reading the orientation in time (fixed only)
- Orientation rule
- Root: picking the layout
- Bar items
- Slide into the Bar

## Choosing the arrangement

`Sources/Duo.swift`. One constant per app; the sample lets a launch argument override it for screenshots.

```swift
enum DuoArrangement { case fixed, joined }

/// The sample's choice. `-arrangement joined` at launch overrides it (screenshots).
let arrangement: DuoArrangement = {
    if let i = CommandLine.arguments.firstIndex(of: "-arrangement"), CommandLine.arguments.indices.contains(i + 1),
       CommandLine.arguments[i + 1] == "joined" { return .joined }
    return .fixed
}()
```

## The canvas: Main in slot 0, Fold where the arrangement says

`Sources/Duo.swift`. `SingleScreen` is Main; it is always subview 0, so its state survives every fold and turn.
The window's long side says folded/unfolded (the size class flickers mid-rotation); the real safe-area insets
are read *outside* `ignoresSafeArea`, because inside it every child sees 0.

```swift
@available(iOS 27.1, *)
struct DuoCanvas: View {
    @Binding var path: [Session]
    @State private var orientation = UIInterfaceOrientation.unknown
    @State private var rotating = false
    @State private var size = CGSize.zero
    /// Fold's share of the window along the join axis. 0.5 = the hinge.
    @AppStorage("foldFraction") private var fraction = 0.5
    @State private var dragStart: Double?
    /// The window's real insets (trailing = the bar), measured outside `ignoresSafeArea`.
    @State private var windowInsets = EdgeInsets()

    /// The inner display is 951 pt on its long side in every orientation; the cover is 678 and never rotates
    /// (AppDelegate). The size class flickers to compact mid-rotation; the window size does not.
    private var unfolded: Bool { max(size.width, size.height) > 800 }

    private var side: FoldSide? {
        guard unfolded else { return nil }
        switch arrangement {
        case .joined:
            return .leading
        case .fixed:
            switch orientation {
            case .landscapeLeft: return .leading
            case .landscapeRight: return .trailing
            case .portrait: return .bottom
            case .portraitUpsideDown: return .top
            default: return nil
            }
        }
    }

    private var foldFraction: Double {
        switch arrangement {
        case .joined: size.width > size.height ? 0.5 : 0.4
        case .fixed: fraction
        }
    }

    /// Main's start button slides into the bar only when Main touches the bar's edge (trailing). In the fixed
    /// arrangement turned 180° the bar is beside Fold, so there is nothing to slide into: pass 0.
    private var mainBarInset: CGFloat {
        side == nil || side == .leading ? windowInsets.trailing : 0
    }

    var body: some View {
        if arrangement == .fixed && orientation == .unknown {
            Color(.systemBackground).ignoresSafeArea().background { probe }   // no wrong-layout flash at launch
        } else {
            JoinLayout(side: side, fraction: foldFraction) {
                SingleScreen(path: $path, barInset: mainBarInset)             // Main: slot 0, always
                if let side {
                    FoldPage().overlay(alignment: side.joinAlignment) { foldLine(side) }
                }
            }
            .ignoresSafeArea()   // bounds = the whole window, so 0.5 is the hinge
            // Fixed: the panes never move on the glass; a turn only re-orients what is inside them. So the
            // rotation transition must not animate pane frames (it would slide Main from "right" to "top" on
            // screen). Only while rotating: the same modifier would also kill Main's own animations.
            .transaction { if rotating { $0.animation = nil } }
            .background { probe }
            .background {
                // Insets read here, outside ignoresSafeArea: inside it every child sees 0.
                Color.clear.onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { windowInsets = $0 }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        }
    }

    @ViewBuilder private var probe: some View {
        if arrangement == .fixed { RotationProbe(orientation: $orientation, rotating: $rotating) }
    }
    // foldLine / dragHandle: a 1-pt line on the edge of Fold facing Main; in the fixed arrangement a 24-pt
    // drag area over it changes `fraction` (clamped 0.25…0.75) along the join axis.
}
```

The fold line sits on the edge of Fold that faces Main:

```swift
extension FoldSide {
    var joinAlignment: Alignment {
        switch self {
        case .leading: .trailing
        case .trailing: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }
}
```

## JoinLayout

`Sources/Duo.swift`. A `Layout` instead of `HStack`/`VStack` so the two subviews never change order or
container when the side changes.

```swift
enum FoldSide: Equatable { case leading, trailing, top, bottom }

/// Places Main (subview 0) and Fold (subview 1, when present) without ever reordering them.
struct JoinLayout: Layout {
    var side: FoldSide?
    var fraction: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count > 1, let side else {
            subviews[0].place(at: b.origin, proposal: .init(b.size)); return
        }
        var m = b, f = b
        switch side {
        case .leading:
            f.size.width = b.width * fraction; m.origin.x += f.width; m.size.width -= f.width
        case .trailing:
            m.size.width = b.width * (1 - fraction); f.origin.x = m.maxX; f.size.width = b.width - m.width
        case .top:
            f.size.height = b.height * fraction; m.origin.y += f.height; m.size.height -= f.height
        case .bottom:
            m.size.height = b.height * (1 - fraction); f.origin.y = m.maxY; f.size.height = b.height - m.height
        }
        subviews[0].place(at: m.origin, proposal: .init(m.size))
        subviews[1].place(at: f.origin, proposal: .init(f.size))
    }
}
```

## Reading the orientation in time (fixed only)

`Sources/Duo.swift`. A view controller in the hierarchy gets `viewWillTransition(to:with:)` before the layout
for the new size; by then the scene already reports the orientation it is turning to. Report it there, and
flag `rotating` for the length of the system animation.

```swift
struct RotationProbe: UIViewControllerRepresentable {
    @Binding var orientation: UIInterfaceOrientation
    @Binding var rotating: Bool

    func makeUIViewController(context: Context) -> VC { VC() }
    func updateUIViewController(_ vc: VC, context: Context) {
        vc.report = { orientation = $0 }
        vc.setRotating = { rotating = $0 }
    }

    final class VC: UIViewController {
        var report: (UIInterfaceOrientation) -> Void = { _ in }
        var setRotating: (Bool) -> Void = { _ in }
        private var last: UIInterfaceOrientation?

        private var current: UIInterfaceOrientation? {
            let o = view.window?.windowScene?.effectiveGeometry.interfaceOrientation
            return o == .unknown ? nil : o
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            if let o = current, o != last { last = o; report(o) }
        }

        override func viewWillTransition(to size: CGSize, with c: any UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: c)
            setRotating(true)
            if let o = current, o != last { last = o; report(o) }
            c.animate(alongsideTransition: nil) { _ in self.setRotating(false) }
        }
    }
}
```

## Orientation rule

`project.yml` allows all four on iPhone; `Sources/App.swift` decides at runtime by the **screen**, not the size
class (stale during a fold).

```yaml
UISupportedInterfaceOrientations~iphone:
  - UIInterfaceOrientationPortrait
  - UIInterfaceOrientationPortraitUpsideDown
  - UIInterfaceOrientationLandscapeLeft
  - UIInterfaceOrientationLandscapeRight
```

```swift
/// Cover: portrait only, so folding never rotates the window. Inner display: all four ways. Other iPhones:
/// portrait. Decided from the screen the window is on, not from its size class: during a fold the size class
/// is still the old one when iOS asks, and answering "all" makes the cover turn landscape and then back.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        let s = window?.screen.bounds.size ?? .zero
        return max(s.width, s.height) > 800 ? .all : .portrait   // the inner display is 951 pt long, the cover 678
    }
}
```

Connect it with `@UIApplicationDelegateAdaptor private var delegate: AppDelegate` in the `App`, and re-ask on
size-class changes (below).

## Root: picking the layout

`Sources/App.swift`. The canvas on iOS 27.1+ phones (on a non-folding iPhone it is just Main), the plain split
view elsewhere. `path` lives here, above both panes.

```swift
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Shared by every layout, so nothing resets when the device folds.
    @State private var path: [Session] = []

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone, let canvas = duoCanvas {
                canvas
            } else {
                ClassicView()   // iPad, and phones below iOS 27.1
            }
        }
        .onChange(of: sizeClass) {
            // Folding swaps a regular-width screen for a compact one; the allowed orientations follow.
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    private var duoCanvas: AnyView? {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) { return AnyView(DuoCanvas(path: $path)) }
        #endif
        return nil
    }
}
```

## Bar items

`Sources/Duo.swift`, `SingleScreen`. Home at the top; adjacent items share one bubble, `ToolbarSpacer(.fixed)`
splits bubbles, and `.bottomBar` pins items to the bottom of the Bar. Pushed pages repeat `.toolbar { barItems }`
so the Bar keeps its controls. Home and the running face swap in place instead of being pushed, so the Bar
keeps its identity. All constructs and what they do: `references/bar.md`.

```swift
NavigationStack(path: $path) {
    ZStack {
        if stopwatch.isActive {
            StopwatchFace().transition(.opacity)
        } else {
            HomePage(hideStart: slide != nil, open: { path = [$0] }) { startFrame = $0 }
                .transition(.opacity)
        }
    }
    .animation(.smooth(duration: 0.35), value: stopwatch.isActive)
    .navigationTitle(stopwatch.isActive ? "" : "Stopwatch")
    .toolbar { barItems }
    .navigationDestination(for: Session.self) { SessionDetail(session: $0).toolbar { barItems } }
}

/// Home at the top; while running, Lap; then Pause + Stop as one bubble pinned to the bottom.
@ToolbarContentBuilder private var barItems: some ToolbarContent {
    ToolbarItem { Button { path = [] } label: { Label("Home", systemImage: "house") } }
        .axisBehavior(.verticalPreferred)
    if stopwatch.isActive {
        ToolbarSpacer(.fixed).axisBehavior(.verticalPreferred)
        ToolbarItem {
            Button { stopwatch.lap() } label: { Label("Lap", systemImage: "flag") }
                .disabled(stopwatch.phase != .running)
        }
        .axisBehavior(.verticalPreferred)
        ToolbarItem(placement: .bottomBar) {
            Button { stopwatch.phase == .paused ? stopwatch.resume() : stopwatch.pause() } label: {
                Label(stopwatch.phase == .paused ? "Resume" : "Pause",
                      systemImage: stopwatch.phase == .paused ? "play.fill" : "pause.fill")
            }
        }
        .axisBehavior(.verticalPreferred)
        ToolbarItem(placement: .bottomBar) {
            Button { stopwatch.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                // The bar ignores .opacity on its items; tint is honored, so hide the icon with a clear tint
                // while the slide overlay stands in for it.
                .tint(slide.map { $0.toBar && $0.stage == 2 } ?? true ? .red : .clear)
        }
        .axisBehavior(.verticalPreferred)
    }
}
```

## Slide into the Bar

`Sources/Duo.swift`, `SingleScreen`. The content Start button slides straight right along its own row to the
Bar's column, narrows into a round Stop button, then cross-fades with the real Bar item. Stop plays it
backwards. The Bar's column comes from the window's trailing inset, passed in as `barInset` (a toolbar item's
own frame is in another coordinate space; and under `ignoresSafeArea` the view's own inset reads 0). With
`barInset == 0` — no Bar on this edge — there is no slide.

```swift
struct SingleScreen: View {
    @Binding var path: [Session]
    /// Width of the vertical bar on this view's trailing edge (0 = no bar there, so no slide).
    var barInset: CGFloat
    @State private var startFrame = CGRect.zero   // HomePage reports it with .onGeometryChange(... .global)
    @State private var slide: Slide?

    /// stage 0: where it starts; 1: slid along its own row into the bar's column, now a round stop button;
    /// 2: faded out while the bar's real stop button fades in. Stopping plays it backwards.
    private struct Slide { var toBar: Bool; var stage = 0 }
    // …
    // on the NavigationStack:
    //   .overlay { slideOverlay }
    //   .onChange(of: stopwatch.isActive) { _, active in run(toBar: active) }

    @ViewBuilder private var slideOverlay: some View {
        if let s = slide {
            GeometryReader { geo in
                let origin = geo.frame(in: .global).origin
                let h = startFrame.height
                let barMidX = origin.x + geo.size.width - barInset / 2
                let inBar = CGRect(x: barMidX - h / 2, y: startFrame.minY, width: h, height: h)
                let keys: [(CGRect, Double)] = s.toBar
                    ? [(startFrame, 1), (inBar, 1), (inBar, 0)]
                    : [(inBar, 0), (inBar, 1), (startFrame, 1)]
                let (r, alpha) = keys[s.stage]
                let round = s.toBar ? s.stage >= 1 : s.stage <= 1
                RoundedRectangle(cornerRadius: round ? h / 2 : 14)
                    .fill(round ? Color.red : Color.primary)
                    .overlay {
                        ZStack {
                            Image(systemName: "stop.fill").foregroundStyle(.white)
                                .opacity(round ? 1 : 0)
                                .animation(.easeOut(duration: 0.12), value: round)
                            Text("Start").font(.headline).foregroundStyle(Color(.systemBackground)).fixedSize()
                                .opacity(round ? 0 : 1)
                                .animation(.easeOut(duration: 0.12), value: round)
                        }
                    }
                    .clipped()
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX - origin.x, y: r.midY - origin.y)
                    .opacity(alpha)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func run(toBar: Bool) {
        guard startFrame != .zero, barInset > 0 else { return }
        slide = Slide(toBar: toBar)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))   // let the bar lay out
            if toBar {
                withAnimation(.easeInOut(duration: 0.45)) { slide?.stage = 1 }
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.18)) { slide?.stage = 2 }
                try? await Task.sleep(for: .milliseconds(180))
            } else {
                withAnimation(.easeIn(duration: 0.15)) { slide?.stage = 1 }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.easeInOut(duration: 0.45)) { slide?.stage = 2 }
                try? await Task.sleep(for: .milliseconds(450))
            }
            slide = nil
        }
    }
}
```

While the overlay runs, hide the real content button (`HomePage(hideStart: slide != nil, …)`) and the real
Bar Stop item with `.tint(.clear)` — the Bar ignores `.opacity` on its items (verified: the red square stayed
visible mid-slide).
