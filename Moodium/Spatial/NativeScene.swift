import RealityKit
import AVFoundation
import Observation
import ARKit

@Observable @MainActor
final class NativeScene {
    let root = Entity()
    private(set) var selection = 0
    private(set) var inWorld = false
    let rescue = RescueWorld()
    let hud = WorldHUD()
    let calibrator = BagCalibrator()
    private(set) var preparing = false
    private(set) var stickerSelection: UUID?
    private var activeSticker: UUID?
    let moodi = MoodiActor()
    let speech = MoodiSpeech()
    private(set) var introDone = false
    var selectedMood: MoodKind?
    private(set) var enteredWorld: String?
    private(set) var visitStarted: Date?
    private(set) var journey = WorldJourney()
    @ObservationIgnored private var speechTask: Task<Void,Never>?
    @ObservationIgnored private var storyTask: Task<Void,Never>?
    private(set) var failure: String?
    @ObservationIgnored var video: ModelEntity?
    @ObservationIgnored var carouselControls: Entity?
    @ObservationIgnored private var islands: [Entity] = []
    @ObservationIgnored private var loading = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var visitGeneration = 0
    @ObservationIgnored private var stickers: [UUID: Entity] = [:]
    @ObservationIgnored private var stickerLoads: Set<UUID> = []
    @ObservationIgnored private var latestImages: [UUID: ImageAnchor] = [:]

