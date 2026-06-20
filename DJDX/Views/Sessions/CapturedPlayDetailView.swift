import SwiftUI

struct CapturedPlayDetailView: View {
    var store: IIDXSessionStore
    var play: IIDXCapturedPlay

    @Environment(\.dismiss) private var dismiss

    @State private var songTitle: String = ""
    @State private var level: IIDXLevel = .unknown
    @State private var difficulty: Int = 0
    @State private var playType: IIDXPlayType = .single
    @State private var exScore: Int = 0
    @State private var perfectGreat: Int = 0
    @State private var great: Int = 0
    @State private var good: Int = 0
    @State private var bad: Int = 0
    @State private var poor: Int = 0
    @State private var clearType: IIDXClearType = .noPlay
    @State private var djLevel: IIDXDJLevel = .none
    @State private var hasLoaded: Bool = false

    var body: some View {
        Form {
            Section {
                if let image = IIDXSessionImageStore.shared.image(for: play.rawImageFilename) {
                    RecognizedTextImage(image: image)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .listRowInsets(EdgeInsets())
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
                        Text(verbatim: "\(value)").tag(value)
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
                numberRow("Sessions.Detail.Good", value: $good)
                numberRow("Sessions.Detail.Bad", value: $bad)
                numberRow("Sessions.Detail.Poor", value: $poor)
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
        .onAppear(perform: loadFields)
        .onChange(of: fields) {
            guard hasLoaded else { return }
            save()
        }
    }

    private var fields: [AnyHashable] {
        [songTitle, level, difficulty, playType, exScore,
         perfectGreat, great, good, bad, poor, clearType, djLevel]
    }

    private func numberRow(_ titleKey: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(titleKey) {
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
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
        good = play.good
        bad = play.bad
        poor = play.poor
        clearType = IIDXClearType(rawValue: play.clearType) ?? .noPlay
        djLevel = IIDXDJLevel(rawValue: play.djLevel) ?? .none
        DispatchQueue.main.async { hasLoaded = true }
    }

    private func save() {
        play.songTitle = songTitle.isEmpty ? nil : songTitle
        play.level = level
        play.difficulty = difficulty
        play.playType = playType
        play.exScore = exScore
        play.perfectGreat = perfectGreat
        play.great = great
        play.good = good
        play.bad = bad
        play.poor = poor
        play.miss = bad + poor
        play.clearType = clearType.rawValue
        play.djLevel = djLevel.rawValue
        store.saveCorrected(play)
    }
}

struct RecognizedTextImage: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
    }
}
