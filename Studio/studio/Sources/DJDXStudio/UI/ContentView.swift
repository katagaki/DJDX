import SwiftUI
import AppKit

enum Mode: String, CaseIterable, Identifiable {
    case edit = "Edit"
    case inspect = "Inspect"
    case python = "Python"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .edit

    var body: some View {
        Group {
            if model.paths?.looksValid == true {
                main
            } else {
                onboarding
            }
        }
    }

    private var main: some View {
        NavigationSplitView {
            ImageListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            VStack(spacing: 0) {
                content
                Divider()
                statusBar
            }
        }
        .toolbar { toolbar }
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .edit:
            HStack(spacing: 0) {
                LabelEditorView()
                Divider()
                ClassPaletteView()
                    .frame(width: 220)
            }
        case .inspect:
            OutputInspectorView()
        case .python:
            PythonRunnerView()
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        ToolbarItemGroup {
            Button {
                Task { await model.autoLabelCurrent() }
            } label: { Label("Auto-label", systemImage: "text.viewfinder") }
                .disabled(model.isAutoLabeling || model.currentImageURL == nil)

            Button {
                Task { await model.autoLabelAll() }
            } label: { Label("Auto-label all", systemImage: "rectangle.stack.badge.play") }
                .disabled(model.isAutoLabeling || model.images.isEmpty)

            if model.isAutoLabeling { ProgressView().controlSize(.small) }

            Button { model.save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
            Button { model.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
            Button { chooseFolder() } label: { Label("Project", systemImage: "folder") }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(model.status).font(.caption).foregroundStyle(.secondary)
            Spacer()
            if let err = model.loadError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
    }

    private var onboarding: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Choose your DJDX PEAK project folder")
                .font(.title3)
            Text("The folder that contains data/ and training/.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Choose Folder…") { chooseFolder() }
                .controlSize(.large)
            if let err = model.loadError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            model.configure(root: url)
        }
    }
}
