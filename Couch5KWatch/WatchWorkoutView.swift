import Combine
import Foundation
import SwiftUI
import WatchKit

@MainActor
final class WatchIntervalEngine: ObservableObject {
    enum State {
        case ready
        case running
        case paused
        case completed
    }

    let session: TrainingSession

    @Published private(set) var state: State = .ready
    @Published private(set) var segmentIndex = 0
    @Published private(set) var remaining: TimeInterval

    private var startedAt: Date?
    private var remainingAtStart: TimeInterval

    init(session: TrainingSession) {
        self.session = session
        let firstDuration = session.segments.first?.duration ?? 0
        remaining = firstDuration
        remainingAtStart = firstDuration
    }

    var segment: WorkoutSegment? {
        guard session.segments.indices.contains(segmentIndex) else { return nil }
        return session.segments[segmentIndex]
    }

    var progress: Double {
        guard !session.segments.isEmpty else { return 1 }
        return min(Double(segmentIndex) / Double(session.segments.count), 1)
    }

    func start(at date: Date = .now) {
        guard state == .ready else { return }
        startedAt = date
        remainingAtStart = remaining
        state = .running
    }

    func pause(at date: Date = .now) {
        guard state == .running else { return }
        update(at: date)
        guard state == .running else { return }
        startedAt = nil
        remainingAtStart = remaining
        state = .paused
    }

    func resume(at date: Date = .now) {
        guard state == .paused else { return }
        startedAt = date
        remainingAtStart = remaining
        state = .running
    }

    func skip(at date: Date = .now) {
        guard state == .running || state == .paused else { return }
        advance(at: date)
    }

    func update(at date: Date = .now) {
        guard state == .running, let startedAt else { return }
        var elapsed = max(date.timeIntervalSince(startedAt), 0)

        while state == .running, elapsed >= remainingAtStart {
            elapsed -= remainingAtStart
            advance(at: date.addingTimeInterval(-elapsed))
        }

        guard state == .running else { return }
        remaining = max(remainingAtStart - elapsed, 0)
    }

    private func advance(at date: Date) {
        let wasPaused = state == .paused
        let next = segmentIndex + 1
        guard session.segments.indices.contains(next) else {
            state = .completed
            segmentIndex = session.segments.count
            remaining = 0
            startedAt = nil
            return
        }
        segmentIndex = next
        remaining = session.segments[next].duration
        remainingAtStart = remaining
        startedAt = wasPaused ? nil : date
    }
}

struct WatchWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: WatchIntervalEngine
    @StateObject private var workoutManager = WatchWorkoutManager()
    @State private var errorMessage: String?

    private let weekNumber: Int
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    init(weekNumber: Int, session: TrainingSession) {
        self.weekNumber = weekNumber
        _engine = StateObject(wrappedValue: WatchIntervalEngine(session: session))
    }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: engine.progress)
                .tint(.brandPink)

            Image(systemName: engine.segment?.kind.systemImage ?? "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.brandPink)

            Text(engine.segment?.kind.title ?? "完成")
                .font(.headline)

            Text(clockText(engine.remaining))
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .accessibilityLabel("剩余时间")
                .accessibilityValue(clockText(engine.remaining))

            if workoutManager.heartRate > 0 {
                Label(
                    "\(Int(workoutManager.heartRate)) 次/分",
                    systemImage: "heart.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }

            controls
        }
        .navigationTitle("第 \(weekNumber) 周")
        .onReceive(timer) { date in
            engine.update(at: date)
        }
        .onChange(of: engine.segmentIndex) { oldValue, newValue in
            guard oldValue != newValue else { return }
            WKInterfaceDevice.current().play(engine.state == .completed ? .success : .notification)
            if engine.state == .completed {
                workoutManager.finish()
            }
        }
        .alert(
            "无法开始训练",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var controls: some View {
        if engine.state == .ready {
            Button("开始") {
                Task {
                    do {
                        try await workoutManager.start()
                        engine.start()
                        WKInterfaceDevice.current().play(.start)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        } else if engine.state == .completed {
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        } else {
            HStack {
                Button {
                    engine.skip()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .accessibilityLabel("跳到下一段")

                Button {
                    if engine.state == .paused {
                        engine.resume()
                        workoutManager.resume()
                    } else {
                        engine.pause()
                        workoutManager.pause()
                    }
                } label: {
                    Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                }
                .tint(.brandPink)
                .accessibilityLabel(engine.state == .paused ? "继续" : "暂停")
            }
        }
    }

    private func clockText(_ duration: TimeInterval) -> String {
        let value = max(Int(duration.rounded(.up)), 0)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
