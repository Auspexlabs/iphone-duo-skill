import SwiftUI

/// Ordinary views, shared by every layout. Nothing here knows about the iPhone Duo.

struct SessionRow: View {
    let session: Session
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.total.clock).font(.headline).monospacedDigit()
            Text("\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(session.laps.count) laps")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SessionDetail: View {
    let session: Session
    var body: some View {
        List {
            Section { Text(session.total.clock).font(.system(size: 44, weight: .semibold)).monospacedDigit() }
            Section("Laps") {
                if session.laps.isEmpty { Text("No laps").foregroundStyle(.secondary) }
                ForEach(session.laps) { Text($0.time.clock).monospacedDigit() }
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
    }
}

/// The running stopwatch: the time and the laps. `showsControls` adds inline buttons for layouts without a bar.
struct StopwatchFace: View {
    var showsControls = false
    @Environment(Stopwatch.self) private var stopwatch

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                Text(stopwatch.elapsed(at: ctx.date).clock)
                    .font(.system(size: 56, weight: .semibold)).monospacedDigit()
            }
            .padding(.top, 40)
            if showsControls {
                HStack {
                    Button(stopwatch.isActive ? "Stop" : "Start") {
                        stopwatch.isActive ? stopwatch.stop() : stopwatch.start()
                    }
                    Button(stopwatch.phase == .paused ? "Resume" : "Pause") {
                        stopwatch.phase == .paused ? stopwatch.resume() : stopwatch.pause()
                    }
                    .disabled(!stopwatch.isActive)
                    Button("Lap") { stopwatch.lap() }.disabled(stopwatch.phase != .running)
                }
                .buttonStyle(.bordered)
            }
            List(stopwatch.laps.enumerated().map { $0 }, id: \.element.id) { i, lap in
                HStack {
                    Text("Lap \(stopwatch.laps.count - i)").foregroundStyle(.secondary)
                    Spacer()
                    Text(lap.time.clock).monospacedDigit()
                }
            }
            .listStyle(.plain)
        }
    }
}

/// Totals over the history: the dual-screen mode's left page.
struct StatsPage: View {
    @Environment(Stopwatch.self) private var stopwatch

    var body: some View {
        let totals = stopwatch.history.map(\.total)
        List {
            Section("This week") {
                LabeledContent("Sessions", value: "\(totals.count)")
                LabeledContent("Total", value: totals.reduce(0, +).clock)
                LabeledContent("Longest", value: (totals.max() ?? 0).clock)
            }
            Section("Recent") {
                ForEach(stopwatch.history) { s in
                    HStack {
                        Text(s.date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                        GeometryReader { g in
                            Capsule().fill(.tint)
                                .frame(width: g.size.width * s.total / max(totals.max() ?? 1, 1), height: 8)
                                .frame(maxHeight: .infinity)
                        }
                    }
                }
            }
        }
    }
}
