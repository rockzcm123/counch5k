import SwiftUI

enum WorkoutEncouragementPolicy {
    static func finishLineThreshold(for duration: TimeInterval) -> TimeInterval {
        min(duration * 0.2, 90)
    }

    static func shouldOfferMidpoint(
        kind: SegmentKind,
        duration: TimeInterval,
        remaining: TimeInterval
    ) -> Bool {
        kind == .run
            && duration >= 3 * 60
            && remaining <= duration / 2
            && remaining > finishLineThreshold(for: duration)
    }

    static func shouldOfferFinishLine(
        kind: SegmentKind,
        duration: TimeInterval,
        remaining: TimeInterval
    ) -> Bool {
        kind == .run && remaining <= finishLineThreshold(for: duration)
    }
}

struct WorkoutPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("voicePromptsEnabled") private var voicePromptsEnabled = true
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 72

    @StateObject private var engine: WorkoutEngine
    @StateObject private var locationService: WorkoutLocationService
    @State private var cueService = WorkoutCueService()
    @State private var isConfirmingEnd = false
    @State private var isShowingCompletion = false
    @State private var didFinishWorkout = false
    @State private var encouragedSegmentIDs: Set<UUID> = []
    @State private var finishLineEncouragedSegmentIDs: Set<UUID> = []
    @State private var encouragementMessage: String?
    @State private var encouragementDismissTask: Task<Void, Never>?

    private let weekNumber: Int
    private let activeStore: ActiveWorkoutStore
    private let onComplete: (WorkoutResult) -> Void
    private let workoutIdentifier: String?
    private let workoutName: String?
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    init(
        weekNumber: Int,
        session: TrainingSession,
        snapshot: ActiveWorkoutSnapshot? = nil,
        activeStore: ActiveWorkoutStore,
        workoutIdentifier: String? = nil,
        workoutName: String? = nil,
        onComplete: @escaping (WorkoutResult) -> Void
    ) {
        self.weekNumber = weekNumber
        self.activeStore = activeStore
        self.onComplete = onComplete
        self.workoutIdentifier = workoutIdentifier
        self.workoutName = workoutName
        if let snapshot {
            _engine = StateObject(
                wrappedValue: WorkoutEngine(session: session, snapshot: snapshot)
            )
            _locationService = StateObject(
                wrappedValue: WorkoutLocationService(
                    distanceMeters: snapshot.distanceMeters,
                    route: snapshot.route
                )
            )
        } else {
            _engine = StateObject(wrappedValue: WorkoutEngine(session: session))
            _locationService = StateObject(wrappedValue: WorkoutLocationService())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 28) {
                    progressHeader
                    segmentDisplay
                    metricsCard
                    nextSegmentCard
                    controls
                }
                .padding(24)
            }
            .navigationTitle(
                workoutName ?? L10n.plannedWorkoutTitle(
                    week: weekNumber,
                    day: engine.session.day
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.end) {
                        isConfirmingEnd = true
                    }
                }
            }
            .interactiveDismissDisabled(engine.state == .running || engine.state == .paused)
            .confirmationDialog(L10n.confirmEndWorkout, isPresented: $isConfirmingEnd) {
                Button(L10n.endWorkout, role: .destructive) {
                    cueService.cancelScheduledTransitions()
                    cueService.stopAudio()
                    _ = locationService.stop()
                    activeStore.clear()
                    dismiss()
                }
                Button(L10n.resumeWorkout, role: .cancel) {}
            }
            .alert(L10n.workoutComplete, isPresented: $isShowingCompletion) {
                Button(L10n.done) {
                    dismiss()
                }
            } message: {
                Text(L10n.workoutCompleteMessage)
            }
            .overlay(alignment: .top) {
                if let encouragementMessage {
                    encouragementToast(encouragementMessage)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            cueService.prepareAudio()
            if engine.state == .completed {
                finishWorkout()
            } else if engine.state == .running {
                locationService.start()
                rescheduleNotifications()
            }
        }
        .onDisappear {
            encouragementDismissTask?.cancel()
            cueService.stopAudio()
        }
        .onReceive(timer) { date in
            engine.update(at: date)
            offerFinishLineEncouragement()
            offerMidpointEncouragement()
        }
        .onChange(of: engine.segmentIndex) { oldValue, newValue in
            guard newValue != oldValue else { return }
            if engine.state == .completed {
                finishWorkout()
            } else if let segment = engine.currentSegment {
                persistWorkout()
                cueService.announce(segment, enabled: voicePromptsEnabled)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.update()
            } else {
                persistWorkout()
            }
        }
        .alert(
            L10n.locationNotice,
            isPresented: Binding(
                get: { locationService.errorMessage != nil },
                set: { if !$0 { locationService.resetError() } }
            )
        ) {
            Button(L10n.gotIt) {
                locationService.resetError()
            }
        } message: {
            Text(locationService.errorMessage ?? "")
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                color(for: engine.currentSegment?.kind).opacity(0.28),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut, value: engine.currentSegment?.kind)
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L10n.totalProgress)
                Spacer()
                Text("\(Int(engine.progress * 100))%")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))

            ProgressView(value: engine.progress)
                .tint(color(for: engine.currentSegment?.kind))

            HStack {
                Text(
                    L10n.segmentProgress(
                        current: min(engine.segmentIndex + 1, engine.session.segments.count),
                        total: engine.session.segments.count
                    )
                )
                Spacer()
                Text(L10n.remaining(clockText(engine.totalRemaining)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var segmentDisplay: some View {
        VStack(spacing: 18) {
            Image(systemName: engine.currentSegment?.kind.systemImage ?? "checkmark.circle.fill")
                .font(.system(size: 78))
                .foregroundStyle(color(for: engine.currentSegment?.kind))
                .symbolRenderingMode(.hierarchical)

            Text(engine.currentSegment?.kind.title ?? L10n.completed)
                .font(.title.bold())

            Text(clockText(engine.segmentRemaining))
                .font(.system(size: timerFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .contentTransition(reduceMotion ? .identity : .numericText())

            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(engine.currentSegment?.kind.title ?? L10n.workoutComplete)
        .accessibilityValue(
            L10n.remainingAccessibility(
                clockText(engine.segmentRemaining),
                status: statusText
            )
        )
    }

    private var nextSegmentCard: some View {
        HStack(spacing: 12) {
            Image(systemName: engine.nextSegment?.kind.systemImage ?? "flag.checkered")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.next)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(nextSegmentText)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var metricsCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                metric(
                    title: L10n.distance,
                    value: distanceText(locationService.distanceMeters),
                    icon: "location.fill"
                )

                Divider()
                    .frame(height: 34)

                metric(
                    title: L10n.averagePace,
                    value: paceText,
                    icon: "speedometer"
                )
            }

            VStack {
                metric(
                    title: L10n.distance,
                    value: distanceText(locationService.distanceMeters),
                    icon: "location.fill"
                )
                metric(
                    title: L10n.averagePace,
                    value: paceText,
                    icon: "speedometer"
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandPink)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            if engine.state == .ready {
                Button(action: start) {
                    Label(L10n.startWorkout, systemImage: "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            } else {
                Button {
                    engine.skip()
                    rescheduleNotifications()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(engine.state == .completed)
                .accessibilityLabel(L10n.skipSegment)

                Button(action: togglePause) {
                    Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(width: 74, height: 74)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(engine.state == .completed)
                .accessibilityLabel(engine.state == .paused ? L10n.resume : L10n.pause)

                Button(action: requestEncouragement) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.brandPink)
                .disabled(engine.state == .completed)
                .accessibilityLabel(L10n.encourageMe)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusText: String {
        switch engine.state {
        case .ready: L10n.readyStatus
        case .running: L10n.runningStatus
        case .paused: L10n.pausedStatus
        case .completed: L10n.workoutComplete
        }
    }

    private var nextSegmentText: String {
        guard let next = engine.nextSegment else { return L10n.finishWorkout }
        return "\(next.kind.title) · \(next.duration.workoutDurationText)"
    }

    private func start() {
        locationService.reset()
        locationService.start()
        engine.start()
        persistWorkout()
        if let segment = engine.currentSegment {
            cueService.announce(segment, enabled: voicePromptsEnabled)
        }
        Task {
            await cueService.requestNotificationAccess()
            rescheduleNotifications()
        }
    }

    private func togglePause() {
        if engine.state == .paused {
            engine.resume()
            locationService.start()
            persistWorkout()
            rescheduleNotifications()
        } else {
            engine.pause()
            _ = locationService.stop()
            persistWorkout()
            cueService.cancelScheduledTransitions()
        }
    }

    private func offerMidpointEncouragement() {
        guard voicePromptsEnabled,
              engine.state == .running,
              let segment = engine.currentSegment,
              WorkoutEncouragementPolicy.shouldOfferMidpoint(
                  kind: segment.kind,
                  duration: segment.duration,
                  remaining: engine.segmentRemaining
              ),
              encouragedSegmentIDs.insert(segment.id).inserted else {
            return
        }
        showEncouragement(cueService.encourage(enabled: true))
    }

    private func offerFinishLineEncouragement() {
        guard voicePromptsEnabled,
              engine.state == .running,
              let segment = engine.currentSegment,
              WorkoutEncouragementPolicy.shouldOfferFinishLine(
                  kind: segment.kind,
                  duration: segment.duration,
                  remaining: engine.segmentRemaining
              ),
              finishLineEncouragedSegmentIDs.insert(segment.id).inserted else {
            return
        }
        showEncouragement(cueService.encourageNearEnd(enabled: true))
    }

    private func requestEncouragement() {
        showEncouragement(cueService.encourage(enabled: voicePromptsEnabled))
    }

    private func showEncouragement(_ message: String?) {
        guard let message else { return }
        encouragementDismissTask?.cancel()
        withAnimation(.easeInOut) {
            encouragementMessage = message
        }
        encouragementDismissTask = Task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut) {
                    encouragementMessage = nil
                }
            }
        }
    }

    private func encouragementToast(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.subheadline.weight(.medium))
        } icon: {
            Image(systemName: "heart.fill")
                .foregroundStyle(Color.brandPink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }

    private func rescheduleNotifications() {
        guard engine.state == .running else { return }
        cueService.scheduleTransitions(
            segments: engine.session.segments.dropFirst(engine.segmentIndex),
            currentRemaining: engine.segmentRemaining
        )
    }

    private func persistWorkout() {
        if let snapshot = engine.snapshot(
            weekNumber: weekNumber,
            distanceMeters: locationService.distanceMeters,
            route: locationService.route,
            workoutIdentifier: workoutIdentifier,
            workoutName: workoutName
        ) {
            activeStore.save(snapshot)
        } else if engine.state == .completed {
            activeStore.clear()
        }
    }

    private func finishWorkout() {
        guard !didFinishWorkout else { return }
        didFinishWorkout = true
        cueService.cancelScheduledTransitions()
        activeStore.clear()
        let locationResult = locationService.stop()
        onComplete(
            WorkoutResult(
                startedAt: engine.workoutStartedAt ?? .now,
                completedAt: .now,
                distanceMeters: locationResult.distanceMeters,
                route: locationResult.route
            )
        )
        cueService.announceCompletion(enabled: voicePromptsEnabled)
        isShowingCompletion = true
    }

    private func clockText(_ duration: TimeInterval) -> String {
        let rounded = max(Int(duration.rounded(.up)), 0)
        return String(format: "%02d:%02d", rounded / 60, rounded % 60)
    }

    private var paceText: String {
        let distance = locationService.distanceMeters
        guard distance >= 20 else { return "--:--" }
        let elapsed = max(engine.session.totalDuration - engine.totalRemaining, 0)
        let unitDistance = unitSystem == "imperial" ? distance / 1_609.344 : distance / 1_000
        let secondsPerUnit = elapsed / unitDistance
        let unit = unitSystem == "imperial" ? L10n.mileAbbreviation : L10n.kilometerAbbreviation
        return "\(clockText(secondsPerUnit)) /\(unit)"
    }

    private func distanceText(_ meters: Double) -> String {
        if unitSystem == "imperial" {
            return String(format: "%.2f %@", meters / 1_609.344, L10n.mileAbbreviation)
        }
        return String(format: "%.2f %@", meters / 1_000, L10n.kilometerAbbreviation)
    }

    private func color(for kind: SegmentKind?) -> Color {
        switch kind {
        case .run: .brandPink
        case .warmup, .walk: .blue
        case .cooldown: .mint
        case nil: .green
        }
    }
}

#Preview {
    WorkoutPlayerView(
        weekNumber: 1,
        session: TrainingPlan.standard.weeks[0].sessions[0],
        activeStore: ActiveWorkoutStore(),
        onComplete: { _ in }
    )
}
