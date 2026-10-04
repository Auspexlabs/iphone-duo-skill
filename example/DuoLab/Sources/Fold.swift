import SwiftUI
import UIKit

enum FoldSide: String { case leading, trailing, top, bottom }

/// Places Main (subview 0) and Fold (subview 1, optional) so Main keeps its identity in every pose.
struct JoinLayout: Layout {
    var side: FoldSide?
    var fraction: CGFloat = 0.5   // share of the axis given to Fold

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let main = subviews[0]
        guard subviews.count > 1, let side else {
            main.place(at: b.origin, proposal: .init(b.size)); return
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
        main.place(at: m.origin, proposal: .init(m.size))
        subviews[1].place(at: f.origin, proposal: .init(f.size))
    }
}

/// Reports the interface orientation *before* the layout for it happens (`viewWillTransition(to:with:)`; by
/// then the scene already reports the orientation being turned to), so the arrangement changes in the same
/// frame as the window size. A post-layout reader lags by a frame.
struct OrientationProbe: UIViewControllerRepresentable {
    @Binding var orientation: UIInterfaceOrientation
    var log: (String) -> Void = { _ in }
    /// (old window size, new window size, rotation delta in degrees from the coordinator's targetTransform)
    var willTransition: (CGSize, CGSize, Int) -> Void = { _, _, _ in }
    var alongside: (TimeInterval) -> Void = { _ in }
    var completion: () -> Void = { }

    func makeUIViewController(context: Context) -> VC { VC() }
    func updateUIViewController(_ vc: VC, context: Context) {
        vc.report = { orientation = $0 }; vc.log = log
        vc.willTransition = willTransition; vc.alongside = alongside; vc.completion = completion
    }

    final class VC: UIViewController {
        var report: (UIInterfaceOrientation) -> Void = { _ in }
        var log: (String) -> Void = { _ in }
        var willTransition: (CGSize, CGSize, Int) -> Void = { _, _, _ in }
        var alongside: (TimeInterval) -> Void = { _ in }
        var completion: () -> Void = { }
        private var last: UIInterfaceOrientation?

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            guard let o = view.window?.windowScene?.effectiveGeometry.interfaceOrientation, o != .unknown, o != last else { return }
            last = o; report(o); log("layout scene=\(o.name)")
        }

        override func viewWillTransition(to size: CGSize, with c: any UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: c)
            let t = c.targetTransform
            let deg = Int((atan2(t.b, t.a) * 180 / .pi).rounded())
            let old = view.window?.bounds.size ?? size
            let cur = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
            let scr = view.window?.screen.bounds.size ?? .zero
            log("willTransition \(Int(old.width))x\(Int(old.height))->\(Int(size.width))x\(Int(size.height)) delta=\(deg) scene=\(cur.name) screen=\(Int(scr.width))x\(Int(scr.height)) dur=\(c.transitionDuration)")
            willTransition(old, size, deg)
            if cur != .unknown, cur != last { last = cur; report(cur) }
            c.animate(alongsideTransition: { _ in self.alongside(c.transitionDuration) }, completion: { _ in self.completion() })
        }
    }
}

extension UIInterfaceOrientation {
    var name: String {
        switch self {
        case .portrait: "portrait"; case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"; case .landscapeRight: "landscapeRight"
        default: "unknown"
        }
    }
}

/// The three arrangements the skill offers. Switch at the top of Main.
enum Arrangement: Int, CaseIterable, Identifiable {
    case fixed = 0, whole = 1, mix = 2
    var id: Int { rawValue }
    var label: String {
        switch self { case .fixed: "固定式"; case .whole: "整屏式"; case .mix: "混合式" }
    }
}

@available(iOS 27.1, *)
struct FoldProbe: View {
    @Environment(\.toolbarVerticalEdge) private var barEdge
    @Environment(\.horizontalSizeClass) private var hsc
    @AppStorage("arrangement") private var arrangementRaw = 0
    /// Whether Main may turn landscape on the cover (read by AppDelegate's orientation rule).
    @AppStorage("coverLandscape") private var coverLandscape = false
    @State private var orientation = UIInterfaceOrientation.unknown
    @State private var size = CGSize.zero
    @State private var born = Date()
    @State private var hinge = "—"
    @State private var rotating = false

    private var arrangement: Arrangement { Arrangement(rawValue: arrangementRaw) ?? .fixed }

    /// Unfolded = the inner display. Its long side is 951 pt in every orientation; the cover's is 678.
    private var unfolded: Bool { max(size.width, size.height) > 800 }
    private var landscape: Bool { size.width > size.height }

    /// 固定式: Main keeps its physical panel (the half carrying the bar at unfold). Only the interface
    /// orientation says where that panel went.
    private var fixedSide: FoldSide? {
        guard unfolded else { return nil }
        switch orientation {
        case .landscapeLeft: return .leading
        case .landscapeRight: return .trailing
        case .portrait: return .bottom
        case .portraitUpsideDown: return .top
        default: return .leading
        }
    }

