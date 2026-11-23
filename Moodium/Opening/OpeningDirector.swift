import AVFoundation
import Observation

@Observable @MainActor
final class OpeningDirector {
    enum Phase: Equatable { case preview, intro, language, question, answer, finished }
    private(set) var phase: Phase = .preview
    private(set) var english = false
    private(set) var hasBag = false
    private(set) var choosing = false
    private(set) var currentFrame = 0
    private(set) var elapsed: Double = 0
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var promptAt = Date()
    private(set) var failure: String?
    let player = AVPlayer()
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var choiceTask: Task<Void, Never>?
    @ObservationIgnored private var seeking = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var answer: OpeningTimeline.Segment?
    private var timeline: OpeningTimeline.Language { english ? OpeningTimeline.english : OpeningTimeline.chinese }

    private var defaults: UserDefaults { .standard }
    private func shouldAsk(_ key: String, answer: String) -> Bool {
        (defaults.object(forKey:key) as? Bool ?? true) || !defaults.bool(forKey:"Moodium.Opening.Completed") || defaults.object(forKey:answer) == nil
    }
    func start() {
        stop()
        guard let url = Bundle.main.url(forResource: "VideoPLUS", withExtension: "mp4", subdirectory: "Content/Video") else {
            failure = "Opening video is missing."; return
        }
        english = defaults.string(forKey:"Moodium.Language") == "English"
        hasBag = defaults.bool(forKey:"Moodium.HasSensoryBag")
        currentFrame = 0; elapsed = 0
        phase = .preview; startedAt = Date(); failure = nil; choosing = false; answer = nil
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            Task { @MainActor in self?.advance(time.seconds) }
        }
        player.play()
    }
    private func advance(_ seconds: Double) {
        guard seconds.isFinite, !seeking, !choosing else { return }
        if player.currentItem?.status == .failed {
            failure = player.currentItem?.error?.localizedDescription ?? "Opening playback failed."
            player.pause(); return
        }
        let frame = Int((seconds * 30).rounded(.down))
        currentFrame = frame; elapsed = Date().timeIntervalSince(startedAt)
        switch phase {
        case .preview:
            if elapsed >= 30 { activate() }
            else if seconds >= 3.08 { seek(0) }
        case .intro:
            if frame >= OpeningTimeline.language.start {
                phase = .language; promptAt = Date()
                if !shouldAsk("Moodium.Opening.AskLanguage",answer:"Moodium.Language") { chooseLanguage(english:english) }
            }
        case .language:
            if Date().timeIntervalSince(promptAt) >= 30 { chooseLanguage(english: false); return }
            if frame >= OpeningTimeline.language.end { seek(OpeningTimeline.language.start) }
        case .question:
            if frame >= timeline.question.start && !shouldAsk("Moodium.Opening.AskBag",answer:"Moodium.HasSensoryBag") { chooseBag(hasBag); return }
            if frame >= timeline.question.end { seek(timeline.question.start) }
        case .answer:
            if let answer, frame >= answer.end { phase = .finished; defaults.set(true,forKey:"Moodium.Opening.Completed"); player.pause() }
        case .finished: break
        }
    }
    var showQuestion: Bool {
        phase == .question && currentFrame >= timeline.question.start
    }
    func activate() {
        guard phase == .preview else { return }; phase = .intro; seek(93)
    }
    func chooseLanguage(english: Bool) {
        guard phase == .language, !choosing else { return }
        delayedChoice { [weak self] in
            guard let self else { return }
            self.english = english; UserDefaults.standard.set(english ? "English" : "Chinese", forKey: "Moodium.Language"); self.phase = .question
            self.seek(self.timeline.entry)
        }
    }
    func chooseBag(_ hasBag: Bool) {
        guard phase == .question, !choosing else { return }
        delayedChoice { [weak self] in
            guard let self else { return }
            self.hasBag = hasBag
            UserDefaults.standard.set(hasBag, forKey: "Moodium.HasSensoryBag")
            self.answer = hasBag ? self.timeline.yes : self.timeline.no
            self.phase = .answer; self.seek(self.answer!.start)
        }
    }
    private func delayedChoice(_ action: @escaping @MainActor () -> Void) {
        choosing = true
        choiceTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            action(); self.choosing = false
        }
    }
    private func seek(_ frame: Int) {
        seeking = true
        let token = generation
        player.seek(to: CMTime(value: Int64(frame), timescale: 30), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            Task { @MainActor in
                guard let self, token == self.generation else { return }
                self.seeking = false
                if completed && self.phase != .finished { self.player.play() }
            }
        }
    }
    func skip() { choiceTask?.cancel(); generation += 1; choosing = false; phase = .finished; player.pause() }
    func stop() {
        generation += 1; choiceTask?.cancel(); choiceTask = nil
        if let observer { player.removeTimeObserver(observer); self.observer = nil }
        player.pause(); player.replaceCurrentItem(with: nil); seeking = false
    }
}
