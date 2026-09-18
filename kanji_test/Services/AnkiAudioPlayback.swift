import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class AnkiAudioPlayback {
    private static weak var activePlayback: AnkiAudioPlayback?
    private static let engine = AnkiAudioEngine()
    @ObservationIgnored private var requestID: UUID?
    private(set) var isPlaying = false
    private(set) var error: String?

    func toggle(_ url: URL) {
        if requestID != nil { stop(); return }
        Self.activePlayback?.stop()
        Self.activePlayback = self
        let id = UUID()
        requestID = id
        error = nil
        Task { [weak self] in
            guard let self, requestID == id else { return }
            do {
                try await Self.engine.play(url, id: id) { message in
                    Task { @MainActor in
                        guard self.requestID == id else { return }
                        self.error = message
                        self.stop()
                    }
                }
                guard requestID == id else {
                    await Self.engine.stop(id: id)
                    return
                }
                isPlaying = true
            } catch {
                guard requestID == id else { return }
                self.error = error.localizedDescription
                stop()
            }
        }
    }

    func stop() {
        guard let id = requestID else { return }
        requestID = nil
        isPlaying = false
        if Self.activePlayback === self { Self.activePlayback = nil }
        Task { await Self.engine.stop(id: id) }
    }
}

/// All blocking audio operations run serially outside the main actor.
private actor AnkiAudioEngine {
    private var player: AVAudioPlayer?
    private var delegate: AudioCompletion?
    private var requestID: UUID?

    func play(_ url: URL, id: UUID, completion: @escaping @Sendable (String?) -> Void) throws {
        if let current = requestID { stop(id: current) }
        requestID = id
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let next = try AVAudioPlayer(contentsOf: url)
            let callback = AudioCompletion(completion: completion)
            delegate = callback
            player = next
            next.delegate = callback
            guard next.prepareToPlay(), next.play() else { throw URLError(.cannotDecodeContentData) }
        } catch {
            stop(id: id)
            throw error
        }
    }

    func stop(id: UUID) {
        guard requestID == id else { return }
        player?.delegate = nil
        player?.stop()
        player = nil
        delegate = nil
        requestID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

nonisolated private final class AudioCompletion: NSObject, AVAudioPlayerDelegate {
    let completion: @Sendable (String?) -> Void
    init(completion: @escaping @Sendable (String?) -> Void) { self.completion = completion }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion(flag ? nil : "Воспроизведение звука прервано.")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion(error?.localizedDescription ?? "Неподдерживаемый формат аудио.")
    }
}
