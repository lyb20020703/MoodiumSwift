import SwiftUI
import RealityKit

struct MoodiumSpace: View {
    @State private var opening = OpeningDirector()
    @State private var scene = NativeScene()
    @State private var tracking = SpatialTracking()
    var body: some View {
        RealityView { content, attachments in
            content.add(scene.root)
            scene.installVideo(opening.player)
            if let controls = attachments.entity(for: "openingControls") {
                controls.position = [0, 1.114, -1.325]
                let width = controls.visualBounds(relativeTo: nil).extents.x
                if width > 0 { controls.scale = .init(repeating: 1.08 / width) }
                scene.root.addChild(controls)
            }
            if let carousel = attachments.entity(for: "carouselControls") {
                carousel.position = [0, 1.38, -0.67]
                scene.carouselControls = carousel
                scene.root.addChild(carousel)
            }
            if let worldControls = attachments.entity(for:"worldControls") {
                worldControls.position = [0,1.05,-0.55]
                scene.root.addChild(worldControls)
            }
            opening.start()
        } update: { _, _ in
            scene.video?.isEnabled = opening.phase != .finished
            scene.carouselControls?.isEnabled = opening.phase == .finished && !scene.inWorld
        } attachments: {
            Attachment(id:"worldControls") {
                if scene.inWorld {
                    VStack {
                        HStack {
                            ForEach(SqueezeMode.allCases,id:\.self) { mode in
                                Button(mode.rawValue.capitalized) { scene.rescue.setMode(mode) }
                            }
                            Button("Return") { scene.leaveWorld() }
                        }
                        if let failure = scene.failure { Text(failure).font(.caption) }
                    }
                }
            }
            Attachment(id: "openingControls") {
                if opening.phase != .finished {
                    OpeningChoices(director: opening)
                }
            }
            Attachment(id: "carouselControls") {
                if opening.phase == .finished && !opening.hasBag && !scene.inWorld {
                    VStack {
                        HStack(spacing: 80) {
                            Button("‹") { scene.select(0) }
                            Text(scene.selection == 0 ? "Candy World" : "Nature World")
                            Button("›") { scene.select(1) }
                        }
                        WorldEntrySlider(nature:scene.selection == 1,english:opening.english) {
                            Task { await scene.enterWorld(nature:scene.selection == 1,english:opening.english) }
                        }.id(scene.selection)
                        if let error = scene.failure { Text(error).font(.caption) }
                    }
                }
            }
        }
        .task {
            tracking.onPlacement = { position, orientation in
                scene.root.position = [position.x, 0, position.z]
                scene.root.orientation = orientation
            }
            tracking.onHand = { hand in
                let source = hand.isLeft ? 1 : 2
                let candidates = [hand.joints[.indexFingerTip],hand.joints[.middleFingerTip],hand.joints[.wrist]].compactMap{$0}
                if let contact = candidates.first(where:{scene.rescue.contains(worldPosition:$0)}) {
                    scene.rescue.contact(source:source,position:contact)
                } else { scene.rescue.release(source:source) }
            }
            tracking.onHandLost = { left in scene.rescue.release(source:left ? 1 : 2,trackingLost:true) }
            await tracking.start()
        }
        .task(id: opening.phase) {
            if opening.phase == .finished {
                if opening.hasBag {
                    tracking.onImage = { anchor, tracked in
                        Task { @MainActor in await scene.updateSticker(anchor, tracked: tracked) }
                    }
                    await tracking.start(trackImages: true)
                } else { await scene.loadCarousel() }
            }
        }
        .gesture(DragGesture(minimumDistance:0).targetedToAnyEntity()
            .onChanged { value in
                guard scene.inWorld else { return }
                let position = value.convert(value.location3D,from:.local,to:.scene)
                scene.rescue.contact(source:100,position:position)
            }
            .onEnded { _ in scene.rescue.release(source:100) })
        .simultaneousGesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            if value.entity.name == "Unity Opening Video" { opening.activate() }
        })
        .onDisappear { opening.stop(); tracking.stop(); scene.stop() }
    }
}

private struct OpeningChoices: View {
    let director: OpeningDirector
    var body: some View {
        ZStack {
            if director.phase == .preview && director.elapsed >= 1 {
                Text("捏一下，打开惊喜\nPinch to discover the surprise")
                    .multilineTextAlignment(.center).offset(y: 234)
            }
            if director.phase == .language || director.showQuestion {
                Text(director.phase == .language ? "你更希望 Moodi 用哪种语言陪你探索？\nWhich language would you like Moodi to use?" :
                    (director.english ? "Do you have a Moodium sensory bag with you?" : "你手边有 Moodium 的感官袋吗？"))
                    .font(.system(size: director.phase == .language ? 36 : 30))
                    .multilineTextAlignment(.center).frame(width: 860).offset(y: -260)
                HStack(spacing: 0) {
                    if director.phase == .language {
                        art("lang_zh", title: "中文") { director.chooseLanguage(english: false) }
                        art("lang_en", title: "English") { director.chooseLanguage(english: true) }
                    } else {
                        art(director.english ? "bag_yes_en" : "bag_yes_zh", title: "Yes") { director.chooseBag(true) }
                        art(director.english ? "bag_no_en" : "bag_no_zh", title: "No") { director.chooseBag(false) }
                    }
                }.offset(y: 160)
            }
            if let failure = director.failure { Text(failure) }
        }.frame(width: 900, height: 680).disabled(director.choosing)
    }
    private func art(_ id: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let url = Bundle.main.url(forResource: "opening_btn_\(id)_idle", withExtension: "png", subdirectory: "Content/Opening"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().frame(width: 330, height: 187)
            } else { Text(title) }
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}
