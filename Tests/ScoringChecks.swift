import Foundation
@main struct ScoringChecks {
    static func main() {
        let p = SqueezeParameters()
        var rhythm = RhythmScorer(p)
        let onBeat = rhythm.started(.init(time: p.inputLatency, closure: 0.6))
        precondition(abs(onBeat - (0.6+1.25+0.3)*1.06) < 1e-9)
        precondition(rhythm.started(.init(time: -1)) == 0 && rhythm.combo == 1)
        precondition(rhythm.started(.init(time: .nan)) == 0)
        var breath = BreathScorer(parameters: p)
        precondition(breath.started(.init(time: 0)) == 0.8)
        precondition(breath.release(.init(time: 4, holdSeconds: 4)) == 5.5)
        precondition(breath.started(.init(time: 9, gapSeconds: 5)) == 4.3)
        precondition(BreathScorer.quality(9) == 0)
        // Integrating the held reward must be independent of frame rate.
        let integral = (1...600).reduce(0.0) { sum, i in
            sum + breath.held(.init(time: Double(i)/100, holdSeconds: Double(i)/100), delta: 0.01)
        }
        precondition(abs(integral - BreathScorer.holdIntegral(6)) < 1e-9)
        precondition(energyAssist(elapsed: 150, mode: .rhythm) == 2.5)
        precondition(energyAssist(elapsed: 300, mode: .free) == 1)
        precondition(OpeningTimeline.english.no.end == 3929)
        print("Unity scoring and timeline checks passed")
    }
}
