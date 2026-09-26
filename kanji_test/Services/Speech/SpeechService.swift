import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var delegate: SpeechDelegate?
    private var generation = 0
    private(set) var isSpeaking = false
    private(set) var lastError: String?
    var voiceIdentifier: String?
    var rate: Float?

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let previousGeneration = generation
        generation += 1
        let current = generation
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = true
        lastError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                if previousGeneration > 0 {
                    await SpeechAudioSession.shared.deactivate(request: previousGeneration)
                }
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
        Task { await SpeechAudioSession.shared.deactivate(request: current) }
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

private actor SpeechAudioSession {
    static let shared = SpeechAudioSession()

    private var isConfigured = false
    private var activeRequest: Int?

    func activate(request: Int) throws {
        let session = AVAudioSession.sharedInstance()
        if !isConfigured {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            isConfigured = true
        }
        try session.setActive(true)
        activeRequest = request
    }

    func deactivate(request: Int) {
        guard activeRequest == request else { return }
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
        if activeRequest == request {
            activeRequest = nil
        }
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
