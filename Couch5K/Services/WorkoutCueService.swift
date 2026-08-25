@preconcurrency import AVFoundation
import UIKit
@preconcurrency import UserNotifications

@MainActor
final class WorkoutCueService: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let notificationPrefix = "active-workout-"
    private var activeUtterance: AVSpeechUtterance?
    private var encouragementIndex = 0
    private var finishLineEncouragementIndex = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    func prepareAudio() {
        configureAudioSession()
    }

    func stopAudio() {
        let utterance = activeUtterance
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        if utterance != nil {
            deactivateAudioSession()
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .duckOthers]
            )
        } catch {
            assertionFailure("Unable to prepare workout audio: \(error)")
        }
    }

    func announce(_ segment: WorkoutSegment, enabled: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard enabled else { return }

        speak(announcement(for: segment))
    }

    func announceCompletion(enabled: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard enabled else { return }

        speak(L10n.completionCue)
    }

    @discardableResult
    func encourage(enabled: Bool) -> String? {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard enabled, !synthesizer.isSpeaking else { return nil }

        let messages = L10n.encouragements
        let message = messages[encouragementIndex % messages.count]
        encouragementIndex += 1
        speak(message)
        return message
    }

    @discardableResult
    func encourageNearEnd(enabled: Bool) -> String? {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard enabled else { return nil }

        let messages = L10n.finishLineEncouragements
        let message = messages[finishLineEncouragementIndex % messages.count]
        finishLineEncouragementIndex += 1
        speak(message)
        return message
    }

    private func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configureAudioSession()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            assertionFailure("Unable to activate workout audio: \(error)")
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice()
        utterance.rate = 0.49
        utterance.pitchMultiplier = utterance.voice?.gender == .male ? 1.06 : 1
        utterance.volume = 0.95
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        let language = isChinese ? "zh" : "en"
        let matchingVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language)
                && ($0.quality == .enhanced || $0.quality == .premium)
        }
        let preferredNames = language == "zh"
            ? ["Tingting", "Sinji", "Meijia"]
            : ["Alex", "Evan", "Daniel", "Aaron", "Tom", "Arthur"]

        return matchingVoices.max { lhs, rhs in
            voiceScore(lhs, preferredNames: preferredNames)
                < voiceScore(rhs, preferredNames: preferredNames)
        } ?? AVSpeechSynthesisVoice(language: language == "zh" ? "zh-CN" : "en-US")
    }

    private func voiceScore(
        _ voice: AVSpeechSynthesisVoice,
        preferredNames: [String]
    ) -> Int {
        let localeScore = voice.language == "en-US" ? 300 : 0
        let qualityScore = voice.quality.rawValue * 100
        let nameScore = preferredNames.firstIndex(of: voice.name)
            .map { preferredNames.count - $0 }
            ?? 0
        return localeScore + qualityScore + nameScore
    }

    private var isChinese: Bool {
        UserDefaults.standard.string(forKey: "coachLanguage") == "zh"
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        finishSpeaking(utterance)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        finishSpeaking(utterance)
    }

    private func finishSpeaking(_ utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        activeUtterance = nil
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            assertionFailure("Unable to release workout audio: \(error)")
        }
    }

    func requestNotificationAccess() async {
        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
        } catch {
            assertionFailure("Unable to request notification access: \(error)")
        }
    }

    func scheduleTransitions(
        segments: ArraySlice<WorkoutSegment>,
        currentRemaining: TimeInterval
    ) {
        cancelScheduledTransitions()

        let remainingSegments = Array(segments)
        guard !remainingSegments.isEmpty else { return }

        var delay = currentRemaining
        for (offset, segment) in remainingSegments.dropFirst().enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Couch 5K"
            content.body = announcement(for: segment)
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(delay, 1),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(notificationPrefix)\(offset)",
                content: content,
                trigger: trigger
            )
            notificationCenter.add(request) { error in
                if let error {
                    assertionFailure("Unable to schedule workout cue: \(error)")
                }
            }
            delay += segment.duration
        }

        let completionContent = UNMutableNotificationContent()
        completionContent.title = L10n.workoutComplete
        completionContent.body = L10n.completionNotificationBody
        completionContent.sound = .default
        let completionRequest = UNNotificationRequest(
            identifier: "\(notificationPrefix)complete",
            content: completionContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        )
        notificationCenter.add(completionRequest)
    }

    func cancelScheduledTransitions() {
        notificationCenter.getPendingNotificationRequests { [notificationCenter, notificationPrefix] requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(notificationPrefix) }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private func announcement(for segment: WorkoutSegment) -> String {
        L10n.cueAnnouncement(segment.kind)
    }
}
