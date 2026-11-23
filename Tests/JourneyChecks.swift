@main struct JourneyChecks {
    static func main() {
        var j = WorldJourney()
        precondition(!j.enterBubble())
        j.energyFull(hasRescue: true)
        precondition(j.stage == .rescue)
        j.rescued()
        precondition(j.enterBubble())
        precondition(j.requestExit())
        precondition(j.stage == .bubble)
        precondition(!j.requestExit())
        j.returned()
        precondition(j.stage == .ending && !j.canGrowInRoom)
        j.begin(); j.energyFull(hasRescue: false)
        precondition(j.stage == .explore)
        precondition(j.enterBubble()); j.returned()
        precondition(j.stage == .explore && j.canGrowInRoom)
        j.end(); precondition(!j.enterBubble())
        print("Journey transition checks passed")
    }
}
