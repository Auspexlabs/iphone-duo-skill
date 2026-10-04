import Foundation
import Observation

struct Lap: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
}

struct Session: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let total: TimeInterval
    let laps: [Lap]
}

/// The whole app's state. Both iPhone Duo modes read this one object, so folding never loses anything.
@MainActor @Observable
final class Stopwatch {
    enum Phase { case idle, running, paused }

    var phase = Phase.idle
    var laps: [Lap] = []
    var history: [Session] = Stopwatch.sample
    private var runningSince: Date?
    private var banked: TimeInterval = 0

    var isActive: Bool { phase != .idle }

    func elapsed(at now: Date = .now) -> TimeInterval {
        banked + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    func start() {
        guard phase == .idle else { return }
        laps = []; banked = 0; runningSince = .now; phase = .running
    }

    func pause() {
        guard phase == .running else { return }
        banked = elapsed(); runningSince = nil; phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        runningSince = .now; phase = .running
    }

    func lap() {
        guard phase == .running else { return }
        laps.insert(Lap(time: elapsed()), at: 0)
    }

    func stop() {
        guard isActive else { return }
        history.insert(Session(date: .now, total: elapsed(), laps: laps), at: 0)
        laps = []; banked = 0; runningSince = nil; phase = .idle
    }

    static let sample: [Session] = [
        Session(date: .now.addingTimeInterval(-3_600), total: 1_512, laps: [Lap(time: 1_512), Lap(time: 1_004), Lap(time: 498)]),
        Session(date: .now.addingTimeInterval(-90_000), total: 1_845, laps: [Lap(time: 1_845), Lap(time: 917)]),
        Session(date: .now.addingTimeInterval(-260_000), total: 1_330, laps: []),
    ]
}

extension TimeInterval {
    /// 25:12.4
    var clock: String {
        let t = max(0, self)
        return String(format: "%02d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }
}
