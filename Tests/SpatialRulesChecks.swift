import Foundation
import simd

@main struct SpatialRulesChecks {
    static func main() {
        var bag = BagCalibration()
        bag.resize(.left,to:[10,0])
        assert(abs(bag.width-0.08)<0.0001 && abs(bag.center.x+bag.width/2-0.2)<0.0001)
        bag.resize(.bottomRight,to:[10,-10])
        assert(abs(bag.width-0.6)<0.0001 && abs(bag.height-0.45)<0.0001)
        bag.setPlaneHeight(.nan); assert(bag.planeHeight == -0.08)
        bag.setPlaneHeight(-10); assert(bag.planeHeight == -0.25)
        var head = matrix_identity_float4x4; head.columns.3.y = 1.5
        let fallback = TablePlacement.pose(head:head,candidates:[])
        assert(!fallback.found && abs(fallback.transform.columns.3.y-1.10)<0.0001)
        var table = matrix_identity_float4x4; table.columns.3 = [0,0.8,-0.6,1]
        let selected = TablePlacement.pose(head:head,candidates:[.init(transform:table,halfSize:[0.3,0.3],isTable:true)])
        assert(selected.found && abs(selected.transform.columns.3.y-0.85)<0.0001)
        let triangle: [SIMD2<Float>] = [[0,0],[1,0],[0,1]]
        let edge = TablePlacement.closest([1,1],boundary:triangle,halfSize:[1,1])
        assert(simd_distance(edge,[0.5,0.5])<0.0001)
        print("Spatial rules checks passed")
    }
}
