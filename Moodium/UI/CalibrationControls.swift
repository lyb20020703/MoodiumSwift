import SwiftUI

struct CalibrationControls: View {
    let calibrator: BagCalibrator
    let english: Bool
    let nature: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    var body: some View {
        VStack(spacing:12) {
            ZStack {
                art("calib_card_dark").frame(width:440,height:80)
                HStack(spacing:14) {
                    art(nature ? "calib_flat_icon_nature" : "calib_flat_icon_candy").frame(width:88,height:56)
                    Text(english ? "Keep the frame flat on the table" : "让边框平放在桌面上").font(.system(size:19,weight:.bold))
                }.padding(.horizontal,16)
            }
            HStack(spacing:10) {
                action(english ? "Reset" : "重置",icon:"calib_icon_reset",primary:false) { calibrator.reset() }
                action(english ? "Confirm" : "确认",icon:"calib_icon_check",primary:true,action:confirm)
            }
            HStack(spacing:12) {
                Button("−") { calibrator.height(-0.005) }
                Text(String(format:"%+.1f cm",calibrator.data.planeHeight*100))
                Button("+") { calibrator.height(0.005) }
                Button("↶") { calibrator.rotate(-5) }
                Button("↷") { calibrator.rotate(5) }
                Button(english ? "Cancel" : "取消",action:cancel)
            }.font(.system(size:18))
            if let failure = calibrator.failure { Text(failure) }
        }.frame(width:440).foregroundStyle(.white)
    }
    private func action(_ title: String,icon: String,primary: Bool,action: @escaping () -> Void) -> some View {
        Button(action:action) {
            HStack(spacing:8) { art(icon).frame(width:17,height:17); Text(title).font(.system(size:18,weight:.bold)) }
                .padding(.horizontal,22).frame(height:46)
                .background { art(primary ? "calib_btn_primary" : "calib_card_dark") }
        }.buttonStyle(.plain)
    }
    private func art(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Calibration"),let image = UIImage(contentsOfFile:url.path) { Image(uiImage:image).resizable() }
        }
    }
}
