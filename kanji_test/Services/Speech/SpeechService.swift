import AVFoundation
import Foundation
import Observation

/// Speaks card fronts with a single shared synthesizer.
///
/// Utterance replacement is engine-confirmed: a new `speak` stops the
/// current audio, but the replacement utterance is only enqueued once the
/// engine reports the previous one ended. `AVSpeechSynthesizer` applies
/// cancellations asynchronously and does not reliably drop utterances that
/// are queued but not yet started — enqueueing over them lets the previous
/// card's audio bleed into the next card. A short timeout covers the
/// synthesizer's occasional missing cancel callbacks.
@MainActor @Observable
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var delegate: SpeechDelegate?
    private var generation = 0
    private var isWarmedUp = false
    private(set) var isSpeaking = false
    private(set) var lastError: String?
    private(set) var lastRequestedText: String?
    var voiceIdentifier: String? {
        didSet { isWarmedUp = false }
    }
    var rate: Float?

    /// The utterance waiting to be enqueued for `generation`.
    private struct PendingUtterance {
        let text: String
        let volume: Float
        let generation: Int
    }
    private var pendingUtterance: PendingUtterance?
    /// Latest generation whose audio session activation succeeded.
    private var activatedGeneration: Int?
    /// Generation of the utterance currently handed to the engine.
    private var enqueuedGeneration: Int?
    private var flushTimeout: Task<Void, Never>?

    init() {
        let delegate = SpeechDelegate { [weak self] in self?.engineDidGoIdle() }
        self.delegate = delegate
        synthesizer.delegate = delegate
    }

    /// Preloads the speech engine and the chosen voice with an inaudible
    /// utterance, so the first audible card doesn't pay the cold-start cost.
    func warmUp() {
        guard !isWarmedUp, generation == 0 else { return }
        isWarmedUp = true
        speak("あ", volume: 0)
    }

    func speak(_ text: String) {
        lastRequestedText = text
        speak(text, volume: 1)
    }

    func stop() {
        let current = generation
        generation += 1
        pendingUtterance = nil
        flushTimeout?.cancel()
        if synthesizer.isSpeaking || isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        enqueuedGeneration = nil
        isSpeaking = false
        Task { await SpeechAudioSession.shared.deactivateNow(request: current) }
    }

    static func japaneseVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .sorted { lhs, rhs in
                lhs.quality != rhs.quality
                    ? lhs.quality.rawValue > rhs.quality.rawValue
                    : lhs.name < rhs.name
            }
    }

    // MARK: - Utterance replacement

    private func speak(_ text: String, volume: Float) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        generation += 1
        let current = generation
        isSpeaking = volume > 0
        lastError = nil
        pendingUtterance = PendingUtterance(text: text, volume: volume, generation: current)
        flushTimeout?.cancel()
        synthesizer.stopSpeaking(at: .immediate)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await SpeechAudioSession.shared.activate(request: current)
            } catch {
                guard self.generation == current else { return }
                self.lastError = "Не удалось настроить звук: \(error.localizedDescription)"
                self.pendingUtterance = nil
                self.isSpeaking = false
                return
            }

            guard self.generation == current else {
                await SpeechAudioSession.shared.deactivate(request: current)
                return
            }
            self.activatedGeneration = max(self.activatedGeneration ?? 0, current)
            self.flushPendingUtterance()
        }
    }

    /// Enqueues the pending utterance once it is safe: the session for its
    /// generation is active and the engine no longer holds a cancelled
    /// utterance. Retried from the engine-idle callback and the timeout.
    private func flushPendingUtterance() {
        guard let pending = pendingUtterance, pending.generation == generation else { return }
        guard activatedGeneration ?? 0 >= pending.generation else {
            scheduleFlushTimeout(for: pending.generation)
            return
        }
        guard !synthesizer.isSpeaking else {
            // The engine is still draining the cancelled utterance; its end
            // callback (or the timeout) will retry.
            scheduleFlushTimeout(for: pending.generation)
            return
        }
        pendingUtterance = nil
        flushTimeout?.cancel()

        let utterance = AVSpeechUtterance(string: pending.text)
        utterance.voice = resolvedVoice()
        utterance.rate = rate ?? AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = pending.volume
        enqueuedGeneration = pending.generation
        synthesizer.speak(utterance)
    }

    /// The engine finished or cancelled its utterance: the queue is empty,
    /// so the pending replacement can go in.
    private func engineDidGoIdle() {
        // A late end-callback for an already-replaced utterance arrives
        // while its successor is speaking — ignore it.
        guard !synthesizer.isSpeaking else { return }
        if let enqueued = enqueuedGeneration {
            Task { await SpeechAudioSession.shared.deactivate(request: enqueued) }
        }
        enqueuedGeneration = nil
        isSpeaking = false
        flushPendingUtterance()
    }

    /// The synthesizer sometimes never delivers the cancel callback; after
    /// the grace period force-stop the engine and flush anyway so the card
    /// is not left silent.
    private func scheduleFlushTimeout(for generation: Int) {
        flushTimeout?.cancel()
        flushTimeout = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            guard self.pendingUtterance?.generation == generation, generation == self.generation else { return }
            self.synthesizer.stopSpeaking(at: .immediate)
            self.enqueuedGeneration = nil
            self.flushPendingUtterance()
        }
    }

    // MARK: - Voices

    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let voiceIdentifier, !voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return voice
        }
        return Self.defaultJapaneseVoice
    }

    private static let defaultJapaneseVoice: AVSpeechSynthesisVoice? = japaneseVoice()

    private static func japaneseVoice() -> AVSpeechSynthesisVoice? {
        japaneseVoices().first ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }
}

/// Owns the shared audio session. `setActive` round-trips to the audio server
/// and can cost hundreds of milliseconds, so the session is kept active while
/// cards keep arriving and is released only after an idle period (or on
/// `stop()`), instead of churning deactivate/activate per utterance.
private actor SpeechAudioSession {
    static let shared = SpeechAudioSession()

    private static let idleDeactivationDelay: Duration = .seconds(30)

    private var isConfigured = false
    private var activeRequest: Int?
    private var pendingDeactivation: Task<Void, Never>?

    func activate(request: Int) throws {
        // A stale request must not steal session ownership from a newer one.
        guard request >= activeRequest ?? 0 else { return }
        cancelPendingDeactivation()
        let session = AVAudioSession.sharedInstance()
        if !isConfigured {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            isConfigured = true
        }
        if activeRequest == nil {
            try session.setActive(true)
        }
        activeRequest = request
    }

    /// Releases the session after the idle delay. A no-op if a newer request
    /// already took ownership.
    func deactivate(request: Int) {
        guard activeRequest == request else { return }
        cancelPendingDeactivation()
        pendingDeactivation = Task {
            try? await Task.sleep(for: Self.idleDeactivationDelay)
            guard !Task.isCancelled, activeRequest == request else { return }
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
            if activeRequest == request {
                activeRequest = nil
            }
        }
    }

    func deactivateNow(request: Int) {
        guard activeRequest == request else { return }
        cancelPendingDeactivation()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        activeRequest = nil
    }

    private func cancelPendingDeactivation() {
        pendingDeactivation?.cancel()
        pendingDeactivation = nil
    }
}

nonisolated private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onEnded: @MainActor () -> Void
    init(onEnded: @escaping @MainActor () -> Void) { self.onEnded = onEnded }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onEnded() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in onEnded() }
    }
}
