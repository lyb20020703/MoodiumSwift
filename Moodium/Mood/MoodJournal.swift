import Foundation
import Observation

@Observable @MainActor final class MoodJournal {
    private(set) var records: [MoodRecord] = []
    private(set) var failure: String?
    private let url: URL
    init() {
        url = URL.applicationSupportDirectory.appending(path:"Moodium/mood-records.json")
        do {
            if FileManager.default.fileExists(atPath:url.path) { records = try JSONDecoder().decode([MoodRecord].self,from:Data(contentsOf:url)) }
        } catch { failure = "Mood records could not be read: \(error.localizedDescription)" }
    }
    @discardableResult func save(_ point: SIMD2<Float>, phase: String, world: String? = nil, duration: Double = 0, presses: Int = 0) -> MoodKind {
        let mood = MoodRules.classify(point)
        let record = MoodRecord(valence:point.x,arousal:point.y,mood:mood,phase:phase,world:world,duration:max(0,duration),presses:max(0,presses))
        do {
            var updated = records; updated.append(record)
            let data = try JSONEncoder().encode(updated)
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            try data.write(to:url,options:.atomic); records = updated; failure = nil
        } catch { failure = "Mood record could not be saved: \(error.localizedDescription)" }
        return mood
    }
}
