// Ported directly from Unity Flow/WorldJourneyDirector.cs.
// Rendering and platform input are deliberately outside the journey rules.
struct WorldJourney {
    enum Stage: String { case rescue, explore, bubble, ending }
    private(set) var stage: Stage = .rescue
    private(set) var exitPending = false
    var canGrowInRoom: Bool { stage == .rescue || stage == .explore }
    mutating func begin() { exitPending = false; stage = .rescue }
    mutating func rescued() { if stage == .rescue { stage = .explore } }
    mutating func energyFull(hasRescue: Bool) { if !hasRescue { rescued() } }
    mutating func enterBubble() -> Bool {
        guard stage == .explore, !exitPending else { return false }
        stage = .bubble; return true
    }
    mutating func requestExit() -> Bool {
        guard !exitPending, stage != .ending else { return false }
        exitPending = true
        if stage != .bubble { stage = .ending }
        return true
    }
    mutating func returned() {
        if stage == .bubble { stage = exitPending ? .ending : .explore }
    }
    mutating func end() { exitPending = true; stage = .ending }
}
