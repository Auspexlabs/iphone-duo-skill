#if compiler(>=6.4)   // Swift 6.4 = Xcode 27.x, the first SDK with the iPhone Duo APIs
import SwiftUI
import UIKit

// MARK: - Arrangement

/// How Main and Fold share the inner display. Pick one for your app.
///
/// - `fixed` (固定式): Main is locked to one physical panel (the half that carries the vertical bar when you
///   unfold). Turn the phone and Main stays on its glass; only what is drawn inside each pane re-orients.
///   Needs the orientation table and a little UIKit (`RotationProbe`). Use when the content belongs to a hand
///   or a side of the table: a recorder under the thumb, a page facing someone else.
/// - `joined` (混合式): Main and Fold form one iPad-like picture placed relative to the window — Fold is a
///   sidebar on the leading side, half the width when wide (the hinge), 40 % when tall. Rotates with the system
///   as a whole; after a 180° turn Main is on the other panel. Plain SwiftUI, no orientation code.
///
/// Folded, both show Main alone. Main keeps its view state through every fold and turn in both.
enum DuoArrangement { case fixed, joined }

/// The sample's choice. `-arrangement joined` at launch overrides it (screenshots).
let arrangement: DuoArrangement = {
    if let i = CommandLine.arguments.firstIndex(of: "-arrangement"), CommandLine.arguments.indices.contains(i + 1),
       CommandLine.arguments[i + 1] == "joined" { return .joined }
    return .fixed
}()

// MARK: - The canvas: Main on its panel, Fold on the other one

/// Which side of Main the Fold page joins from, in the user's frame.
enum FoldSide: Equatable { case leading, trailing, top, bottom }

/// The whole app on an iPhone. Folded (or on any other iPhone) it is just Main. Unfolded, Fold joins Main on
/// the hinge line, where `arrangement` says. Main sits in slot 0 of the layout in every pose, so its view
/// state survives folds and turns.
///
/// Fixed: Main is locked to the physical panel that carries the vertical bar in the pose you get by unfolding
/// (landscapeLeft, Main on the right). iOS keeps the bar on the trailing edge in every pose, so the interface
/// orientation is the only thing that says where that panel went:
///
///     landscapeLeft → Main right · portraitUpsideDown → Main bottom · landscapeRight → Main left · portrait → Main top
///
/// (read off the simulator's native-frame video; see references/simulator.md).
@available(iOS 27.1, *)
struct DuoCanvas: View {
    @Binding var path: [Session]
    @State private var orientation = UIInterfaceOrientation.unknown
    @State private var rotating = false
    @State private var size = CGSize.zero
    /// Fold's share of the window along the join axis. 0.5 = the hinge.
    @AppStorage("foldFraction") private var fraction = 0.5
    @State private var dragStart: Double?

    /// The inner display is 951 pt on its long side in every orientation; the cover is 678 and never rotates
    /// (AppDelegate). The size class flickers to compact mid-rotation; the window size does not.
    private var unfolded: Bool { max(size.width, size.height) > 800 }

    /// The window's real insets (trailing = the bar), measured outside `ignoresSafeArea`.
    @State private var windowInsets = EdgeInsets()

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
            .onHingeChange { _, new in
                // Feeds the orientation rule (AppDelegate); re-ask at once so a fold never lands in landscape.
                HingeState.shared.open = new.hinge.map { $0.status != .closed } ?? false
                for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                    scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }
    }

    @ViewBuilder private var probe: some View {
        if arrangement == .fixed { RotationProbe(orientation: $orientation, rotating: $rotating) }
    }

    /// The hinge line; in the fixed arrangement draggable along the join axis, and the fraction is remembered.
    private func foldLine(_ side: FoldSide) -> some View {
        let horizontal = side == .leading || side == .trailing
        return Rectangle().fill(.primary.opacity(0.12))
            .frame(width: horizontal ? 1 : nil, height: horizontal ? nil : 1)
            .overlay {
                if arrangement == .fixed { dragHandle(side, horizontal: horizontal) }
            }
    }

    private func dragHandle(_ side: FoldSide, horizontal: Bool) -> some View {
        Color.clear.frame(width: horizontal ? 24 : nil, height: horizontal ? nil : 24).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { g in
                    let start = dragStart ?? fraction
                    dragStart = start
                    let delta = horizontal ? g.translation.width / size.width : g.translation.height / size.height
                    let sign: Double = (side == .leading || side == .top) ? 1 : -1
                    fraction = min(max(start + sign * delta, 0.25), 0.75)
                }
                .onEnded { _ in dragStart = nil })
            .accessibilityLabel("Resize pages")
    }
}

extension FoldSide {
    /// Where Fold touches Main: the edge of the Fold pane that faces Main.
    var joinAlignment: Alignment {
        switch self {
        case .leading: .trailing
        case .trailing: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }
}

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

/// Reports the interface orientation *before* the layout for it happens (`viewWillTransition(to:with:)`; by
/// then the scene already reports the orientation being turned to), so the arrangement changes in the same
/// frame as the window size. A post-layout reader lags by a frame and shows the old arrangement squeezed into
/// the new frame. `rotating` is true for the duration of the system's rotation animation.
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

// MARK: - Fold

/// The page that opens on the other panel. Here: the stats; a real app puts what the cover had no room for.
@available(iOS 27.1, *)
private struct FoldPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Stats").font(.largeTitle.bold()).padding(.horizontal, 20).padding(.top, 20)
            StatsPage()
        }
    }
}

// MARK: - Main

/// Folded, the whole app; unfolded, the Main pane. Home and the running stopwatch swap in place (no push), so
/// the bar keeps its identity; history entries are pushed. Controls live in the vertical bar on every page.
@available(iOS 27.1, *)
struct SingleScreen: View {
    @Binding var path: [Session]
    /// Width of the vertical bar on this view's trailing edge (0 = no bar there, so no slide).
    var barInset: CGFloat
    @Environment(Stopwatch.self) private var stopwatch
    @State private var startFrame = CGRect.zero
    @State private var slide: Slide?

    /// stage 0: where it starts; 1: slid along its own row into the bar's column, now a round stop button;
    /// 2: faded out while the bar's real stop button fades in. Stopping plays it backwards.
    private struct Slide { var toBar: Bool; var stage = 0 }

    var body: some View {
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
        .overlay { slideOverlay }
        .onChange(of: stopwatch.isActive) { _, active in run(toBar: active) }
    }

    // MARK: Vertical bar

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

    // MARK: Start → bar slide

    /// The start button slides straight right along its own row and narrows into the round stop button at the bar's
    /// column. The bar's column comes from the window's trailing safe-area inset (`barInset`): a toolbar item's
    /// own frame is in another coordinate space. Without a bar on this edge `barInset` is 0 and there is no slide.
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

/// Home: the history, then the start button at the bottom, under the thumb.
@available(iOS 27.1, *)
private struct HomePage: View {
    var hideStart: Bool
    let open: (Session) -> Void
    let reportStartFrame: (CGRect) -> Void
    @Environment(Stopwatch.self) private var stopwatch

    var body: some View {
        VStack(spacing: 0) {
            List(stopwatch.history) { s in
                Button { open(s) } label: { SessionRow(session: s) }.foregroundStyle(.primary)
            }
            .listStyle(.plain)
            Button { stopwatch.start() } label: {
                Text("Start").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Color(.systemBackground))
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .opacity(hideStart ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reportStartFrame($0) }
            .padding(20)
        }
    }
}
#endif
