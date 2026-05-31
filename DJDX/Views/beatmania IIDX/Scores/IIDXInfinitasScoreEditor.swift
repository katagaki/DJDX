import SwiftUI

// Manual add/edit sheet for INFINITAS scores. INFINITAS has no e-amusement
// export, so each chart/difficulty is entered by hand. One entry maps to a
// single populated level on an `IIDXSongRecord`.
struct IIDXInfinitasScoreEditor: View {

    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType

    // nil = add a new entry; non-nil = edit the existing entry.
    var record: IIDXSongRecord? = nil
    var onSaved: (IIDXSongRecord) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var genre: String = ""
    @State private var playType: IIDXPlayType = .single
    @State private var level: IIDXLevel = .another
    @State private var difficulty: Int = 12
    @State private var exScore: Int = 0
    @State private var pgreat: Int = 0
    @State private var great: Int = 0
    @State private var miss: Int = 0
    @State private var clearType: IIDXClearType = .clear
    @State private var djLevel: IIDXDJLevel = .djAAA
    @State private var lastPlayDate: Date = .now
    @State private var playCount: Int = 1

    @State private var songs: [IIDXSong] = []
    @State private var isShowingSongPicker: Bool = false
    @State private var isShowingDeleteConfirmation: Bool = false
    @State private var didLoadInitialValues: Bool = false

    private let reader = IIDXReader()
    private let writer = IIDXImporter()

    var isEditing: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                songSection
                chartSection
                scoreSection
                playSection
                if isEditing {
                    Section {
                        Button("Scores.ManualEntry.Delete", systemImage: "trash", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Scores.ManualEntry.Edit.Title" : "Scores.ManualEntry.Add.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Shared.Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) { save() }
                            .disabled(title.isEmpty)
                    } else {
                        Button("Shared.Done") { save() }
                            .disabled(title.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $isShowingSongPicker) {
                songPicker
            }
            .confirmationDialog(
                "Scores.ManualEntry.Delete.Confirmation",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Scores.ManualEntry.Delete", role: .destructive) { delete() }
            }
            .onAppear(perform: loadInitialValuesIfNeeded)
            .task {
                songs = await reader.fetchAllSongs()
            }
        }
    }

    // MARK: Sections

    @ViewBuilder private var songSection: some View {
        Section("Scores.ManualEntry.Section.Song") {
            TextField("Scores.ManualEntry.Title", text: $title)
            if !songs.isEmpty {
                Button("Scores.ManualEntry.PickFromBEMANIWiki", systemImage: "magnifyingglass") {
                    isShowingSongPicker = true
                }
            }
            TextField("Scores.ManualEntry.Artist", text: $artist)
            TextField("Scores.ManualEntry.Genre", text: $genre)
        }
    }

    @ViewBuilder private var chartSection: some View {
        Section("Scores.ManualEntry.Section.Chart") {
            Picker("Shared.PlayType", selection: $playType) {
                Text(verbatim: "SP").tag(IIDXPlayType.single)
                Text(verbatim: "DP").tag(IIDXPlayType.double)
            }
            .pickerStyle(.segmented)
            Picker("Scores.ManualEntry.Level", selection: $level) {
                ForEach(IIDXLevel.sorted, id: \.self) { level in
                    Text(LocalizedStringKey(level.rawValue)).tag(level)
                }
            }
            Stepper(value: $difficulty, in: 1...12) {
                LabeledContent("Scores.ManualEntry.DifficultyRating") {
                    Text(verbatim: "\(difficulty)")
                }
            }
        }
    }

    @ViewBuilder private var scoreSection: some View {
        Section("Scores.ManualEntry.Section.Score") {
            numberField("Scores.ManualEntry.EXScore", value: $exScore)
            numberField("Scores.ManualEntry.PGreat", value: $pgreat)
            numberField("Scores.ManualEntry.Great", value: $great)
            numberField("Scores.ManualEntry.Miss", value: $miss)
            Picker("Shared.IIDX.ClearType", selection: $clearType) {
                ForEach(IIDXClearType.sortedWithoutNoPlay, id: \.self) { clearType in
                    Text(LocalizedStringKey(clearType.rawValue)).tag(clearType)
                }
                Text(LocalizedStringKey(IIDXClearType.noPlay.rawValue)).tag(IIDXClearType.noPlay)
            }
            Picker("Shared.IIDX.DJLevel", selection: $djLevel) {
                ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { djLevel in
                    Text(verbatim: djLevel.rawValue).tag(djLevel)
                }
                Text(verbatim: IIDXDJLevel.none.rawValue).tag(IIDXDJLevel.none)
            }
        }
    }

