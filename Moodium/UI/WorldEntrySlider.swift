import SwiftUI

/// Geometry, travel, completion threshold and original bitmap layers from Unity GlassSlideToEnter.
/// SwiftUI glass rendering still requires visual comparison with the original URP glass material.
struct WorldEntrySlider: View {
    let nature: Bool
    let english: Bool
    let completed: () -> Void
    @State private var progress: CGFloat = 0
    @State private var grabOffset: CGFloat?
    @State private var didComplete = false
    @State private var completionTask: Task<Void,Never>?
    private let travel: CGFloat = 212 // width - height, in the 1000 pt/m drawing space
    private var knobX: CGFloat { -106 + progress*travel }
    var body: some View {
        ZStack {
            art("slider_track_glow").frame(width:350,height:140.08)
            Capsule().fill(.ultraThinMaterial).frame(width:280,height:68)
            art("slider_track_tint").frame(width:280,height:68)
            art("slider_fill").frame(width:max(0.1,progress*travel+57.12),height:57.12)
                .offset(x:(progress-1)*travel/2)
            art("slider_track_rim").frame(width:280,height:68)
            Text(didComplete ? (english ? "Entering…" : "正在进入…") : (english ? (nature ? "Enter Nature World" : "Enter Candy World") : (nature ? "进入自然世界" : "进入糖果世界")))
                .font(.system(size:17,weight:.bold)).tracking(0.7)
                .offset(x:didComplete ? 0 : 28.56).opacity(didComplete ? 1 : max(0,1-progress*1.6))
            art("slider_knob_glow").frame(width:88,height:88).offset(x:knobX)
            art(nature ? "slider_knob_nature" : "slider_knob_candy").frame(width:57.12,height:57.12).offset(x:knobX)
            art(didComplete ? "slider_icon_check" : "slider_icon_arrow").frame(width:25.7,height:25.7).offset(x:knobX)
        }.frame(width:350,height:140.08)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance:0)
            .onChanged { value in
                guard !didComplete else { return }
                let x = value.location.x-175
                if grabOffset == nil { grabOffset = abs(x-knobX)<57.12*0.8 ? knobX-x : 0 }
                progress = min(1,max(0,(x+(grabOffset ?? 0)+106)/travel))
            }
            .onEnded { _ in
                guard !didComplete else { return }; grabOffset = nil
                if progress >= 0.9 {
                    didComplete = true
                    withAnimation(.easeOut(duration:0.2)) { progress = 1 }
                    completionTask = Task { @MainActor in
                        do { try await Task.sleep(for:.milliseconds(350)) } catch { return }
                        if !Task.isCancelled { completed() }
                    }
                } else { withAnimation(.interpolatingSpring(stiffness:404,damping:22)) { progress = 0 } }
            })
        .accessibilityLabel(english ? "Slide to enter world" : "滑动进入世界")
        .accessibilityAction { if !didComplete { didComplete = true; completed() } }
        .onDisappear { completionTask?.cancel() }
    }
    private func art(_ name:String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Slider"),let ui=UIImage(contentsOfFile:url.path) {
                Image(uiImage:ui).resizable()
            }
        }.allowsHitTesting(false)
    }
}
