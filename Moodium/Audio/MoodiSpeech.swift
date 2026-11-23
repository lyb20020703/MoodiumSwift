import Foundation
import RealityKit

/// Local spatial voice. The Unity low-pass muffle still needs a native DSP path.
@MainActor final class MoodiSpeech {
    private var cache: [String: AudioFileResource] = [:]
    private var playback: AudioPlaybackController?
    private var generation = 0
    var english = false
    private(set) var failure: String?
    var speaking: Bool { playback?.isPlaying == true }
    func say(_ id: String, from entity: Entity, interrupt: Bool = false) async {
        guard interrupt || !speaking else { return }
        let token = generation
        let language = english ? "en" : "zh"
        let key = "moodi_vo_\(id)_\(language)"
        do {
            if cache[key] == nil {
                guard let url = Bundle.main.url(forResource:key,withExtension:"wav",subdirectory:"Content/Voice/\(language)") else { throw CocoaError(.fileNoSuchFile) }
                cache[key] = try await AudioFileResource(contentsOf:url)
            }
            guard token == generation, !Task.isCancelled, let resource = cache[key], interrupt || !speaking else { return }
            playback?.stop(); playback = entity.playAudio(resource)
        } catch { failure = error.localizedDescription }
    }
    func waitUntilQuiet(extra: Double = 0) async throws {
        while speaking { try Task.checkCancellation(); try await Task.sleep(for:.milliseconds(30)) }
        if extra > 0 { try await Task.sleep(for:.seconds(extra)) }
    }
    func stop() { generation += 1; playback?.stop(); playback = nil }
}
