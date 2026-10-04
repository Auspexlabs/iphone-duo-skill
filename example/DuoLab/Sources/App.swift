import SwiftUI
import UIKit

@main struct DuoLabApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    var body: some Scene {
        WindowGroup { if #available(iOS 27.1, *) { Probe() } else { Text("old OS") } }
    }
}

/// Variants, chosen by launch argument. Main is the page the folded cover shows; Left is the extra page.
///   -hstack   hand-written: HStack { if regular { Left }; Main }      (Main keeps its slot in both modes)
///   -split    ArrangementView(primary: Main, secondary: Left) .split.axes(.horizontal)
///   -rtl      same as -split, but the arrangement is laid out right-to-left so primary lands on the right
///   -overlay  ArrangementView .overlay, Left gets .overlayArrangementEdge(.leading)
///   -auto     ArrangementView .automatic
@available(iOS 27.1, *)
struct Probe: View {
    @Environment(\.toolbarVerticalEdge) private var edge
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var hinge = "—"
    private let variant = CommandLine.arguments.dropFirst().first ?? "-fold"   // tapping the icon opens the arrangements page

    var body: some View {
        Group {
            switch variant {
            case "-split":   arrangement.arrangementViewStyle(.split.axes(.horizontal))
            case "-rtl":     arrangement.arrangementViewStyle(.split.axes(.horizontal)).environment(\.layoutDirection, .rightToLeft)
            case "-overlay": arrangement.arrangementViewStyle(.overlay)
            case "-auto":    arrangement.arrangementViewStyle(.automatic)
            case "-fold":    FoldProbe()
            case let p where p.hasPrefix("-bar"): Gallery(page: p)
            default:         hstack
            }
        }
        .onHingeChange { _, new in hinge = new.hinge.map { "\($0.status) \(Int($0.angle.degrees))°" } ?? "nil" }
        .onChange(of: hsc) {
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    private var arrangement: some View {
        ArrangementView {
            main.environment(\.layoutDirection, .leftToRight)
        } secondary: {
            left.environment(\.layoutDirection, .leftToRight).overlayArrangementEdge(.leading)
        }
    }

    private var hstack: some View {
        HStack(spacing: 0) {
            if hsc == .regular { left.frame(width: 320) }
            main
        }
    }

    private var main: some View { MainPage(variant: variant, edge: edge, hsc: hsc, hinge: hinge) }

    private var left: some View {
        VStack(spacing: 12) {
            Text("LEFT").font(.largeTitle.bold())
            SplitAxisLabel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.15))
    }
}

@available(iOS 27.1, *)
struct MainPage: View {
    let variant: String
    let edge: HorizontalEdge?
    let hsc: UserInterfaceSizeClass?
    let hinge: String
    /// Set when this view's state is created. If it changes after a fold, the view was rebuilt.
    @State private var born = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("MAIN").font(.largeTitle.bold())
                Text(variant).font(.title3.monospaced())
                Text("born \(born.formatted(.dateTime.hour().minute().second()))").font(.title3.monospaced())
                Text("toolbarVerticalEdge=\(edge.map { "\($0)" } ?? "nil")")
                Text("hsc=\(hsc.map { "\($0)" } ?? "nil")")
                Text("hinge=\(hinge)")
                SplitAxisLabel()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.15))
            .navigationTitle("Main")
            .toolbar {
                ToolbarItem { Button { } label: { Label("Home", systemImage: "house") } }.axisBehavior(.verticalPreferred)
            }
        }
    }
}

@available(iOS 27.1, *)
struct SplitAxisLabel: View {
    @Environment(\.splitArrangementAxis) private var axis
    @Environment(\.overlayArrangementZIndex) private var z
    var body: some View { Text("splitAxis=\(axis.map { "\($0)" } ?? "nil") z=\(z)").font(.caption) }
}

/// What the hinge reports, for the orientation rule below. Updated from `onHingeChange` in `FoldProbe`.
final class HingeState {
    static let shared = HingeState()
    /// True while the device is unfolded (hinge not closed). False on non-folding iPhones.
    var open = false
}

/// Cover: portrait only by default. Inner display: all four ways. Two signals, both needed: the screen the
/// window is on (951 pt long = inner, 678 = cover) and the hinge. During a fold iOS asks while the window is
/// *still on the inner screen*, so the screen alone answers "all" and the cover lands in landscape, then turns
/// back; the hinge already reads `closed` at that moment.
///
/// "cover landscape" (toggle in FoldProbe) lets Main turn landscape on the cover. Known: the simulator then
/// shows one rotation at the end of every fold — it reports the cover in one landscape while the hinge swings
/// and the opposite one at 0°, and iOS never displays an orientation the device is not in, so it cannot be
/// pre-empted. Tried and dropped: predicting the settled landscape (iOS falls back to portrait instead) and
/// blanking the content mid-swing.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        let s = window?.screen.bounds.size ?? .zero
        let inner = max(s.width, s.height) > 800
        if inner && HingeState.shared.open { return .all }
        return UserDefaults.standard.bool(forKey: "coverLandscape") ? .allButUpsideDown : .portrait
    }
}
