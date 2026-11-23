import RealityKit
import Observation
import Combine
import QuartzCore

/// Active Unity path: FloatingSqueezeProgress + WorldActionDock.UseTableBesideBag.
@Observable @MainActor final class WorldHUD {
    var ring: Entity?
    var dock: Entity?
    var modes: Entity?
    private(set) var progress: Float = 0
    private(set) var now: Double = 0
    private(set) var shownAt: Double = 0
    private(set) var fullAt: Double?
    private(set) var dotAt = Array(repeating:-100.0,count:40)
    private(set) var giftAt = Array(repeating:-100.0,count:4)
    private(set) var canPress = false
    private var lastPress = -100.0
    private var lastSqueeze = 0.0
    private var alpha: Float = 1
    private var head: simd_float4x4?
    private var tableRight: SIMD3<Float>?
    private var subscription: (any Cancellable)?
    private weak var rescue: RescueWorld?
    func device(_ transform: simd_float4x4) { head = transform }
    func start(scene: RealityKit.Scene,rescue: RescueWorld) {
        stop(); self.rescue = rescue; shownAt = CACurrentMediaTime(); now = shownAt; lastSqueeze = shownAt
        subscription = scene.subscribe(to:SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.update(delta:Float(event.deltaTime)) }
        }
    }
    func pressExit(_ action: () -> Void) { guard canPress else { return }; lastPress = CACurrentMediaTime(); action() }
    func stop() {
        subscription?.cancel(); subscription = nil; rescue = nil; tableRight = nil
        ring?.isEnabled = false; dock?.isEnabled = false; modes?.isEnabled = false; canPress = false
        progress = 0; fullAt = nil; alpha = 1; lastPress = -100
        dotAt = Array(repeating:-100,count:40); giftAt = Array(repeating:-100,count:4)
    }
    private func update(delta: Float) {
        guard let rescue, let bounds = rescue.worldBounds, rescue.root.isEnabled, let head else {
            ring?.isEnabled = false; dock?.isEnabled = false; modes?.isEnabled = false; canPress = false; return
        }
        now = CACurrentMediaTime()
        let next = Float(rescue.energy.energy/100), old = litCount
        progress = next
        if litCount > old { for i in old..<litCount { dotAt[i] = now }; lastSqueeze = now }
        for (i,dot) in [7,19,31,39].enumerated() where old <= dot && litCount > dot { giftAt[i] = now }
        if next >= 1 && fullAt == nil { fullAt = now }
        if next < 1 { fullAt = nil }
        let target: Float = fullAt.map { now-$0 < 1.6 ? 1 : 0 } ?? (now-lastSqueeze > 8 ? 0.6 : 1)
        let step = max(0,delta)/(target < 1 ? 0.6 : 0.2)
        alpha += min(step,max(-step,target-alpha))
        let eyes = SIMD3(head.columns.3.x,head.columns.3.y,head.columns.3.z)
        if let ring {
            let position = SIMD3(bounds.center.x,bounds.max.y+0.16,bounds.center.z)
            ring.isEnabled = alpha > 0
            ring.look(at:[eyes.x,position.y,eyes.z],from:position,relativeTo:nil,forward:.positiveZ)
            ring.components.set(OpacityComponent(opacity:alpha))
        }
        if let modes {
            let age = now-shownAt
            let fadeIn = Float(min(1,max(0,(age-1)/0.4)))
            let fadeOut = Float(fullAt.map { 1-min(1,max(0,(now-$0)/0.4)) } ?? 1)
            let a = fadeIn*fadeIn*(3-2*fadeIn)*fadeOut
            modes.isEnabled = a > 0
            modes.components.set(OpacityComponent(opacity:a))
            let localEyes = rescue.root.convert(position:eyes,from:nil)
            let reversed = localEyes.z < 0
            let local = SIMD3<Float>(0,0.002,(rescue.calibration.height/2+0.13)*(reversed ? 1 : -1))
            modes.setPosition(rescue.root.convert(position:local,to:nil),relativeTo:nil)
            modes.setOrientation(rescue.root.orientation(relativeTo:nil)*simd_quatf(angle:reversed ? .pi : 0,axis:[0,1,0])*simd_quatf(angle:-Float.pi/2,axis:[1,0,0]),relativeTo:nil)
        }
        if tableRight == nil {
            var toward = SIMD3(bounds.center.x-eyes.x,0,bounds.center.z-eyes.z)
            toward = simd_length_squared(toward)>0.0001 ? simd_normalize(toward) : [0,0,-1]
            tableRight = simd_normalize(simd_cross(toward,SIMD3<Float>(0,1,0)))
        }
        if let dock {
            let position = bounds.center+tableRight!*(max(bounds.extents.x,bounds.extents.z)/2+0.18)+SIMD3<Float>(0,0.07-0.029,0)
            dock.isEnabled = true
            dock.look(at:eyes,from:position,relativeTo:nil,forward:.positiveZ)
            dock.components.set(OpacityComponent(opacity:Float(min(1,(now-shownAt)/0.25))))
        }
        canPress = now-shownAt >= 0.5 && now-lastPress >= 0.4
    }
    var litCount: Int { min(40,max(0,Int(floor(progress*40+0.0001)))) }
    var headIndex: Int { litCount>0 && litCount<40 ? litCount-1 : -1 }
}
