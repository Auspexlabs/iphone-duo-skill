import SwiftUI
import UIKit

@main
struct DuoStopwatchApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var stopwatch = Stopwatch()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(stopwatch)
                #if DEBUG
                // `-demoRunning`: start the stopwatch two seconds after launch, to watch the slide into the bar.
                .task {
                    guard CommandLine.arguments.contains("-demoRunning") else { return }
                    try? await Task.sleep(for: .seconds(2))
                    stopwatch.start()
                }
                #endif
        }
    }
}

/// What the hinge reports, for the orientation rule below. Updated from `onHingeChange` in `DuoCanvas`.
final class HingeState {
    static let shared = HingeState()
    /// True while the device is unfolded (hinge not closed). False on non-folding iPhones.
    var open = false
}

/// Cover: portrait only, so folding never rotates the window. Inner display: all four ways. Other iPhones:
/// portrait. Two signals, both needed: the screen the window is on (951 pt long = inner, 678 = cover) and the
/// hinge. During a fold iOS asks while the window is *still on the inner screen*, so the screen alone answers
/// "all" and the cover lands in landscape, then turns back; the hinge already reads `closed` at that moment.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        let s = window?.screen.bounds.size ?? .zero
        let inner = max(s.width, s.height) > 800
        if inner && HingeState.shared.open { return .all }
        // The cover. An app that allows landscape here answers consistently before and after the fold, so the
        // cover lands in the device's orientation once; a portrait-only cover must say so the moment the hinge
        // closes (above) or it lands in landscape first and turns back.
        return coverSupportsLandscape ? .allButUpsideDown : .portrait
    }
}

/// Set to true for an app whose phone UI (Main) works in landscape, e.g. video or games. Known: the simulator
/// then shows one rotation at the end of every fold (it reports the cover in one landscape while the hinge
/// swings and the opposite one at 0°); iOS never displays an orientation the device is not in, so this cannot
/// be pre-empted by the app.
let coverSupportsLandscape = false

/// Picks the layout: the Duo canvas on iOS 27.1+ phones (on a non-folding iPhone it is just Main), the plain
/// split view elsewhere.
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

/// Everything else: a plain split view (collapses to a stack on a narrow screen).
struct ClassicView: View {
    @Environment(Stopwatch.self) private var stopwatch
    @State private var selected: Session?

    var body: some View {
        NavigationSplitView {
            List(stopwatch.history, selection: $selected) { s in
                NavigationLink(value: s) { SessionRow(session: s) }
            }
            .navigationTitle("History")
        } detail: {
            if let selected { SessionDetail(session: selected) } else { StopwatchFace(showsControls: true) }
        }
    }
}
