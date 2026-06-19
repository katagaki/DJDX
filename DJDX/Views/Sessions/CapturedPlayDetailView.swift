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
                    RecognizedTextImage(
                        image: image,
                        result: IIDXSessionImageStore.shared.recognizedText(id: play.id)
                    )
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
                if let minHR = play.minHeartRate, let maxHR = play.maxHeartRate {
                    LabeledContent("Sessions.Detail.HeartRate") {
                        Text(verbatim: "\(minHR)–\(maxHR) BPM")
                    }
                }
                if let parseError = play.parseError {
                    LabeledContent("Sessions.Detail.Error") {
                        Text(verbatim: parseError)
                            .foregroundStyle(.red)
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

enum AnnotationMode: CaseIterable {
    case none, title, numeric

    var next: AnnotationMode {
        switch self {
        case .none: .title
        case .title: .numeric
        case .numeric: .none
        }
    }

    var label: LocalizedStringKey? {
        switch self {
        case .none: nil
        case .title: "Sessions.Detail.Annotations.Title"
        case .numeric: "Sessions.Detail.Annotations.Numeric"
        }
    }

    var color: Color {
        self == .title ? .orange : .green
    }
}

struct RecognizedTextImage: View {
    let image: UIImage
    let result: RecognizedTextResult?

    @State private var mode: AnnotationMode = .numeric

    private var boxes: [RecognizedTextBox] {
        switch mode {
        case .none: []
        case .title: result?.title ?? []
        case .numeric: result?.numeric ?? []
        }
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    let rect = fittedRect(imageSize: image.size, container: proxy.size)
                    ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                        let frame = boxFrame(box, in: rect)
                        Text(verbatim: box.text)
                            .font(.system(size: 9.0))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .foregroundStyle(mode.color)
                            .padding(.horizontal, 1.0)
                            .background(.black.opacity(0.5))
                            .overlay(Rectangle().stroke(mode.color.opacity(0.7), lineWidth: 1.0))
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if let label = mode.label {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6.0)
                        .padding(.vertical, 2.0)
                        .background(mode.color.opacity(0.85), in: Capsule())
                        .foregroundStyle(.black)
                        .padding(6.0)
                }
            }
            .contentShape(.rect)
            .onTapGesture { mode = mode.next }
    }

    private func fittedRect(imageSize: CGSize, container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: (container.width - width) / 2.0, y: (container.height - height) / 2.0,
                      width: width, height: height)
    }

    private func boxFrame(_ box: RecognizedTextBox, in rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + box.originX * rect.width,
            y: rect.minY + (1.0 - box.originY - box.height) * rect.height,
            width: box.width * rect.width,
            height: box.height * rect.height
        )
    }
}
