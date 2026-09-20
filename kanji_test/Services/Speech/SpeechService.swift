import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var delegate: SpeechDelegate?
    private var sessionConfigured = false
    private var generation = 0
    private(set) var isSpeaking = false
    private(set) var lastError: String?
    var voiceIdentifier: String?
    var rate: Float?

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !sessionConfigured {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                sessionConfigured = true
            } catch {
                lastError = "Не удалось настроить звук: \(error.localizedDescription)"
                return
            }
        }
        lastError = nil
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = resolvedVoice()
        utterance.rate = rate ?? AVSpeechUtteranceDefaultSpeechRate
        generation += 1
        let current = generation
        let completion = SpeechDelegate { [weak self] in
            guard let self, self.generation == current else { return }
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
        delegate = completion
        synthesizer.delegate = completion
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        generation += 1
        guard synthesizer.isSpeaking || isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
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
        return Self.japaneseVoice()
    }

    private static func japaneseVoice() -> AVSpeechSynthesisVoice? {
        japaneseVoices().first ?? AVSpeechSynthesisVoice(language: "ja-JP")
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
