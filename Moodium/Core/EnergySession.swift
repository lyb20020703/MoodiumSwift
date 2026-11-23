import Foundation

struct EnergySession {
    private(set) var energy = 0.0
    private(set) var mode: SqueezeMode = .free
    private(set) var presses = 0
    var pace = 1.0
    private var rhythm = RhythmScorer(SqueezeParameters())
    private var breath = BreathScorer(parameters:SqueezeParameters())
    private var began = Double.nan
    mutating func begin(at time: Double) { if time.isFinite { began = time } }
    mutating func setMode(_ value: SqueezeMode, parameters: SqueezeParameters = .init()) {
        mode = value; rhythm = RhythmScorer(parameters); breath = BreathScorer(parameters:parameters)
    }
    mutating func handle(_ event: SqueezeTracker.Event) -> [Int] {
        guard energy < 100 else { return [] }
        let amount: Double, time: Double
        switch event {
        case .started(let sample):
            presses += 1; time = sample.time
            if began.isNaN { began = time }
            switch mode { case .free: amount = 5; case .rhythm: amount = rhythm.started(sample); case .breath: amount = breath.started(sample) }
        case .held(let sample,let delta): time = sample.time; amount = mode == .breath ? breath.held(sample,delta:delta) : 0
        case .released(let sample): time = sample.time; amount = mode == .breath ? breath.release(sample) : 0
        }
        guard amount.isFinite, amount > 0, energy < 100 else { return [] }
        let previous = energy
        energy = min(100, energy + amount * pace * energyAssist(elapsed:began.isNaN ? 0 : time-began,mode:mode))
        return [20,50,80,100].filter { previous < Double($0) && energy >= Double($0) }
    }
}
