import SwiftUI
import RealityKit

@main
struct MoodiumApp: App {
    @State private var session = SpatialSession()
    var body: some SwiftUI.Scene {
        WindowGroup(id:"launch") {
            LaunchEntry().environment(session)
        }
        .defaultSize(width:420,height:220)
        ImmersiveSpace(id: "MoodiumWorld") {
            MoodiumSpace()
            .onAppear { session.phase = .open }
            .onDisappear { session.phase = .closed }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

@Observable @MainActor
final class SpatialSession {
    enum Phase { case closed, opening, open, closing }
    var phase: Phase = .closed
    var message = ""
}

struct LaunchEntry: View {
    @Environment(SpatialSession.self) private var session
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    var body: some View {
        VStack(spacing: 20) {
            Text("Moodium").font(.title)
            Text("A little space to feel better.").foregroundStyle(.secondary)
            Button(session.phase == .open ? "Close space" : "Open space") {
                Task { @MainActor in
                    if session.phase == .open {
                        session.phase = .closing
                        await dismissSpace()
                        session.phase = .closed
                    } else {
                        session.phase = .opening
                        switch await openSpace(id: "MoodiumWorld") {
                        case .opened: session.phase = .open; session.message = ""; dismissWindow(id:"launch")
                        case .userCancelled: session.phase = .closed
                        case .error: session.phase = .closed; session.message = "Unable to open space. Please try again."
                        @unknown default: session.phase = .closed
                        }
                    }
                }
            }.disabled(session.phase == .opening || session.phase == .closing)
            if !session.message.isEmpty { Text(session.message) }
        }.padding(40)
        .task {
            guard session.phase == .closed else { return }
            session.phase = .opening
            switch await openSpace(id:"MoodiumWorld") {
            case .opened: session.phase = .open; dismissWindow(id:"launch")
            case .userCancelled: session.phase = .closed
            case .error: session.phase = .closed; session.message = "Unable to open space. Please try again."
            @unknown default: session.phase = .closed
            }
        }
    }
}