    /// 混合式: Main and Fold form one iPad-like picture in every orientation — Fold is a sidebar on the leading
    /// side, joined to Main; half the width when wide (the hinge), 40 % when tall. Rotates with the system as a
    /// whole, like an iPad app. Folded: Main alone.
    private var mixSide: FoldSide? { unfolded ? .leading : nil }
    private var mixFraction: CGFloat { landscape ? 0.5 : 0.4 }

    private var line: String {
        "arr=\(arrangement.label) hinge=\(hinge) orient=\(orientation.name) bar=\(barEdge.map { "\($0)" } ?? "nil") hsc=\(hsc.map { "\($0)" } ?? "nil") size=\(Int(size.width))x\(Int(size.height)) unfolded=\(unfolded)"
    }

    var body: some View {
        Group {
            switch arrangement {
            case .fixed:
                JoinLayout(side: fixedSide) {
                    mainPane(info: "fold side: \(fixedSide?.rawValue ?? "none")")
                    if let s = fixedSide { foldPane("joins from \(s.rawValue)") }
                }
                // The panes never move on the glass: the rotation must not animate their frames.
                .transaction { if rotating { $0.animation = nil } }
            case .mix:
                JoinLayout(side: mixSide, fraction: mixFraction) {
                    mainPane(info: unfolded ? "joined with Fold on the left" : "folded: Main")
                    if unfolded { foldPane("sidebar · \(Int(mixFraction * 100))%").overlay(alignment: .trailing) { Divider() } }
                }
            case .whole:
                if unfolded { wholeCanvas } else { mainPane(info: "folded: Main") }
            }
        }
        .ignoresSafeArea()   // bounds = whole window, so a 0.5 split lands on the hinge
        .background {
            OrientationProbe(orientation: $orientation, log: log,
                             willTransition: { _, _, _ in rotating = true },
                             completion: { rotating = false })
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onChange(of: hsc) {
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        .onHingeChange { _, new in
            hinge = new.hinge.map { "\($0.status) \(Int($0.angle.degrees))°" } ?? "nil"
            // Feeds the orientation rule (AppDelegate); re-ask at once so a fold never lands in landscape.
            HingeState.shared.open = new.hinge.map { $0.status != .closed } ?? false
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        .onChange(of: line) { _, l in log(l) }
        .onAppear { log(line) }
    }

    private var picker: some View {
        VStack(spacing: 6) {
            Picker("Arrangement", selection: $arrangementRaw) {
                ForEach(Arrangement.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            Toggle("封面横屏 cover landscape", isOn: $coverLandscape).font(.caption)
                .onChange(of: coverLandscape) {
                    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                    }
                }
        }
        .padding(.horizontal, 24)
    }

    private func mainPane(info: String) -> some View {
        NavigationStack {
            VStack(spacing: 8) {
                picker
                Text("MAIN").font(.largeTitle.bold())
                Text("born \(born.formatted(.dateTime.hour().minute().second()))").font(.title3.monospaced())
                Text("orient=\(orientation.name)")
                Text("bar=\(barEdge.map { "\($0)" } ?? "nil")  hsc=\(hsc.map { "\($0)" } ?? "nil")")
                Text("window \(Int(size.width))×\(Int(size.height))")
                Text("hinge=\(hinge)")
                Text(info).font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.15))
            .navigationTitle("Main")
            .toolbar {
                ToolbarItem { Button { } label: { Label("Home", systemImage: "house") } }.axisBehavior(.verticalPreferred)
            }
        }
    }

    private func foldPane(_ info: String) -> some View {
        VStack {
            Text("FOLD").font(.largeTitle.bold())
            Text(info)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.2))
    }

    /// 整屏式: one canvas, two designs — a wide one and a tall one. No Main/Fold.
    private var wholeCanvas: some View {
        NavigationStack {
            VStack(spacing: 12) {
                picker
                Text(landscape ? "整屏 · 横屏界面" : "整屏 · 竖屏界面").font(.largeTitle.bold())
                if landscape {
                    HStack(spacing: 12) {
                        box("列表", .green); box("内容", .green); box("详情", .green)
                    }
                } else {
                    VStack(spacing: 12) {
                        box("内容", .green)
                        HStack(spacing: 12) { box("列表", .green); box("详情", .green) }
                    }
                }
                Text("orient=\(orientation.name)  window \(Int(size.width))×\(Int(size.height))").font(.caption)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.12))
            .navigationTitle("Whole")
            .toolbar {
                ToolbarItem { Button { } label: { Label("Home", systemImage: "house") } }.axisBehavior(.verticalPreferred)
            }
        }
    }

    private func box(_ title: String, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.25))
            .overlay(Text(title).font(.title2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func log(_ l: String) {
        let url = URL.documentsDirectory.appending(path: "log.txt")
        let data = ("\(Date().formatted(.dateTime.hour().minute().second())) " + l + "\n").data(using: .utf8)!
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); try? h.close() }
        else { try? data.write(to: url) }
    }
}
