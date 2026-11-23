import Foundation
import simd

struct BagCalibration {
    enum Handle: String, CaseIterable { case frame,left,right,top,bottom,topLeft,topRight,bottomLeft,bottomRight,height,rotate }
    var width: Float = 0.4
    var height: Float = 0.25
    var center = SIMD2<Float>.zero
    var planeHeight: Float = -0.08
    var yaw: Float = 0
    mutating func setPlaneHeight(_ value: Float) { if value.isFinite { planeHeight = min(0.10,max(-0.25,value)) } }
    mutating func resize(_ handle: Handle, to point: SIMD2<Float>) {
        guard point.x.isFinite && point.y.isFinite else { return }
        var left = center.x-width/2, right = center.x+width/2
        var bottom = center.y-height/2, top = center.y+height/2
        if [.left,.topLeft,.bottomLeft].contains(handle) { left = min(right-0.08,max(right-0.6,point.x)) }
        if [.right,.topRight,.bottomRight].contains(handle) { right = min(left+0.6,max(left+0.08,point.x)) }
        if [.bottom,.bottomLeft,.bottomRight].contains(handle) { bottom = min(top-0.06,max(top-0.45,point.y)) }
        if [.top,.topLeft,.topRight].contains(handle) { top = min(bottom+0.45,max(bottom+0.06,point.y)) }
        width = right-left; height = top-bottom; center = [(left+right)/2,(bottom+top)/2]
    }
}

// TablePlaneSelector: table classification wins; floor/seat/ceiling are excluded by caller.
enum TablePlacement {
    struct Candidate { var transform: simd_float4x4; var halfSize: SIMD2<Float>; var boundary: [SIMD2<Float>] = []; var isTable: Bool }
    static func closest(_ point: SIMD2<Float>, boundary: [SIMD2<Float>], halfSize: SIMD2<Float>) -> SIMD2<Float> {
        guard boundary.count >= 3 else { return simd_clamp(point,-halfSize,halfSize) }
        var inside = false, nearest = point, distance = Float.infinity
        for i in boundary.indices {
            let a = boundary[(i+boundary.count-1)%boundary.count], b = boundary[i]
            if (a.y > point.y) != (b.y > point.y), point.x < (b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x { inside.toggle() }
            let edge = b-a, t = min(1,max(0,simd_dot(point-a,edge)/max(1e-10,simd_length_squared(edge))))
            let candidate = a+edge*t, d = simd_length_squared(candidate-point)
            if d < distance { distance = d; nearest = candidate }
        }
        return inside ? point : nearest
    }
    static func pose(head: simd_float4x4, candidates: [Candidate]) -> (transform: simd_float4x4, found: Bool) {
        let eyes = SIMD3(head.columns.3.x,head.columns.3.y,head.columns.3.z)
        var forward = SIMD3(-head.columns.2.x,0,-head.columns.2.z)
        forward = simd_length_squared(forward) > 0.00001 ? simd_normalize(forward) : [0,0,-1]
        let target = eyes+forward*0.5
        var position = target-SIMD3(0,0.45,0), found = false, bestTable = false, bestDistance = Float.infinity
        for candidate in candidates {
            let m = candidate.transform
            guard simd_dot(SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z),[0,1,0]) >= 0.95 else { continue }
            let local = simd_inverse(m)*SIMD4(target,1)
            let point = closest([local.x,local.z],boundary:candidate.boundary,halfSize:candidate.halfSize)
            let world = m*SIMD4(point.x,0,point.y,1), p = SIMD3(world.x,world.y,world.z)
            let drop = eyes.y-p.y, horizontal = SIMD3(p.x-eyes.x,0,p.z-eyes.z)
            guard drop >= 0.2, drop <= 1, simd_length(horizontal) <= 1.5,
                  simd_dot(simd_normalize(horizontal),forward) >= cos(40*Float.pi/180) else { continue }
            let distance = simd_length_squared(p-target)
            if found && ((bestTable && !candidate.isTable) || (bestTable == candidate.isTable && distance >= bestDistance)) { continue }
            found = true; bestTable = candidate.isTable; bestDistance = distance; position = p
        }
        let right = simd_normalize(simd_cross(forward,SIMD3<Float>(0,1,0)))
        return (simd_float4x4(columns:(SIMD4(right,0),[0,1,0,0],SIMD4(-forward,0),SIMD4(position+SIMD3(0,0.05,0),1))),found)
    }
}
