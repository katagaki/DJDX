import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum Mode: String, CaseIterable, Identifiable {
    case edit = "Edit"
    case inspect = "Inspect"
    case python = "Python"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .edit
    @State private var confirmExport = false
    @State private var confirmPromote = false
    @State private var confirmClearAll = false

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
        .confirmationDialog("Export CoreML model?", isPresented: $confirmExport) {
            Button("Export Model") { model.exportCoreMLModel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves labels, then runs prepare → train → export in Training/ "
                 + "into the evaluation model. Promote it once it looks good. "
                 + "This can take several minutes.")
        }
        .confirmationDialog("Promote evaluation model to production?", isPresented: $confirmPromote) {
            Button("Promote Model") { model.promoteEvalToProduction() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replaces the production model used by Label current / Auto label all "
                 + "with the current evaluation model.")
        }
        .confirmationDialog("Clear all data?", isPresented: $confirmClearAll) {
            Button("Clear All Labels", role: .destructive) { model.clearAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every label and deletes labels.json. This cannot be undone.")
        }
    }

    @ViewBuilder private var content: some View {
        if model.config.labelKind == .classification {
            ClassifierView()
        } else {
            switch mode {
            case .edit:
                LabelEditorView(trailingInset: 244)
                    .overlay(alignment: .trailing) {
                        ClassPaletteView()
                            .frame(width: 220)
                            .padding(12)
                    }
            case .inspect:
                OutputInspectorView()
            case .python:
                PythonRunnerView()
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Workspace", selection: Binding(
                get: { model.workspace },
                set: { model.switchWorkspace($0) })) {
                ForEach(Workspace.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        if model.config.labelKind == .bbox {
            ToolbarItem(placement: .navigation) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }

        // Labelling
        ToolbarItemGroup {
            Button {
                Task { await model.autoLabelCurrent() }
            } label: { Label("Label current", systemImage: "text.viewfinder") }
                .disabled(model.isAutoLabeling || model.currentImageURL == nil)
                .help("Label the current image with the trained model (falls back to Vision OCR)")

            Button {
                Task { await model.autoLabelAll() }
            } label: { Label("Auto label all", systemImage: "rectangle.stack.badge.play") }
                .disabled(model.isAutoLabeling || model.images.isEmpty)
                .help("Label every image with the trained model (falls back to Vision OCR)")

            Button { model.clearCurrentLabels() } label: {
                Label("Remove current labels", systemImage: "rectangle.badge.xmark")
            }
            .disabled(model.currentBoxes.isEmpty)
            .help("Remove all labels on the current image")

            if model.isAutoLabeling { ProgressView().controlSize(.small) }
        }

        ToolbarSpacer(.fixed)

        // Save / reload labels
        ToolbarItemGroup {
            Button { model.save() } label: {
                Label("Save to labels.json", systemImage: "square.and.arrow.down")
            }
            .help("Save labels to labels.json (⌘S)")

            Button { chooseLabelsFile() } label: {
                Label("Load new labels.json", systemImage: "tray.and.arrow.down")
            }
            .help("Load labels from a chosen labels.json file")
        }

        ToolbarSpacer(.fixed)

        // CoreML model
        ToolbarItemGroup {
            Button { confirmExport = true } label: {
                Label("Export CoreML model", systemImage: "cpu")
            }
            .disabled(model.isBuildingModel || model.paths == nil)
            .help("Run prepare → train → export to build the evaluation CoreML model")

            Button { confirmPromote = true } label: {
                Label("Promote evaluation model to production model", systemImage: "arrow.up.circle")
            }
            .disabled(model.isBuildingModel || !model.hasEvalModel)
            .help("Make the evaluation model the production model used by Label current / Auto label all")

            Button { revealModelLocation() } label: {
                Label("Open file location", systemImage: "arrow.up.right.square")
            }
            .disabled(model.paths == nil)
            .help("Reveal the exported model in Finder")

            if model.isBuildingModel { ProgressView().controlSize(.small) }
        }

        ToolbarSpacer(.fixed)

        // Disk operations
        ToolbarItemGroup {
            Button { chooseFolder() } label: { Label("Select project folder", systemImage: "folder") }
                .help("Choose a different project folder")

            Button(role: .destructive) { confirmClearAll = true } label: {
                Label("Clear all data", systemImage: "trash")
            }
            .help("Remove every label and delete labels.json")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private var onboarding: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Choose your DJDX PEAK project folder")
                .font(.title3)
            Text("The folder that contains Inputs/, Outputs/, and Training/.")
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

    private func chooseLabelsFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.directoryURL = model.paths?.labelsDir
        panel.prompt = "Load"
        if panel.runModal() == .OK, let url = panel.url {
            model.importLabels(from: url)
        }
    }

    private func revealModelLocation() {
        guard let p = model.paths else { return }
        let modelURL = p.modelURL(named: model.config.productionModelName)
        let target = FileManager.default.fileExists(atPath: modelURL.path) ? modelURL : p.outputDir
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }
}
