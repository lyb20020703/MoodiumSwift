import SwiftUI

struct ModeButtonRow: View {
    let rescue: RescueWorld
    let hud: WorldHUD
    let recommended: SqueezeMode
    let nature: Bool
    let english: Bool
    private var accent: Color { nature ? Color(red:111/255,green:211/255,blue:154/255) : Color(red:1,green:141/255,blue:199/255) }
    var body: some View {
        ZStack {
            ForEach(Array(SqueezeMode.allCases.enumerated()),id:\.element) { index,mode in
                let selected = rescue.energy.mode == mode
                Button {
                    guard rescue.energy.energy < 100, rescue.energy.mode != mode else { return }
                    // Explicit selection cancels mood tuning, as SqueezeModeState.ManualOverride does.
                    rescue.setMode(mode)
                } label: {
                    ZStack {
                        art("mode_btn_selected_glow",width:80).colorMultiply(accent).opacity(selected ? 1 : 0)
                        art("mode_btn_base",width:80)
                        art("mode_icon_"+mode.rawValue,width:30).colorMultiply(selected ? accent : .white).opacity(selected ? 1 : 0.55)
                        art("mode_label_\(mode.rawValue)_\(english ? "en" : "cn")",width:75)
                            .colorMultiply(selected ? accent : Color(white:0.85)).opacity(selected ? 1 : 0.6).offset(y:56)
                        if mode == recommended { Circle().fill(accent).frame(width:6,height:6).offset(x:-27,y:-25) }
                    }.frame(width:80,height:80).contentShape(Circle()).scaleEffect(selected ? 1.04 : 1)
                }.buttonStyle(ModePressStyle()).offset(x:Double(index-1)*85)
            }
        }.frame(width:250,height:160)
            .disabled(rescue.energy.energy >= 100 || hud.now-hud.shownAt < 1)
    }
    private func art(_ name: String,width: CGFloat) -> some View {
        Group {
            if let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Modes"),let image = UIImage(contentsOfFile:url.path) {
                Image(uiImage:image).resizable().aspectRatio(contentMode:.fit).frame(width:width)
            }
        }
    }
}
private struct ModePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1) }
}