    func installVideo(_ player: AVPlayer) {
        var material = VideoMaterial(avPlayer: player)
        material.writesDepth = false
        material.faceCulling = .none
        let video = ModelEntity(mesh: .generatePlane(width: 1.28, height: 0.72), materials: [material])
        video.name = "Unity Opening Video"
        video.generateCollisionShapes(recursive: false)
        video.components.set(InputTargetComponent())
        video.position = [0, 1.15, -1.35]
        root.addChild(video); self.video = video
    }
    func loadCarousel() async {
        guard islands.isEmpty, !loading else { return }
        loading = true
        let token = generation
        defer { loading = false }
        var loaded: [Entity] = []
        do {
            for name in ["CandyWorldUI", "NatureWorldUI"] {
                guard let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Content/Models") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let model = try await Entity(contentsOf: url)
                guard !Task.isCancelled, generation == token else { return }
                let item = UnitySpace.normalizedModel(model, extent: 0.44)
                item.name = name
                let placement = Entity(); placement.addChild(item)
                loaded.append(placement)
            }
            islands = loaded
            for entity in islands { root.addChild(entity) }
            applyLayout(animated: false)
        } catch { failure = "World model could not be loaded: \(error.localizedDescription)" }
    }
    func updateSticker(_ anchor: ImageAnchor, tracked: Bool) async {
        if !tracked {
            if activeSticker == anchor.id { rescue.root.isEnabled = false }
            if stickerSelection == anchor.id { stickerSelection = nil }
            latestImages.removeValue(forKey: anchor.id)
            stickers[anchor.id]?.isEnabled = false
            return
        }
        latestImages[anchor.id] = anchor
        if !inWorld { stickerSelection = anchor.id; selection = anchor.referenceImage.name == "NatureWorldPhoneTracking" ? 1 : 0 }
        if activeSticker == anchor.id {
            rescue.root.isEnabled = true
            var placement = anchor.originFromAnchorTransform
            placement.columns.3 -= placement.columns.1 * 0.08
            rescue.root.setTransformMatrix(placement,relativeTo:nil)
        }
        if let entry = stickers[anchor.id] {
            entry.isEnabled = !inWorld; entry.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)
            return
        }
        guard !stickerLoads.contains(anchor.id) else { return }
        stickerLoads.insert(anchor.id)
        defer { stickerLoads.remove(anchor.id) }
        let token = generation
        let name = anchor.referenceImage.name == "NatureWorldPhoneTracking" ? "NatureWorldUI" : "CandyWorldUI"
        do {
            guard let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Content/Models") else { throw CocoaError(.fileNoSuchFile) }
            let model = try await Entity(contentsOf: url)
            guard generation == token, let current = latestImages[anchor.id] else { return }
            let entry = Entity(); entry.name = "Sticker-" + name
            let visual = UnitySpace.normalizedModel(model, extent: 0.44)
            visual.position = UnitySpace.position([0, 0.12, 0.10])
            entry.addChild(visual); root.addChild(entry)
            entry.setTransformMatrix(current.originFromAnchorTransform, relativeTo: nil)
            entry.isEnabled = !inWorld
            stickers[anchor.id] = entry
        } catch { failure = "Sticker world could not be loaded: \(error.localizedDescription)" }
    }
    func enterWorld(nature: Bool, english: Bool = false, placement: simd_float4x4? = nil, calibration: BagCalibration = .init()) async {
        guard !inWorld else { return }
        visitGeneration += 1
        let visit = visitGeneration
        failure = nil; enteredWorld = nature ? "nature" : "candy"; visitStarted = Date()
        inWorld = true; introDone = false; journey.begin(); speech.english = english
        for island in islands { island.isEnabled = false }
        for entry in stickers.values { entry.isEnabled = false }
        carouselControls?.isEnabled = false
        rescue.root.isEnabled = true
        rescue.root.position = [0, 0.75, -0.75]
        root.addChild(rescue.root)
        if let placement { rescue.root.setTransformMatrix(placement,relativeTo:nil) }
        await rescue.load(nature: nature,calibration:calibration)
        guard visit == visitGeneration, inWorld else { return }
        guard rescue.ready else { failure = rescue.failure; return }
        if let scene = root.scene {
            rescue.attachUpdates(to:scene)
            hud.start(scene:scene,rescue:rescue)
        }
        rescue.setMode(selectedMood?.mode ?? .free,parameters:MoodRules.parameters(for:selectedMood))
        rescue.setPace(UserDefaults.standard.integer(forKey:"Moodium.ProgressPace"))
        do {
            try await moodi.load()
            guard visit == visitGeneration, inWorld else { return }
            rescue.root.addChild(moodi.root)
            rescue.onStage = { [weak self] stage in
                guard let self else { return }
                if let line = [20:"K5",50:"K6",80:"K7"][stage] {
                    self.speechTask = Task { await self.speech.say(line,from:self.moodi.root) }
                }
                if stage == 100 { self.storyTask?.cancel(); self.storyTask = Task { await self.jumpOut() } }
            }
            rescue.onProgress = { [weak self] progress in
                guard let self, self.introDone, self.journey.stage == .rescue else { return }
                self.moodi.scrubEmergence(progress)
            }
            rescue.onPress = { [weak self] in
                guard let self, self.introDone, self.rescue.energy.presses == 0 else { return }
                self.speechTask = Task { await self.speech.say("K4",from:self.moodi.root) }
            }
            storyTask = Task { await runIntro() }
        } catch { guard visit == visitGeneration else { return }; failure = "Moodi animation could not be loaded: \(error.localizedDescription)" }
    }
    func enterSticker(english: Bool) async {
        guard let id = stickerSelection, let anchor = latestImages[id], !inWorld else { return }
        activeSticker = id
        var placement = anchor.originFromAnchorTransform
        placement.columns.3 -= placement.columns.1 * 0.08
        await enterWorld(nature:anchor.referenceImage.name == "NatureWorldPhoneTracking",english:english,placement:placement)
    }
    func prepareTable(tracking: SpatialTracking) async {
        guard !inWorld && !preparing else { return }
        preparing = true
        for island in islands { island.isEnabled = false }
        let token = generation
        // Unity waits up to three seconds, then exposes an adjustable fallback.
        let began = Date()
        var pose = tracking.tablePose()
        while !pose.found && Date().timeIntervalSince(began) < 3 {
            do { try await Task.sleep(for:.milliseconds(100)) } catch { preparing = false; return }
            guard preparing, generation == token else { return }
            pose = tracking.tablePose()
        }
        guard preparing, generation == token else { return }
        root.addChild(calibrator.root)
        await calibrator.begin(transform:pose.transform,fallback:!pose.found)
    }
    func confirmCalibration(english: Bool) async {
        guard calibrator.active else { return }
        let placement = calibrator.placement, data = calibrator.data
        calibrator.stop(); preparing = false
        await enterWorld(nature:selection == 1,english:english,placement:placement,calibration:data)
    }
    func cancelCalibration() {
        preparing = false; calibrator.stop()
        for island in islands { island.isEnabled = true }
    }
    private func runIntro() async {
        // Unity MoodiRescueDirector timings and distances. Surface alignment is refined
        // against the serialized surface samples before visual acceptance.
        moodi.root.position = [0.12,0.38,0]
        await moodi.play("Wave")
        moodi.root.move(to:Transform(translation:[0,0.38,0]),relativeTo:rescue.root,duration:0.6,timingFunction:.easeOut)
        do { try await Task.sleep(for:.seconds(1.5)) } catch { return }
        await speech.say("K1",from:moodi.root)
        await moodi.play("FallIn")
        moodi.root.move(to:Transform(translation:[0,0.08,0]),relativeTo:rescue.root,duration:0.4,timingFunction:.easeIn)
        do { try await Task.sleep(for:.seconds(0.9)) } catch { return }
        await moodi.play("Peek",loop:true)
        do {
            try await Task.sleep(for:.seconds(0.7))
            await speech.say("K2",from:moodi.root)
            try await speech.waitUntilQuiet(extra:0.3)
            await speech.say("K3",from:moodi.root)
            try await speech.waitUntilQuiet(extra:0.6)
            introDone = true
            await moodi.play("Emerge")
            moodi.scrubEmergence(0)
        } catch { return }
    }
    private func jumpOut() async {
        introDone = true; speech.stop(); journey.rescued()
        await moodi.play("Happy")
        moodi.root.move(to:Transform(translation:[0,0.30,0.10]),relativeTo:rescue.root,duration:0.6,timingFunction:.easeOut)
        do { try await Task.sleep(for:.seconds(0.6)) } catch { return }
        await speech.say("K10",from:moodi.root,interrupt:true)
    }
    func leaveWorld() {
        visitGeneration += 1
        storyTask?.cancel(); storyTask = nil; speechTask?.cancel(); speech.stop(); introDone = false; journey.end(); rescue.stop(); rescue.root.removeFromParent(); moodi.stop()
        hud.stop(); activeSticker = nil
        cancelCalibration()
        inWorld = false; visitStarted = nil; failure = nil
        for (id, entry) in stickers { entry.isEnabled = latestImages[id] != nil }
        for island in islands { island.isEnabled = true }
        carouselControls?.isEnabled = true
    }
    func select(_ value: Int) { selection = min(1, max(0, value)); applyLayout(animated: true) }
    private func applyLayout(animated: Bool) {
        for (index, entity) in islands.enumerated() {
            let delta = Float(index - selection)
            let side = min(1, abs(delta))
            let transform = Transform(scale: SIMD3(repeating: 1 - side * 0.3),
                rotation: simd_quatf(angle: -delta * 20 * .pi / 180, axis: [0,1,0]),
                translation: [delta * 0.58, 1.07, -0.75 - abs(delta) * 0.06])
            if animated { entity.move(to: transform, relativeTo: root, duration: 0.35, timingFunction: .easeOut) }
            else { entity.transform = transform }
            entity.components.set(OpacityComponent(opacity: 1 - side * 0.45))
        }
    }
    func stop() { leaveWorld(); generation += 1; root.children.removeAll(); islands.removeAll(); video = nil; stickers.removeAll(); latestImages.removeAll(); stickerLoads.removeAll() }
}
