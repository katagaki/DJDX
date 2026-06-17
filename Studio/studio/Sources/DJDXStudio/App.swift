import SwiftUI

@main
struct DJDXStudioApp: App {
    @State private var model = AppModel()

    init() {
        SelfTest.runIfRequested()
        let root = ProjectRootStore.load() ?? ProjectRootStore.fallback
        let m = model
        if ProjectPaths(root: root).looksValid {
            m.configure(root: root)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("Save Labels") { model.save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.undo() }
                    .keyboardShortcut("z", modifiers: .command)
            }
            CommandMenu("Image") {
                Button("Next") { model.next() }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("Previous") { model.prev() }.keyboardShortcut(.leftArrow, modifiers: [])
            }
        }
    }
}
