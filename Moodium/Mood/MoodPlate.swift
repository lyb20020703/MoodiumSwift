import SwiftUI

/// Native interaction for the Unity valence/arousal plate. Exact visual assets/layout remain under comparison.
struct MoodPlate: View {
    let english: Bool
    var post = false
    let confirm: (SIMD2<Float>) -> Void
    let cancel: () -> Void
    @State private var point = SIMD2<Float>.zero
    var body: some View {
        VStack(spacing:18) {
            Text(english ? (post ? "And now?" : "How are you feeling right now?") : (post ? "现在呢？" : "你现在的心情怎么样？")).font(.title2)
            Text(english ? "Drag Moodi, or tap a mood" : "拖动 Moodi，或直接点一个心情")
            ZStack {
                Circle().fill(AngularGradient(colors:[.pink,.orange,.green,.blue,.purple,.pink],center:.center)).opacity(0.35)
                Path { p in p.move(to:.init(x:140,y:0));p.addLine(to:.init(x:140,y:280));p.move(to:.init(x:0,y:140));p.addLine(to:.init(x:280,y:140)) }.stroke(.white.opacity(0.3))
                Text("Moodi").font(.headline).padding(12).background(.ultraThinMaterial,in:Capsule()).offset(x:CGFloat(point.x)*120,y:-CGFloat(point.y)*120)
            }.frame(width:280,height:280).contentShape(Circle())
            .gesture(DragGesture(minimumDistance:0).onChanged { v in
                var x = Float((v.location.x-140)/120), y = Float((140-v.location.y)/120)
                let length = sqrt(x*x+y*y); if length > 1 { x /= length; y /= length }
                point = [x,y]
            })
            HStack { ForEach(MoodKind.allCases,id:\.self) { mood in Button(mood.label(english:english)) { point = mood.preset } } }
            Text(MoodRules.classify(point).label(english:english))
            HStack { Button(english ? "Skip" : "跳过",action:cancel);Button(english ? "That's right" : "对") { confirm(point) } }
        }.padding(28).glassBackgroundEffect()
    }
}
