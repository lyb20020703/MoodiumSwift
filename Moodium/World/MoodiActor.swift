import Foundation
import RealityKit
import Observation

@MainActor final class MoodiActor {
    let root = Entity()
    private(set) var visual: Entity?
    private var clips: [String:AnimationResource] = [:]
    private var playback: AnimationPlaybackController?
    private var generation = 0
    private var currentClip: String?
    func load() async throws {
        let token = generation
        guard let url=Bundle.main.url(forResource:"Idle",withExtension:"usdz",subdirectory:"Content/Animations") else { throw CocoaError(.fileNoSuchFile) }
        let entity=try await Entity(contentsOf:url)
        guard token == generation,!Task.isCancelled else { return }
        visual=entity
        let sized=UnitySpace.normalizedModel(entity,extent:0.04)
        root.addChild(sized)
        if let animation=firstAnimation(entity) { clips["Idle"]=animation }
        await play("Idle",loop:true)
    }
    private func firstAnimation(_ entity:Entity) -> AnimationResource? {
        if let animation=entity.availableAnimations.first { return animation }
        for child in entity.children { if let animation=firstAnimation(child) { return animation } }
        return nil
    }
    func play(_ name:String,loop:Bool=false) async {
        currentClip=name
        let token=generation
        if clips[name] == nil,let url=Bundle.main.url(forResource:name,withExtension:"usdz",subdirectory:"Content/Animations"),let loaded=try? await Entity(contentsOf:url) {
            guard token==generation else { return }
            clips[name]=firstAnimation(loaded)
        }
        guard currentClip==name,token==generation,let visual,let clip=clips[name] else { return }
        playback?.stop()
        playback=visual.playAnimation(loop ? clip.repeat() : clip,transitionDuration:0.1)
    }
    func scrubEmergence(_ progress:Float) {
        guard currentClip=="Emerge",let playback else { return }
        playback.pause();playback.time=Double(min(1,max(0,progress)))*playback.duration
    }
    func stop() { generation+=1;playback?.stop();playback=nil;root.children.removeAll();visual=nil;clips.removeAll() }
}
