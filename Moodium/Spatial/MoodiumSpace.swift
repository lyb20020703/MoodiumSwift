import SwiftUI
import RealityKit

struct MoodiumSpace: View {
    @State private var opening = OpeningDirector()
    @State private var scene = NativeScene()
    @State private var tracking = SpatialTracking()
    @State private var journal = MoodJournal()
    @State private var showMood = false
    @State private var postMood = false
    @State private var visitDuration = 0.0
    @State private var visitPresses = 0
    @State private var visitWorld: String?
    @State private var showSettings = false
    @AppStorage("Moodium.ProgressPace") private var pace = 0
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
            if let modes = attachments.entity(for:"modes") {
                scene.hud.modes = modes; scene.root.addChild(modes)
                let width = modes.visualBounds(relativeTo:modes).extents.x
                if width > 0 { modes.scale = SIMD3(repeating:0.25/width) }
                modes.isEnabled = false
            }
            if let mood = attachments.entity(for:"moodPlate") { mood.position = [0,1.25,-0.85]; scene.root.addChild(mood) }
            if let ring = attachments.entity(for:"energyRing") {
                scene.hud.ring = ring; scene.root.addChild(ring)
                let width = ring.visualBounds(relativeTo:ring).extents.x
                if width > 0 { ring.scale = SIMD3(repeating:Float(200*0.42/520)/width) }
                ring.isEnabled = false
            }
            if let dock = attachments.entity(for:"worldDock") {
                scene.hud.dock = dock; scene.root.addChild(dock)
                let width = dock.visualBounds(relativeTo:dock).extents.x
                if width > 0 { dock.scale = SIMD3(repeating:0.10/width) }
                dock.isEnabled = false
            }
            if let controls = attachments.entity(for:"calibration") {
                scene.calibrator.controls = controls; scene.root.addChild(controls)
                let width = controls.visualBounds(relativeTo:controls).extents.x
                if width > 0 { controls.scale = SIMD3(repeating:0.22/width) }
                controls.isEnabled = false
            }
            if let errors = attachments.entity(for:"errors") { errors.position = [0,1.3,-0.7]; scene.root.addChild(errors) }
            opening.start()
        } update: { _, _ in
            scene.video?.isEnabled = opening.phase != .finished
            scene.carouselControls?.isEnabled = opening.phase == .finished && !scene.inWorld
        } attachments: {
            Attachment(id:"errors") {
                if let failure = scene.failure ?? tracking.failure {
                    VStack {
                        Text(failure)
                        if scene.inWorld { Button(opening.english ? "Return" : "返回",action:leaveWorld) }
                    }.padding().glassBackgroundEffect()
                }
            }
            Attachment(id:"calibration") {
                CalibrationControls(calibrator:scene.calibrator,english:opening.english,nature:scene.selection == 1,confirm:{ Task { await scene.confirmCalibration(english:opening.english) } },cancel:scene.cancelCalibration)
            }
            Attachment(id:"energyRing") { EnergyRingView(hud:scene.hud,nature:scene.enteredWorld == "nature") }
            Attachment(id:"worldDock") { WorldDockView(hud:scene.hud,english:opening.english,exit:leaveWorld) }
            Attachment(id:"moodPlate") {
                if showMood {
                    MoodPlate(english:opening.english,post:postMood) { point in
                        let mood = journal.save(point,phase:postMood ? "post" : "pre",world:visitWorld,duration:visitDuration,presses:visitPresses)
                        guard journal.failure == nil else { return }
                        if !postMood { scene.selectedMood = mood; scene.select(mood.world == "nature" ? 1 : 0) }
                        showMood = false
                    } cancel: { showMood = false }
                    if let error = journal.failure { Text(error).foregroundStyle(.red) }
                }
            }
            Attachment(id:"modes") {
                ModeButtonRow(rescue:scene.rescue,hud:scene.hud,recommended:scene.selectedMood?.mode ?? .free,nature:scene.enteredWorld == "nature",english:opening.english)
            }
            Attachment(id: "openingControls") {
                if opening.phase != .finished {
                    OpeningChoices(director: opening)
                }
            }
            Attachment(id: "carouselControls") {
                if opening.phase == .finished && !scene.inWorld && !showMood {
                    if scene.preparing {
                        if !scene.calibrator.active { Text(opening.english ? "Looking for a table…" : "正在寻找桌面…") }
                    } else if opening.hasBag {
                        if scene.stickerSelection != nil {
                            WorldEntrySlider(nature:scene.selection == 1,english:opening.english) { Task { await scene.enterSticker(english:opening.english) } }.id(scene.stickerSelection)
                        } else { Text(opening.english ? "Look at the sticker on your sensory bag" : "请看向感官袋上的贴纸") }
                    } else {
                    VStack {
                        HStack(spacing: 80) {
                            Button("‹") { scene.select(0) }
                            Text(scene.selection == 0 ? "Candy World" : "Nature World")
                            Button("›") { scene.select(1) }
                        }
                        Button(opening.english ? "Not sure? Check your mood" : "不知道选哪个？测测心情") {
                            postMood = false; visitWorld = nil; visitDuration = 0; visitPresses = 0; showMood = true
                        }
                        Button(opening.english ? "Settings" : "设置") { showSettings.toggle() }
                        if showSettings {
                            Toggle(opening.english ? "Ask language" : "询问语言",isOn:Binding(get:{UserDefaults.standard.object(forKey:"Moodium.Opening.AskLanguage") as? Bool ?? true},set:{UserDefaults.standard.set($0,forKey:"Moodium.Opening.AskLanguage")}))
                            Toggle(opening.english ? "Ask about sensory bag" : "询问感官袋",isOn:Binding(get:{UserDefaults.standard.object(forKey:"Moodium.Opening.AskBag") as? Bool ?? true},set:{UserDefaults.standard.set($0,forKey:"Moodium.Opening.AskBag")}))
                            Picker(opening.english ? "Pace" : "进度快慢",selection:$pace) { Text("×1").tag(0);Text("×2").tag(1);Text("×4").tag(2) }
                        }
                        WorldEntrySlider(nature:scene.selection == 1,english:opening.english) {
                            Task { await scene.prepareTable(tracking:tracking) }
                        }.id(scene.selection)
                        if let error = scene.failure { Text(error).font(.caption) }
                    }
                    }
                }
            }
        }
        .onChange(of:pace) { _, value in scene.rescue.setPace(value) }
        .task {
            tracking.onPlacement = { position, orientation in
                scene.root.position = [position.x, 0, position.z]
                scene.root.orientation = orientation
            }
            tracking.onDevice = { transform in
                scene.hud.device(transform)
                if scene.calibrator.active, let controls = scene.calibrator.controls {
                    let eyes = SIMD3(transform.columns.3.x,transform.columns.3.y,transform.columns.3.z)
                    controls.look(at:eyes,from:controls.position(relativeTo:nil),relativeTo:nil,forward:.positiveZ)
                    let pose = tracking.tablePose()
                    if pose.found { scene.calibrator.relocate(pose.transform) }
                }
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
                let position = value.convert(value.location3D,from:.local,to:.scene)
                if scene.calibrator.move(entity:value.entity,worldPosition:position) { return }
                guard scene.inWorld, scene.rescue.owns(value.entity) else { return }
                scene.rescue.contact(source:100,position:position)
            }
            .onEnded { _ in scene.calibrator.endDrag(); scene.rescue.release(source:100) })
        .simultaneousGesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            if value.entity.name == "Unity Opening Video" { opening.activate() }
        })
        .onDisappear { opening.stop(); tracking.stop(); scene.stop() }
    }
    private func leaveWorld() {
        let shouldAsk = scene.journey.stage == .explore && scene.selectedMood != nil
        visitDuration = scene.visitStarted.map { Date().timeIntervalSince($0) } ?? 0
        visitPresses = scene.rescue.energy.presses; visitWorld = scene.enteredWorld
        scene.leaveWorld()
        if shouldAsk { postMood = true; showMood = true }
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
        }.buttonStyle(OpeningArtStyle(id:id)).accessibilityLabel(title)
    }
}

private struct OpeningArtStyle: ButtonStyle {
    let id: String
    func makeBody(configuration: Configuration) -> some View {
        let name = "opening_btn_\(id)_\(configuration.isPressed ? "pressed" : "idle")"
        if let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"Content/Opening"),let image = UIImage(contentsOfFile:url.path) {
            Image(uiImage:image).resizable().frame(width:330,height:187)
        } else { configuration.label }
    }
}
