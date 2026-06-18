import SwiftUI

@main
struct DJDXStudioApp: App {
    @State private var model = AppModel()

    init() {
        SelfTest.runIfRequested()
        let m = model
        // Prefer a saved root, but ignore it if it no longer validates (e.g. an
        // older layout from before the Inputs/Training restructure), then try
        // the default location.
        let candidates = [ProjectRootStore.load(), ProjectRootStore.fallback].compactMap { $0 }
        if let root = candidates.first(where: { ProjectPaths(root: $0).looksValid }) {
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
                Divider()
                Button("Delete Label") { model.deleteSelected() }
                    .keyboardShortcut(.delete, modifiers: [])
                    .disabled(model.selectedBoxID == nil)
            }
        }
    }
}
