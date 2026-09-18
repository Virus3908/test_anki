import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class AnkiAudioPlayback: NSObject, AVAudioPlayerDelegate {
    // One active clip, even when a card contains several audio buttons.
    private static weak var activePlayback: AnkiAudioPlayback?
    @ObservationIgnored private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    private(set) var error: String?

    func toggle(_ url: URL) {
        if isPlaying { stop(); return }
        Self.activePlayback?.stop()
        error = nil
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            let session = AVAudioSession.sharedInstance()
            // The default session is silenced by the iPhone's Ring/Silent switch.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            Self.activePlayback = self
            player = next
            next.delegate = self
            guard next.prepareToPlay(), next.play() else {
                error = "Не удалось воспроизвести звук: \(url.lastPathComponent)"
                stop()
                return
            }
            isPlaying = true
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
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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
