import Foundation

enum MoodKind: String, Codable, CaseIterable {
    case happy, calm, neutral, low, tense
    var preset: SIMD2<Float> {
        switch self { case .happy: return [0.6,0.6]; case .calm: return [0.6,-0.6]; case .low: return [-0.6,-0.6]; case .tense: return [-0.6,0.6]; case .neutral: return .zero }
    }
    var world: String { self == .happy || self == .low ? "candy" : "nature" }
    var mode: SqueezeMode { self == .happy || self == .low ? .rhythm : self == .calm || self == .tense ? .breath : .free }
    func label(english: Bool) -> String {
        if english { return self == .neutral ? "Okay" : rawValue.capitalized }
        switch self { case .happy:return "开心";case .calm:return "平静";case .neutral:return "一般";case .low:return "低落";case .tense:return "烦躁" }
    }
}
enum MoodRules {
    static func classify(_ p: SIMD2<Float>) -> MoodKind {
        let x = min(1,max(-1,p.x)), y = min(1,max(-1,p.y))
        if sqrt(x*x+y*y) < 0.22 { return .neutral }
        return x >= 0 ? (y >= 0 ? .happy : .calm) : (y >= 0 ? .tense : .low)
    }
    static func parameters(for mood: MoodKind?) -> SqueezeParameters {
        var p = SqueezeParameters()
        if mood == .low { p.window = 0.28; p.earlyComboBoost = true }
        if mood == .tense { p.exhaleOk = 6 }
        return p
    }
}
struct MoodRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    let valence: Float
    let arousal: Float
    let mood: MoodKind
    let phase: String
    let world: String?
    let duration: Double
    let presses: Int
}
