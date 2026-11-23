import SwiftUI

struct EnergyRingView: View {
    let hud: WorldHUD
    let nature: Bool
    private var accent: Color { nature ? Color(red:85/255,green:196/255,blue:127/255) : Color(red:242/255,green:125/255,blue:182/255) }
    var body: some View {
        ZStack {
            art("energy_halo")
            ForEach(0..<40) { i in
                let head = i == hud.headIndex, lit = i < hud.litCount
                art(head ? "energy_dot_head" : lit ? "energy_dot_on" : "energy_dot_off")
                    .colorMultiply(lit ? accent : .white)
                    .scaleEffect(dotScale(i)).offset(point(i,radius:54))
            }
            ForEach(0..<4) { i in
                let reached = hud.litCount > [7,19,31,39][i]
                let age = hud.now-hud.giftAt[i]
                art(reached ? "energy_gem_full" : "energy_gem_empty")
                    .colorMultiply(reached ? accent : .white)
                    .scaleEffect(age >= 0 && age < 0.5 ? 1+0.5*sin(age/0.5 * .pi) : 1)
                    .offset(point([7,19,31,39][i],radius:67))
                ForEach(0..<2) { j in
                    let t = (age-Double(j)*0.12)/0.7
                    if t >= 0 && t < 1 {
                        art("energy_ripple").colorMultiply(accent).scaleEffect(0.5+1.1*ease(t))
                            .opacity(0.8*(1-t)).offset(point([7,19,31,39][i],radius:67))
                    }
                }
            }
            (Text("\(Int((hud.progress*100).rounded(.toNearestOrEven)))").font(.system(size:30,weight:.bold)) + Text("%").font(.system(size:14,weight:.bold)).foregroundColor(.white.opacity(0.72)))
                .foregroundStyle(.white)
        }.frame(width:200,height:200).allowsHitTesting(false)
            .scaleEffect(0.9+0.1*ease((hud.now-hud.shownAt)/0.4))
    }
    private func point(_ i: Int,radius: Double) -> CGSize {
        let a = (90-Double(i+1)*9)*Double.pi/180
        return CGSize(width:cos(a)*radius,height:-sin(a)*radius)
    }
    private func ease(_ x: Double) -> Double { let t = min(1,max(0,x)); return t*t*(3-2*t) }
    private func dotScale(_ i: Int) -> Double {
        var scale = 1+0.8*(1-ease((hud.now-hud.dotAt[i])/0.35))
        if i == hud.headIndex { scale *= 1+0.075*(1+sin(hud.now * .pi*2/1.6)) }
        if let full = hud.fullAt { let age = hud.now-full-Double(i)*0.8/40; if age >= 0 && age < 0.12 { scale *= 1+0.4*sin(age/0.12 * .pi) } }
        return scale
    }
    private func art(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Progress"),let image = UIImage(contentsOfFile:url.path) {
                // Original sprites were exported at 1.5x design pixels.
                Image(uiImage:image).resizable().frame(width:image.size.width/1.5,height:image.size.height/1.5)
            }
        }
    }
}

struct WorldDockView: View {
    let hud: WorldHUD
    let english: Bool
    let exit: () -> Void
    var body: some View {
        Button { hud.pressExit(exit) } label: { Color.clear.frame(width:200,height:74) }
            .buttonStyle(DockArtStyle(english:english)).disabled(!hud.canPress)
            .accessibilityLabel(english ? "Exit World" : "退出世界")
    }
}
private struct DockArtStyle: ButtonStyle {
    let english: Bool
    func makeBody(configuration: Configuration) -> some View {
        let name = "dock_exit_\(english ? "en" : "zh")_\(configuration.isPressed ? "pressed" : "idle")"
        if let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Dock"),let image = UIImage(contentsOfFile:url.path) {
            Image(uiImage:image).resizable().frame(width:200,height:74).contentShape(Capsule())
        }
    }
}
