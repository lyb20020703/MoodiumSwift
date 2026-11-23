@main struct TrackerChecks {
    static func main() {
        var t = SqueezeTracker()
        precondition(t.contact(1,now:0).count == 1)
        // A second overlapping hand joins the same squeeze.
        let join = t.contact(2,now:0.1)
        precondition(join.count == 1)
        if case .held = join[0] {} else { fatalError("Duplicate start") }
        t.release(1,now:0.2)
        precondition(t.isHeld)
        t.release(2,now:0.3,trackingLost:true)
        _ = t.tick(0.5); precondition(t.isHeld)
        let done = t.tick(0.61)
        precondition(!t.isHeld && done.count == 1)
        if case .released(let sample) = done[0] { precondition(sample.holdSeconds == 0.3) }
        else { fatalError("Expected release at last tracked time") }
        _ = t.contact(1,now:1); t.release(1,now:1.1)
        _ = t.contact(1,now:1.2); precondition(t.isHeld)
        let pulse = t.pulse(1,now:1.3)
        precondition(pulse.count == 3)
        t.reset(); precondition(!t.isHeld)
        print("Overlapping contact and tracking-loss checks passed")
    }
}
