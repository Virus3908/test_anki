import SwiftUI
import AVKit
import AVFoundation
import Observation
import UIKit
import AnkiImport

struct AnkiNativeContentView: View {
    let blocks: [AnkiContentBlock]
    let mediaDirectory: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func blockView(_ block: AnkiContentBlock) -> some View {
        switch block.kind {
        case .text:
            Text(attributed(block.runs)).font(.title3).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let url = mediaURL(block.filename) { AnkiNativeImage(url: url, label: block.label) }
        case .audio:
            if let url = mediaURL(block.filename) { AnkiNativeAudio(url: url) }
        case .video:
            if let url = mediaURL(block.filename) { AnkiNativeVideo(url: url) }
        case .divider: Divider()
        case .input: AnkiNativeAnswerInput(placeholder: block.label)
        case .hint:
            DisclosureGroup(block.label) {
                // Type erasure terminates the recursive View type for nested hint blocks.
                AnyView(AnkiNativeContentView(blocks: block.children, mediaDirectory: mediaDirectory))
            }.tint(AppPalette.accent)
        }
    }

    private func mediaURL(_ filename: String?) -> URL? {
        guard let filename, AnkiPackageParser.isSafeFilename(filename) else { return nil }
        return mediaDirectory.appendingPathComponent(filename)
    }

    private func attributed(_ runs: [AnkiTextRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var string = AttributedString(run.text)
            var font = Font.title3
            if run.bold { font = font.bold() }
            if run.italic { font = font.italic() }
            string.font = font
            if run.underline { string.underlineStyle = .single }
            if run.strikethrough { string.strikethroughStyle = .single }
            string.foregroundColor = run.cloze ? AppPalette.accent : AppPalette.text
            result += string
        }
        return result
    }
}

private struct AnkiNativeImage: View {
    let url: URL
    let label: String
    @State private var image: UIImage?
    @State private var failed = false
    private let media = AnkiMediaService()
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel(label.isEmpty ? url.lastPathComponent : label) }
            else if failed { Label("Не удалось открыть изображение: \(url.lastPathComponent)", systemImage: "photo").font(.caption) }
            else { ProgressView() }
        }.frame(maxWidth: .infinity)
            .task(id: url) {
                image = nil; failed = false
                let data = try? await media.data(at: url)
                guard !Task.isCancelled else { return }
                image = data.flatMap { UIImage(data: $0) }
                failed = image == nil
            }
    }
}

private struct AnkiNativeAudio: View {
    let url: URL
    @State private var playback = AnkiAudioPlayback()
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { playback.toggle(url) } label: {
                Label(playback.isPlaying ? "Остановить" : "Воспроизвести", systemImage: playback.isPlaying ? "stop.fill" : "play.fill")
            }.buttonStyle(.bordered).tint(AppPalette.accent)
            if let error = playback.error { Text(error).font(.caption).foregroundStyle(AppPalette.correction) }
        }
        .onChange(of: url) { playback.stop() }
        .onDisappear { playback.stop() }
    }
}

private struct AnkiNativeVideo: View {
    let url: URL
    @State private var player: AVPlayer?
    var body: some View {
        VideoPlayer(player: player).frame(height: 220)
            .onAppear { player = AVPlayer(url: url) }
            .onDisappear { player?.pause(); player = nil }
    }
}

private struct AnkiNativeAnswerInput: View {
    let placeholder: String
    @State private var text = ""
    var body: some View { TextField(placeholder.isEmpty ? "Введите ответ" : placeholder, text: $text).textFieldStyle(.roundedBorder) }
}
