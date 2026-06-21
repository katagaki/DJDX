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

    @State private var songIndex: [SongEntry] = []
    @State private var songSuggestions: [IIDXSong] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var capturedImage: UIImage?
    @State private var photoAlert: PhotoAlert?
    @FocusState private var songFieldFocused: Bool

    private let reader = IIDXReader()

    var body: some View {
        Form {
            Section {
                if let image = capturedImage {
                    RecognizedTextImage(image: image)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .listRowInsets(EdgeInsets())
                }
            }

            Section("Sessions.Detail.Chart") {
                TextField("Sessions.Detail.Song", text: $songTitle)
                    .focused($songFieldFocused)
                if songFieldFocused {
                    ForEach(songSuggestions, id: \.title) { song in
                        Button {
                            songTitle = song.title
                            songSuggestions = []
                            songFieldFocused = false
                        } label: {
                            Label(song.title, systemImage: "music.note")
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
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
                if let capturedImage {
                    Button("Sessions.Photos.Save", systemImage: "square.and.arrow.down") {
                        saveToPhotos(capturedImage)
                    }
                }
            }
        }
        .navigationTitle("Sessions.Detail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let capturedImage {
                ShareLink(
                    item: Image(uiImage: capturedImage),
                    preview: SharePreview("Sessions.Detail.Title", image: Image(uiImage: capturedImage))
                )
            }
        }
        .alert(item: $photoAlert) { alert in
            switch alert {
            case .saved:
                return Alert(title: Text("Sessions.Photos.Saved"), dismissButton: .default(Text("Shared.OK")))
            case .failed:
                return Alert(title: Text("Sessions.Photos.Failed"), dismissButton: .default(Text("Shared.OK")))
            case .denied:
                return Alert(
                    title: Text("Sessions.Photos.Denied.Title"),
                    message: Text("Sessions.Photos.Denied.Message"),
                    dismissButton: .default(Text("Shared.OK"))
                )
            }
        }
        .onAppear(perform: loadFields)
        .task {
            if capturedImage == nil {
                let filename = play.rawImageFilename
                capturedImage = await Task.detached {
                    IIDXSessionImageStore.shared.image(for: filename)
                }.value
            }
            if songIndex.isEmpty {
                let songs = await reader.fetchAllSongs()
                songIndex = songs.map { SongEntry(song: $0, compact: $0.titleCompact()) }
            }
        }
        .onChange(of: fields) {
            guard hasLoaded else { return }
            save()
        }
        .onChange(of: songTitle) { scheduleSuggestions() }
        .onChange(of: playType) { scheduleSuggestions() }
        .onChange(of: songFieldFocused) {
            if songFieldFocused {
                scheduleSuggestions()
            } else {
                searchTask?.cancel()
                songSuggestions = []
            }
        }
    }

    private func scheduleSuggestions() {
        searchTask?.cancel()
        let needle = songTitle.compact
        guard songFieldFocused, !songIndex.isEmpty, needle.count >= 2 else {
            songSuggestions = []
            return
        }
        let index = songIndex
        let playType = playType
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            let results = await Task.detached {
                Self.rank(needle: needle, playType: playType, index: index)
            }.value
            if Task.isCancelled { return }
            songSuggestions = results
        }
    }

    private nonisolated static func rank(
        needle: String, playType: IIDXPlayType, index: [SongEntry]
    ) -> [IIDXSong] {
        if index.contains(where: { $0.compact == needle }) { return [] }

        func hasNotes(_ song: IIDXSong) -> Bool {
            (playType == .single ? song.spNoteCount : song.dpNoteCount) != nil
        }

        let ranked = index.compactMap { entry -> (song: IIDXSong, score: Double)? in
            let candidate = entry.compact
            guard candidate.count >= 2 else { return nil }
            if candidate.contains(needle) {
                return (entry.song, Double(candidate.count - needle.count) / Double(candidate.count))
            }
            let longest = max(candidate.count, needle.count)
            guard Double(abs(candidate.count - needle.count)) / Double(longest) <= 0.4 else { return nil }
            let ratio = needle.editRatio(to: candidate)
            guard ratio <= 0.4 else { return nil }
            return (entry.song, 1.0 + ratio)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            let lhsNotes = hasNotes(lhs.song), rhsNotes = hasNotes(rhs.song)
            if lhsNotes != rhsNotes { return lhsNotes }
            return lhs.song.title.count < rhs.song.title.count
        }

        return ranked.prefix(6).map(\.song)
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

    private func saveToPhotos(_ image: UIImage) {
        Task {
            switch await SessionPhotoExporter.save([image]) {
            case .saved: photoAlert = .saved
            case .denied: photoAlert = .denied
            case .failed: photoAlert = .failed
            }
        }
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

private struct SongEntry: Sendable {
    let song: IIDXSong
    let compact: String
}

private enum PhotoAlert: Int, Identifiable {
    case saved, denied, failed
    var id: Int { rawValue }
}

struct RecognizedTextImage: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
    }
}
