import RealityKit
import Observation
import UIKit

@Observable @MainActor final class BagCalibrator {
    let root = Entity()
    let plane = Entity()
    private(set) var data = BagCalibration()
    private(set) var active = false
    private(set) var interacted = false
    private(set) var failure: String?
    var controls: Entity?
    private var handles: [BagCalibration.Handle:Entity] = [:]
    private var drag: (kind:BagCalibration.Handle, start:SIMD3<Float>, data:BagCalibration)?
    private var generation = 0
    private var mayRelocate = false
    init() { root.addChild(plane); root.isEnabled = false }
    func begin(transform: simd_float4x4, fallback: Bool = false) async {
        stop(); active = true; root.isEnabled = true; data = BagCalibration(); failure = nil; interacted = false
        root.setTransformMatrix(transform,relativeTo:nil)
        mayRelocate = fallback
        let token = generation
        do {
            for kind in BagCalibration.Handle.allCases where kind != .height && kind != .rotate {
                let entity: Entity
                if kind == .frame { entity = Entity() }
                else {
                    let corner = [.topLeft,.topRight,.bottomLeft,.bottomRight].contains(kind)
                    entity = try await sprite(corner ? "calib_corner" : "calib_line")
                }
                guard token == generation else { return }
                entity.name = "Calibration-"+kind.rawValue
                entity.components.set(InputTargetComponent()); plane.addChild(entity); handles[kind] = entity
            }
            refresh()
        } catch { failure = "Calibration assets: \(error.localizedDescription)" }
    }
    func relocate(_ transform: simd_float4x4) { guard active && !interacted && mayRelocate else { return }; mayRelocate = false; root.setTransformMatrix(transform,relativeTo:nil); refresh() }
    func reset() { data = BagCalibration(); interacted = true; drag = nil; refresh() }
    func height(_ delta: Float) { guard active else { return }; interacted = true; data.setPlaneHeight(data.planeHeight+delta); refresh() }
    func rotate(_ degrees: Float) { guard active else { return }; interacted = true; data.yaw += degrees*Float.pi/180; refresh() }
    func move(entity: Entity, worldPosition: SIMD3<Float>) -> Bool {
        guard active, let kind = handles.first(where:{$0.value === entity})?.key else { return false }
        interacted = true
        let local = root.convert(position:worldPosition,from:nil)
        if drag == nil { drag = (kind,local,data) }
        guard let drag, drag.kind == kind else { return true }
        if kind == .frame { data.center = drag.data.center+SIMD2(local.x-drag.start.x,local.z-drag.start.z) }
        else {
            // Keep the opposite edge fixed in the rotated frame.
            let q = simd_quatf(angle:-data.yaw,axis:[0,1,0])
            let centered = q.act(local-SIMD3(data.center.x,0,data.center.y))
            let oldCenter = data.center
            data.resize(kind,to:SIMD2(centered.x,-centered.z)+data.center)
            let shift = data.center-oldCenter
            let worldShift = simd_quatf(angle:data.yaw,axis:[0,1,0]).act([shift.x,0,-shift.y])
            data.center = oldCenter+SIMD2(worldShift.x,worldShift.z)
        }
        refresh(); return true
    }
    func endDrag() { drag = nil }
    var placement: simd_float4x4 {
        root.transformMatrix(relativeTo:nil) * Transform(rotation:simd_quatf(angle:data.yaw,axis:[0,1,0]),translation:[data.center.x,data.planeHeight,data.center.y]).matrix
    }
    func stop() { generation += 1; active = false; root.isEnabled = false; controls?.isEnabled = false; handles.removeAll(); plane.children.removeAll(); drag = nil }
    private func refresh() {
        plane.position = [data.center.x,data.planeHeight,data.center.y]
        plane.orientation = simd_quatf(angle:data.yaw,axis:[0,1,0])
        for (kind,entity) in handles {
            var x: Float = 0, z: Float = 0
            if [.left,.topLeft,.bottomLeft].contains(kind) { x = -data.width/2 }
            if [.right,.topRight,.bottomRight].contains(kind) { x = data.width/2 }
            if [.top,.topLeft,.topRight].contains(kind) { z = -data.height/2 }
            if [.bottom,.bottomLeft,.bottomRight].contains(kind) { z = data.height/2 }
            entity.position = [x,0.001,z]
            if kind == .frame {
                entity.components.set(CollisionComponent(shapes:[.generateBox(size:[max(0.001,data.width-0.004),0.004,max(0.001,data.height-0.004)])]))
            } else {
                let vertical = kind == .left || kind == .right
                let edge = [.left,.right,.top,.bottom].contains(kind)
                entity.orientation = simd_quatf(angle:-Float.pi/2,axis:[1,0,0]) * simd_quatf(angle:vertical ? Float.pi/2 : 0,axis:[0,0,1])
                if edge {
                    entity.scale = [vertical ? data.height : data.width,0.008,1]
                    entity.components.set(CollisionComponent(shapes:[.generateBox(size:[1,5,0.02])]))
                } else {
                    let angle: Float = kind == .topRight ? -.pi/2 : kind == .bottomRight ? .pi : kind == .bottomLeft ? .pi/2 : 0
                    entity.orientation *= simd_quatf(angle:angle,axis:[0,0,1]); entity.scale = [0.0275,0.0275,1]
                    entity.components.set(CollisionComponent(shapes:[.generateBox(size:[1.82,1.82,0.04])]))
                }
            }
        }
        if let controls { controls.isEnabled = active; controls.position = root.convert(position:[data.center.x,data.planeHeight+0.14,data.center.y-data.height/2-0.06],to:controls.parent) }
    }
    private func sprite(_ name: String) async throws -> ModelEntity {
        guard let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Calibration") else { throw CocoaError(.fileNoSuchFile) }
        let texture = try await TextureResource(contentsOf:url)
        var material = UnlitMaterial(); material.color = .init(tint:UIColor(red:0.92,green:0.98,blue:1,alpha:1),texture:.init(texture)); material.blending = .transparent(opacity:.init(floatLiteral:1)); material.faceCulling = .none
        if name == "calib_corner" {
            let px: Float = 0.16363636, py: Float = 0.8363637
            var descriptor = MeshDescriptor(name:"Unity corner pivot")
            descriptor.positions = MeshBuffers.Positions([[-px,-py,0],[1-px,-py,0],[-px,1-py,0],[1-px,1-py,0]])
            descriptor.normals = MeshBuffers.Normals(Array(repeating:[0,0,1],count:4))
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates([[0,0],[1,0],[0,1],[1,1]])
            descriptor.primitives = .triangles([0,1,2,1,3,2])
            return ModelEntity(mesh:try MeshResource.generate(from:[descriptor]),materials:[material])
        }
        return ModelEntity(mesh:.generatePlane(width:1,height:1),materials:[material])
    }
}
