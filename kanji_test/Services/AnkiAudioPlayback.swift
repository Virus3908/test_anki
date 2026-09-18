import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class AnkiAudioPlayback: NSObject, AVAudioPlayerDelegate {
    // One active clip, even when a card contains several audio buttons.
    private static weak var activePlayback: AnkiAudioPlayback?
    private static let sessionQueue = DispatchQueue(label: "com.kanji-test.audio-session", qos: .userInitiated)
    @ObservationIgnored private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    private(set) var error: String?

    func toggle(_ url: URL) {
        if player != nil { stop(); return }
        Self.activePlayback?.stop()
        error = nil
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            Self.activePlayback = self
            player = next
            next.delegate = self

            // Audio-session activation can block while the system selects a
            // route, so never perform it synchronously on the main actor.
            Task { @MainActor [weak self, weak next] in
                guard let self, let next, self.player === next else { return }
                do {
                    try await Self.activateSession()
                    guard self.player === next else { return }
                    guard next.prepareToPlay(), next.play() else {
                        self.error = "Не удалось воспроизвести звук: \(url.lastPathComponent)"
                        self.stop()
                        return
                    }
                    self.isPlaying = true
                } catch {
                    guard self.player === next else { return }
                    self.error = "Не удалось воспроизвести \(url.lastPathComponent): \(error.localizedDescription)"
                    self.stop()
                }
            }
        } catch {
            self.error = "Не удалось воспроизвести \(url.lastPathComponent): \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        player?.delegate = nil
        player?.stop()
        player = nil
        isPlaying = false
        if Self.activePlayback === self {
            Self.activePlayback = nil
            Self.deactivateSession()
        }
    }

    private static func activateSession() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    // The playback category ignores the Ring/Silent switch.
                    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func deactivateSession() {
        sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let identity = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == identity else { return }
            if !flag { self.error = "Воспроизведение звука прервано." }
            self.stop()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let identity = ObjectIdentifier(player)
        let message = error?.localizedDescription ?? "Неподдерживаемый формат аудио."
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == identity else { return }
            self.error = message
            self.stop()
        }
    }
}