    @ViewBuilder private var playSection: some View {
        Section("Scores.ManualEntry.Section.Play") {
            DatePicker("Scores.ManualEntry.LastPlayDate",
                       selection: $lastPlayDate,
                       in: ...Date.now,
                       displayedComponents: [.date, .hourAndMinute])
            Stepper(value: $playCount, in: 0...9999) {
                LabeledContent("Scores.ManualEntry.PlayCount") {
                    Text(verbatim: "\(playCount)")
                }
            }
        }
    }

    @ViewBuilder private func numberField(_ titleKey: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(titleKey) {
            TextField(titleKey, value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder private var songPicker: some View {
        SongSearchPicker(songs: songs) { selectedTitle in
            title = selectedTitle
            isShowingSongPicker = false
        }
    }

    // MARK: Actions

    private func loadInitialValuesIfNeeded() {
        guard !didLoadInitialValues else { return }
        didLoadInitialValues = true

        guard let record else {
            // New entry: default the play type to the currently displayed one so
            // the entry appears in the list immediately.
            playType = playTypeToShow
            return
        }

        title = record.title
        artist = record.artist
        genre = record.genre
        playType = record.playType
        playCount = record.playCount
        lastPlayDate = record.lastPlayDate == .distantPast ? .now : record.lastPlayDate

        // Find the single populated level for this manual entry.
        if let populated = record.scores().first {
            level = populated.level
            difficulty = populated.difficulty
            exScore = populated.score
            pgreat = populated.perfectGreatCount
            great = populated.greatCount
            miss = populated.missCount
            clearType = IIDXClearType(rawValue: populated.clearType) ?? .clear
            djLevel = populated.djLevelEnum()
        }
    }

    private func buildRecord() -> IIDXSongRecord {
        let result = record ?? IIDXSongRecord()
        result.version = IIDXVersion.infinitas.marketingName
        result.title = title
        result.artist = artist
        result.genre = genre
        result.playType = playType
        result.playCount = playCount
        result.lastPlayDate = lastPlayDate

        // Each manual entry holds exactly one populated level; clear the rest.
        result.beginnerScore = IIDXLevelScore()
        result.normalScore = IIDXLevelScore()
        result.hyperScore = IIDXLevelScore()
        result.anotherScore = IIDXLevelScore()
        result.leggendariaScore = IIDXLevelScore()

        let score = IIDXLevelScore(
            level: level,
            difficulty: difficulty,
            score: exScore,
            perfectGreatCount: pgreat,
            greatCount: great,
            missCount: miss,
            clearType: clearType.rawValue,
            djLevel: djLevel.rawValue
        )
        switch level {
        case .beginner: result.beginnerScore = score
        case .normal: result.normalScore = score
        case .hyper: result.hyperScore = score
        case .another: result.anotherScore = score
        case .leggendaria: result.leggendariaScore = score
        default: result.anotherScore = score
        }
        return result
    }

    private func save() {
        let builtRecord = buildRecord()
        let databaseID = record?.databaseID
        Task {
            if let databaseID {
                await writer.updateSongRecord(id: databaseID, builtRecord)
            } else {
                await writer.addManualSongRecord(builtRecord)
            }
            await MainActor.run {
                NotificationCenter.default.post(name: .dataImported, object: nil)
                onSaved(builtRecord)
                dismiss()
            }
        }
    }

    private func delete() {
        guard let databaseID = record?.databaseID else { return }
        Task {
            await writer.deleteSongRecord(id: databaseID)
            await MainActor.run {
                NotificationCenter.default.post(name: .dataImported, object: nil)
                onDeleted()
                dismiss()
            }
        }
    }
}

// Searchable list of BEMANIWiki song titles used to fill in the song title.
private struct SongSearchPicker: View {

    @Environment(\.dismiss) var dismiss

    let songs: [IIDXSong]
    var onSelect: (String) -> Void

    @State private var searchTerm: String = ""

    private var filteredSongs: [IIDXSong] {
        let trimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return songs }
        return songs.filter { $0.title.lowercased().contains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            List(filteredSongs, id: \.title) { song in
                Button {
                    onSelect(song.title)
                } label: {
                    Text(song.title)
                        .foregroundStyle(.primary)
                }
            }
            .searchable(text: $searchTerm, prompt: "Scores.ManualEntry.SongPicker.Search")
            .navigationTitle("Scores.ManualEntry.SongPicker.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { dismiss() }
                    } else {
                        Button("Shared.Cancel") { dismiss() }
                    }
                }
            }
        }
    }
}
