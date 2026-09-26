import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var delegate: SpeechDelegate?
    private var generation = 0
    private var isWarmedUp = false
    private(set) var isSpeaking = false
    private(set) var lastError: String?
    var voiceIdentifier: String? {
        didSet { isWarmedUp = false }
    }
    var rate: Float?

    /// Preloads the speech engine and the chosen voice with an inaudible
    /// utterance, so the first audible card doesn't pay the cold-start cost.
    func warmUp() {
        guard !isWarmedUp, generation == 0 else { return }
        isWarmedUp = true
        speak("あ", volume: 0)
    }

    func speak(_ text: String) {
        speak(text, volume: 1)
    }

    private func speak(_ text: String, volume: Float) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        generation += 1
        let current = generation
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                try await SpeechAudioSession.shared.activate(request: current)
            } catch {
                guard generation == current else { return }
                lastError = "Не удалось настроить звук: \(error.localizedDescription)"
                isSpeaking = false
                return
            }

            guard generation == current else {
                await SpeechAudioSession.shared.deactivate(request: current)
                return
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = resolvedVoice()
            utterance.rate = rate ?? AVSpeechUtteranceDefaultSpeechRate
            utterance.volume = volume
            let completion = SpeechDelegate { [weak self] in
                Task { await SpeechAudioSession.shared.deactivate(request: current) }
                guard let self, self.generation == current else { return }
                self.isSpeaking = false
            }
            delegate = completion
            synthesizer.delegate = completion
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        let current = generation
        generation += 1
        if synthesizer.isSpeaking || isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
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
    let onDone: @MainActor () -> Void
    init(onDone: @escaping @MainActor () -> Void) { self.onDone = onDone }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onDone() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in onDone() }
    }
}
