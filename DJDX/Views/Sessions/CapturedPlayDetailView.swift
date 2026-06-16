import SwiftUI

struct CapturedPlayDetailView: View {
    var store: SessionStore
    var play: CapturedPlay

    @Environment(\.dismiss) private var dismiss

    @State private var songTitle: String = ""
    @State private var level: IIDXLevel = .unknown
    @State private var difficulty: Int = 0
    @State private var playType: IIDXPlayType = .single
    @State private var exScore: Int = 0
    @State private var perfectGreat: Int = 0
    @State private var great: Int = 0
    @State private var miss: Int = 0
    @State private var clearType: IIDXClearType = .noPlay
    @State private var djLevel: IIDXDJLevel = .none

    var body: some View {
        Form {
            Section {
                if let image = SessionImageStore.shared.image(for: play.rawImageFilename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .listRowInsets(EdgeInsets())
                }
            }

            Section("Sessions.Detail.Status") {
                LabeledContent("Sessions.Detail.State") {
                    Text(verbatim: statusText)
                }
                LabeledContent("Sessions.Detail.Confidence") {
                    Text(play.ocrConfidence, format: .percent.precision(.fractionLength(0)))
                }
                if let parseError = play.parseError {
                    LabeledContent("Sessions.Detail.Error") {
                        Text(verbatim: parseError)
                            .foregroundStyle(.red)
                    }
                }
            }

            if let recognizedText = SessionImageStore.shared.ocrText(id: play.id), !recognizedText.isEmpty {
                Section("Sessions.Detail.RecognizedText") {
                    DisclosureGroup("Sessions.Detail.ShowText") {
                        Text(verbatim: recognizedText)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Sessions.Detail.Chart") {
                TextField("Sessions.Detail.Song", text: $songTitle)
                Picker("Shared.Level", selection: $level) {
                    ForEach(IIDXLevel.sorted, id: \.self) { value in
                        Text(verbatim: levelName(value)).tag(value)
                    }
                }
                Picker("Shared.Difficulty", selection: $difficulty) {
                    Text(verbatim: "—").tag(0)
                    ForEach(IIDXDifficulty.sortedInts, id: \.self) { value in
                        Text(verbatim: "☆\(value)").tag(value)
                    }
                }
                Picker("Shared.PlayType", selection: $playType) {
                    Text(verbatim: "SP").tag(IIDXPlayType.single)
                    Text(verbatim: "DP").tag(IIDXPlayType.double)
                }
            }

            Section("Sessions.Detail.Result") {
                Picker("Sessions.Detail.ClearType", selection: $clearType) {
                    ForEach(IIDXClearType.sorted, id: \.self) { value in
                        Text(verbatim: value.rawValue).tag(value)
                    }
                }
                Picker("Sessions.Detail.DJLevel", selection: $djLevel) {
                    ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { value in
                        Text(verbatim: value.rawValue).tag(value)
                    }
                }
                numberRow("Sessions.Detail.ExScore", value: $exScore)
                numberRow("Sessions.Detail.PGreat", value: $perfectGreat)
                numberRow("Sessions.Detail.Great", value: $great)
                numberRow("Sessions.Detail.Miss", value: $miss)
            }

            Section {
                Button("Sessions.Detail.Reprocess", systemImage: "arrow.clockwise") {
                    store.reprocess(play)
                    dismiss()
                }
            }
        }
        .navigationTitle("Sessions.Detail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Shared.Done") {
                    save()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear(perform: loadFields)
    }

    private func numberRow(_ titleKey: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(titleKey) {
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statusText: String {
        switch play.state {
        case .pending: String(localized: "Sessions.State.Pending")
        case .processing: String(localized: "Sessions.State.Processing")
        case .done: String(localized: "Sessions.State.Done")
        case .needsReview: String(localized: "Sessions.State.NeedsReview")
        case .failed: String(localized: "Sessions.State.Failed")
        }
    }

    private func levelName(_ level: IIDXLevel) -> String {
        switch level {
        case .beginner: "BEGINNER"
        case .normal: "NORMAL"
        case .hyper: "HYPER"
        case .another: "ANOTHER"
        case .leggendaria: "LEGGENDARIA"
        default: "—"
        }
    }

    private func loadFields() {
        songTitle = play.songTitle ?? ""
        level = play.level
        difficulty = play.difficulty
        playType = play.playType
        exScore = play.exScore
        perfectGreat = play.perfectGreat
        great = play.great
        miss = play.miss
        clearType = IIDXClearType(rawValue: play.clearType) ?? .noPlay
        djLevel = IIDXDJLevel(rawValue: play.djLevel) ?? .none
    }

    private func save() {
        play.songTitle = songTitle.isEmpty ? nil : songTitle
        play.level = level
        play.difficulty = difficulty
        play.playType = playType
        play.exScore = exScore
        play.perfectGreat = perfectGreat
        play.great = great
        play.miss = miss
        play.clearType = clearType.rawValue
        play.djLevel = djLevel.rawValue
        store.saveCorrected(play)
    }
}
