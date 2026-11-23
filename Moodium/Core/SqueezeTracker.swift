// Direct port of Unity SqueezeTracker.cs: overlapping contacts count as one squeeze.
struct SqueezeTracker {
    enum Event { case started(SqueezeSample), held(SqueezeSample, Double), released(SqueezeSample) }
    private var sources: Set<Int> = []
    private var start = 0.0, lastPaid = 0.0, lastRelease = Double.nan, pending = Double.nan, grace = 0.15
    private(set) var isHeld = false
    mutating func contact(_ source: Int, now: Double) -> [Event] {
        guard now.isFinite else { return [] }
        var events = tick(now)
        sources.insert(source); pending = .nan; grace = 0.15
        guard !isHeld else { return events }
        isHeld = true; start = now; lastPaid = now
        events.append(.started(.init(time: now, gapSeconds: lastRelease.isNaN ? .infinity : max(0,now-lastRelease))))
        return events
    }
    mutating func pulse(_ source: Int, now: Double) -> [Event] {
        guard now.isFinite else { return [] }
        var events = tick(now)
        if !isHeld || (pending.isNaN && !sources.contains(source)) { return events + contact(source,now:now) }
        let end = pending.isNaN ? now : pending
        sources.removeAll(); pending = .nan; grace = 0.15; lastRelease = end
        events.append(.released(.init(time:end,holdSeconds:max(0,end-start))))
        sources.insert(source); start = now; lastPaid = now
        events.append(.started(.init(time:now,gapSeconds:max(0,now-end))))
        return events
    }
    mutating func release(_ source: Int, now: Double, trackingLost: Bool = false) {
        guard now.isFinite else { return }
        sources.remove(source)
        guard isHeld, sources.isEmpty else { return }
        if pending.isNaN { pending = now; grace = trackingLost ? 0.3 : 0.15 }
        else if trackingLost { grace = max(grace,0.3) }
    }
    mutating func tick(_ now: Double) -> [Event] {
        guard isHeld, now.isFinite else { return [] }
        var events: [Event] = []
        let through = pending.isNaN ? now : min(now,pending)
        if through > lastPaid {
            events.append(.held(.init(time:through,holdSeconds:through-start),through-lastPaid)); lastPaid = through
        }
        if !pending.isNaN && now-pending >= grace {
            let end = pending; isHeld = false; sources.removeAll(); pending = .nan; lastRelease = end
            events.append(.released(.init(time:end,holdSeconds:max(0,end-start))))
        }
        return events
    }
    mutating func reset() { sources.removeAll(); isHeld = false; pending = .nan; lastRelease = .nan }
    mutating func releaseAllForExit(_ now: Double) { sources.removeAll(); if isHeld && pending.isNaN { pending = now } }
}
