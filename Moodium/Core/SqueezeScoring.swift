import Foundation

// Direct ports of Unity SqueezeTuning, RhythmScorer, BreathScorer and EnergyAssist.
// Scene-specific ScriptableObject overrides must be applied before creating scorers.
enum SqueezeMode: String, CaseIterable { case free, rhythm, breath }
struct SqueezeParameters {
    var bpm = 89.0, beatsPerSqueeze = 2.0, beatOffset = 0.0, inputLatency = 0.05
    var window = 0.22, assistWindow = 0.34, base = 0.6, rhythm = 1.25, strength = 0.3
    var comboStep = 0.06, rushBonus = 2.0, spamHard = 0.55, spamHardMult = 0.25, spamSoft = 0.85, spamSoftMult = 0.6
    var comboCap = 8, rushEvery = 8, adaptMisses = 4
    var adaptMin = 0.9, adaptMax = 2.2, rate = 0.5, inhale = 4.0, fadeEnd = 6.0
    var breathBonus = 5.5, qLo = 1.2, qOkLo = 3.0, qOkHi = 5.5, qHi = 8.0
    var exhaleBonus = 3.5, exhaleOk = 5.0, floor = 0.8, floorMinGap = 1.2, floorSpamMult = 0.2
    var earlyComboBoost = false
    var rhythmPeriod: Double { 60 / max(1, bpm) * max(1, beatsPerSqueeze) }
}
struct SqueezeSample {
    var time: Double
    var beatTime: Double = .nan
    var closure: Double = 0
    var holdSeconds: Double = 0
    var gapSeconds: Double = .infinity
}
private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, value)) }
struct RhythmScorer {
    let parameters: SqueezeParameters
    private(set) var combo = 0, misses = 0, hits = 0
    private(set) var adaptive = false, lastRush = false
    private(set) var lastAccuracy = 0.0, lastError = 0.0, lastMultiplier = 0.0
    private(set) var lastStart = Double.nan
    private(set) var adaptiveInterval: Double
    init(_ parameters: SqueezeParameters) { self.parameters = parameters; adaptiveInterval = parameters.rhythmPeriod }
    static func accuracy(error: Double, window: Double) -> Double { clamp(1 - abs(error) / max(0.001, window), 0, 1) }
    mutating func started(_ sample: SqueezeSample) -> Double {
        let p = parameters
        guard sample.time.isFinite, lastStart.isNaN || sample.time >= lastStart else { return 0 }
        let gap = lastStart.isNaN ? .infinity : sample.time - lastStart
        let beat = sample.beatTime.isNaN ? sample.time : sample.beatTime
        let phase = (beat - p.beatOffset - p.inputLatency) / p.rhythmPeriod
        lastError = adaptive && !lastStart.isNaN ? abs(sample.time - lastStart - adaptiveInterval) : abs(phase - phase.rounded(.toNearestOrEven)) * p.rhythmPeriod
        lastAccuracy = Self.accuracy(error: lastError, window: adaptive ? p.assistWindow : p.window)
        if lastAccuracy > 0 { combo += 1; misses = 0; hits += 1 } else { combo = 0; misses += 1 }
        lastMultiplier = 1 + p.comboStep * (p.earlyComboBoost && hits <= 8 ? 2 : 1) * Double(min(combo, p.comboCap))
        lastRush = combo > 0 && combo % max(1, p.rushEvery) == 0
        let spam = gap < p.spamHard ? p.spamHardMult : gap < p.spamSoft ? p.spamSoftMult : 1
        let energy = (p.base + p.rhythm * lastAccuracy + (sample.closure >= 0.6 ? p.strength : 0)) * lastMultiplier * spam + (lastRush ? p.rushBonus : 0)
        if !adaptive && misses >= p.adaptMisses {
            adaptive = true; adaptiveInterval = clamp(gap.isFinite ? gap : p.rhythmPeriod, p.adaptMin, p.adaptMax)
        } else if adaptive && gap.isFinite { adaptiveInterval = clamp(adaptiveInterval * 0.7 + gap * 0.3, p.adaptMin, p.adaptMax) }
        lastStart = sample.time
        return max(0, energy)
    }
}
struct BreathScorer {
    let parameters: SqueezeParameters
    private(set) var released = Double.nan
    private(set) var lastQuality = 0.0, lastExhaleQuality = 0.0
    private(set) var breathCount = 0
    static func quality(_ t: Double, lo: Double = 1.2, okLo: Double = 3, okHi: Double = 5.5, hi: Double = 8) -> Double {
        t < lo || t > hi ? 0 : t < okLo ? (t-lo)/(okLo-lo) : t <= okHi ? 1 : (hi-t)/(hi-okHi)
    }
    static func holdIntegral(_ hold: Double, rate: Double = 0.5, inhale: Double = 4, end: Double = 6) -> Double {
        let first = clamp(hold, 0, inhale), tail = clamp(hold-inhale, 0, max(0.001,end-inhale))
        return rate * (first + tail - tail * tail / (2 * max(0.001,end-inhale)))
    }
    mutating func started(_ s: SqueezeSample) -> Double {
        let p = parameters
        lastExhaleQuality = released.isNaN ? 0 : clamp((max(0,s.time-released)-2)/max(0.001,p.exhaleOk-2),0,1)
        return p.exhaleBonus * lastExhaleQuality + p.floor * (s.gapSeconds >= p.floorMinGap ? 1 : p.floorSpamMult)
    }
    func held(_ s: SqueezeSample, delta: Double) -> Double {
        let p = parameters
        return Self.holdIntegral(s.holdSeconds,rate:p.rate,inhale:p.inhale,end:p.fadeEnd) - Self.holdIntegral(max(0,s.holdSeconds-max(0,delta)),rate:p.rate,inhale:p.inhale,end:p.fadeEnd)
    }
    mutating func release(_ s: SqueezeSample) -> Double {
        let p = parameters; released = s.time
        lastQuality = Self.quality(s.holdSeconds,lo:p.qLo,okLo:p.qOkLo,okHi:p.qOkHi,hi:p.qHi)
        if lastQuality > 0 { breathCount += 1 }
        return p.breathBonus * lastQuality
    }
}
func energyAssist(elapsed: Double, mode: SqueezeMode) -> Double {
    mode == .free ? 1 : 1 + 1.5 * clamp((elapsed-75)/75,0,1)
}
