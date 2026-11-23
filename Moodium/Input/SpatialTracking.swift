import ARKit
import QuartzCore
import Observation
import simd
import UIKit

@Observable @MainActor
final class SpatialTracking {
    struct HandFrame {
        let isLeft: Bool
        let joints: [HandSkeleton.JointName: SIMD3<Float>]
        let closure: Float?
    }
    private(set) var failure: String?
    @ObservationIgnored private let session = ARKitSession()
    @ObservationIgnored private var world: WorldTrackingProvider?
    @ObservationIgnored private var hands: HandTrackingProvider?
    @ObservationIgnored private var images: ImageTrackingProvider?
    @ObservationIgnored var onImage: ((ImageAnchor, Bool) -> Void)?
    @ObservationIgnored private var tasks: [Task<Void,Never>] = []
    @ObservationIgnored private var openDistance: [Bool: Float] = [:]
    @ObservationIgnored var onHand: ((HandFrame) -> Void)?
    @ObservationIgnored var onHandLost: ((Bool) -> Void)?
    @ObservationIgnored var onPlacement: ((SIMD3<Float>, simd_quatf) -> Void)?

    func start(trackImages: Bool = false) async {
        stop(); failure = nil
        guard WorldTrackingProvider.isSupported else { return }
        let world = WorldTrackingProvider(); self.world = world
        var providers: [any DataProvider] = [world]
        if HandTrackingProvider.isSupported {
            let hands = HandTrackingProvider(); self.hands = hands; providers.append(hands)
        }
        if trackImages && ImageTrackingProvider.isSupported {
            let references = ["CandyWorldPhoneTracking", "NatureWorldPhoneTracking"].compactMap { name -> ReferenceImage? in
                guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Content/Tracking"),
                      let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
                var reference = ReferenceImage(cgimage: image, physicalSize: CGSize(width: 0.05,height: 0.05))
                reference.name = name; return reference
            }
            guard references.count == 2 else { failure = "World tracking images are missing."; return }
            let images = ImageTrackingProvider(referenceImages: references)
            self.images = images; providers.append(images)
        }
        do {
            try await session.run(providers)
            if let images {
                tasks.append(Task { @MainActor [weak self] in
                    for await update in images.anchorUpdates {
                        guard let self, !Task.isCancelled else { return }
                        self.onImage?(update.anchor, update.event != .removed && update.anchor.isTracked)
                    }
                })
            }
            tasks.append(Task { @MainActor [weak self] in
                guard let self else { return }
                // Wait for the first tracked pose; keep the resulting content world-locked.
                while !Task.isCancelled {
                    if let anchor = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), anchor.isTracked {
                        let m = anchor.originFromAnchorTransform
                        let p = SIMD3(m.columns.3.x,m.columns.3.y,m.columns.3.z)
                        var forward = SIMD3(-m.columns.2.x,0,-m.columns.2.z)
                        if simd_length_squared(forward) < 0.001 { forward = [0,0,-1] }
                        forward = simd_normalize(forward)
                        let orientation = simd_quatf(from: SIMD3<Float>(0,0,-1), to: forward)
                        self.onPlacement?(p,orientation); break
                    }
                    do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                }
            })
            if let hands {
                tasks.append(Task { @MainActor [weak self] in
                    for await update in hands.anchorUpdates {
                        guard let self, !Task.isCancelled else { return }
                        let left = update.anchor.chirality == .left
                        guard update.event != .removed, update.anchor.isTracked, let skeleton = update.anchor.handSkeleton else {
                            self.onHandLost?(left); continue
                        }
                        var joints: [HandSkeleton.JointName: SIMD3<Float>] = [:]
                        for joint in skeleton.allJoints where joint.isTracked {
                            let m = update.anchor.originFromAnchorTransform * joint.anchorFromJointTransform
                            joints[joint.name] = [m.columns.3.x,m.columns.3.y,m.columns.3.z]
                        }
                        var closure: Float?
                        let tips: [HandSkeleton.JointName] = [.thumbTip,.indexFingerTip,.middleFingerTip,.ringFingerTip,.littleFingerTip]
                        if let wrist = joints[.wrist], let middle = joints[.middleFingerMetacarpal], tips.allSatisfy({joints[$0] != nil}) {
                            let palm = (wrist+middle)*0.5
                            let distance = tips.reduce(Float(0)) { $0+simd_distance(joints[$1]!,palm)/5 }
                            if distance > 0.065 { self.openDistance[left] = max(self.openDistance[left] ?? 0,distance) }
                            if let open = self.openDistance[left], open > 0.065 { closure = min(1,max(0,1-distance/open)) }
                        }
                        self.onHand?(.init(isLeft:left,joints:joints,closure:closure))
                    }
                })
            }
        } catch { failure = error.localizedDescription }
    }
    func stop() {
        for task in tasks { task.cancel() }; tasks.removeAll()
        session.stop(); world = nil; hands = nil; images = nil
        onHandLost?(true); onHandLost?(false); openDistance.removeAll()
    }
}
