import Foundation
import simd

// Pure geometry rules from CalibratedSensoryBagPresentation and SoftTouchDeformationController.
enum SoftGeometry {
    static func fit(width: Float, height: Float, extents: SIMD3<Float>, authoredScale: SIMD3<Float> = .one) -> SIMD3<Float> {
        let x = width / max(0.0001,extents.x*abs(authoredScale.x))
        let z = height / max(0.0001,extents.z*abs(authoredScale.z))
        return [x,sqrt(max(0.0001,x*z)),z]
    }
    static func falloff(distance: Float, radius: Float) -> Float {
        let w = 1-min(1,max(0,distance/max(0.0001,radius)))
        return w*w*(3-2*w)
    }
    static func muffle(progress: Float) -> Float {
        let x = min(1,max(0,progress/0.85))
        return 1-x*x*(3-2*x)
    }
}
