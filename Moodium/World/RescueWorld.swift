import RealityKit
import Observation
import QuartzCore
import Combine

@Observable @MainActor final class RescueWorld {
    let root = Entity()
    private(set) var energy = EnergySession()
    private(set) var ready = false
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

    func load(nature: Bool) async {
        stop(); failure = nil
        let token = generation
        do {
            let name = nature ? "NatureSoft" : "CandySoft"
            guard let url = Bundle.main.url(forResource:name,withExtension:"usdz",subdirectory:"Content/Models") else { throw CocoaError(.fileNoSuchFile) }
            let model = try await Entity(contentsOf:url)
            guard token == generation, !Task.isCancelled else { return }
            let placement = Entity(); placement.addChild(model)
            let bounds = model.visualBounds(relativeTo:placement)
            model.position = [-bounds.center.x,-bounds.min.y,-bounds.center.z]
            placement.scale = SoftGeometry.fit(width:0.4,height:0.25,extents:bounds.extents)
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
            ready = true; onReady?()
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
    func contains(worldPosition: SIMD3<Float>) -> Bool {
        guard let soft else { return false }
        let bounds = soft.visualBounds(relativeTo:nil)
        let padding = SIMD3<Float>(repeating:0.008)
        let lo = bounds.min-padding, hi = bounds.max+padding
        return worldPosition.x >= lo.x && worldPosition.x <= hi.x && worldPosition.y >= lo.y && worldPosition.y <= hi.y && worldPosition.z >= lo.z && worldPosition.z <= hi.z
    }
    func setMode(_ mode: SqueezeMode) {
        tracker.reset(); contacts.removeAll(); deformations.forEach{$0.end()}; energy.setMode(mode)
    }
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
