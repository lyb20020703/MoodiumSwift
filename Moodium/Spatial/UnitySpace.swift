import RealityKit
import simd

/// Unity left-handed +Z forward to RealityKit right-handed -Z forward.
/// Imported USD models use their declared axes; only Unity-authored scene transforms use this conversion.
enum UnitySpace {
    static func position(_ p: SIMD3<Float>) -> SIMD3<Float> { [p.x, p.y, -p.z] }
    static func rotation(_ q: SIMD4<Float>) -> simd_quatf { simd_quatf(vector: [-q.x, -q.y, q.z, q.w]) }
    static func normalizedModel(_ entity: Entity, extent: Float) -> Entity {
        let wrapper = Entity()
        wrapper.addChild(entity)
        let bounds = entity.visualBounds(relativeTo: wrapper)
        let longest = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        guard longest > 0.0001 else { return wrapper }
        entity.position -= bounds.center
        wrapper.scale = SIMD3(repeating: extent / longest)
        return wrapper
    }
}
