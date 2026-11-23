import RealityKit
import Observation
import QuartzCore
import Combine

@Observable @MainActor final class RescueWorld {
    let root = Entity()
    private(set) var energy = EnergySession()
    private(set) var ready = false
    private(set) var calibration = BagCalibration()
    private(set) var failure: String?
    @ObservationIgnored private var tracker = SqueezeTracker()
    @ObservationIgnored private var soft: Entity?
    @ObservationIgnored private var deformations: [SoftDeformation] = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var contacts: Set<Int> = []
    @ObservationIgnored private var subscription: (any Cancellable)?
    @ObservationIgnored var onStage: ((Int) -> Void)?
    @ObservationIgnored var onPress: (() -> Void)?
    @ObservationIgnored var onReady: (() -> Void)?
    @ObservationIgnored var onProgress: ((Float) -> Void)?

    func load(nature: Bool, calibration: BagCalibration = .init()) async {
        stop(); failure = nil; self.calibration = calibration
        let token = generation
        do {
            let name = nature ? "NatureSoft" : "CandySoft"
            guard let url = Bundle.main.url(forResource:name,withExtension:"usdz",subdirectory:"Content/Models") else { throw CocoaError(.fileNoSuchFile) }
            let model = try await Entity(contentsOf:url)
            guard token == generation, !Task.isCancelled else { return }
            let placement = Entity(); placement.addChild(model)
            let bounds = model.visualBounds(relativeTo:placement)
            model.position = [-bounds.center.x,-bounds.min.y,-bounds.center.z]
            placement.scale = SoftGeometry.fit(width:calibration.width,height:calibration.height,extents:bounds.extents)
            placement.name = "SensoryBag"
            model.generateCollisionShapes(recursive:true)
            func configure(_ entity: Entity) throws {
                if entity.components[ModelComponent.self] != nil {
                    entity.components.set(InputTargetComponent())
                    deformations.append(try SoftDeformation(entity:entity))
                }
                for child in entity.children { try configure(child) }
            }
            try configure(model)
            root.addChild(placement); soft = placement
            ready = true; energy.begin(at:CACurrentMediaTime()); onReady?()
        } catch { failure = "Sensory world could not be loaded: \(error.localizedDescription)" }
    }
    func attachUpdates(to scene: RealityKit.Scene) {
        subscription?.cancel()
        subscription = scene.subscribe(to:SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.update(delta:Float(event.deltaTime)) }
        }
    }
    func contact(source: Int, position: SIMD3<Float>) {
        guard ready else { return }
        let newlyAdded = contacts.insert(source).inserted
        if newlyAdded {
            process(tracker.contact(source,now:CACurrentMediaTime()))
            for d in deformations { d.begin(worldPosition:position) }
        } else { for d in deformations { d.hold(worldPosition:position) } }
    }
    func release(source: Int, trackingLost: Bool = false) {
        contacts.remove(source)
        tracker.release(source,now:CACurrentMediaTime(),trackingLost:trackingLost)
        if contacts.isEmpty { for d in deformations { d.end() } }
    }
    var worldBounds: BoundingBox? { soft?.visualBounds(relativeTo:nil) }
    func owns(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let node = current { if node === soft { return true }; current = node.parent }
        return false
    }
    func contains(worldPosition: SIMD3<Float>) -> Bool {
        guard ready, root.isEnabled, let soft else { return false }
        let bounds = soft.visualBounds(relativeTo:soft)
        let localPosition = soft.convert(position:worldPosition,from:nil)
        let worldScale = soft.scale(relativeTo:nil)
        let padding = SIMD3<Float>(repeating:0.008) / simd_max(simd_abs(worldScale),SIMD3(repeating:0.0001))
        let lo = bounds.min-padding, hi = bounds.max+padding
        return localPosition.x >= lo.x && localPosition.x <= hi.x && localPosition.y >= lo.y && localPosition.y <= hi.y && localPosition.z >= lo.z && localPosition.z <= hi.z
    }
    func setMode(_ mode: SqueezeMode, parameters: SqueezeParameters = .init()) {
        tracker.reset(); contacts.removeAll(); deformations.forEach{$0.end()}; energy.setMode(mode,parameters:parameters)
    }
    func setPace(_ level: Int) { energy.pace = [1.0,2.0,4.0][min(2,max(0,level))] }
    private func update(delta: Float) {
        process(tracker.tick(CACurrentMediaTime()))
        for deformation in deformations { deformation.update(delta:delta) }
    }
    private func process(_ events: [SqueezeTracker.Event]) {
        for event in events {
            if case .started = event { onPress?() }
            let stages = energy.handle(event)
            onProgress?(Float(energy.energy / 100))
            for stage in stages { onStage?(stage) }
        }
    }
    func stop() {
        generation += 1; subscription?.cancel(); subscription = nil
        tracker.reset(); contacts.removeAll(); deformations.removeAll(); root.children.removeAll()
        soft = nil; ready = false; energy = EnergySession()
    }
}
