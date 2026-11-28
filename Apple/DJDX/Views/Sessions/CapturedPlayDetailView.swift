import SwiftUI

struct CapturedPlayDetailView: View {
    var store: IIDXSessionStore
    var play: IIDXCapturedPlay

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
    @State private var isReanalyzing: Bool = false
    @State private var needsReview: Bool = false
    @FocusState private var songFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let reader = IIDXReader()

    var body: some View {
        GeometryReader { proxy in
            responsiveLayout(in: proxy)
        }
        .background {
            AppBackgroundGradient()
        }
        .navigationTitle("Sessions.Detail.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { editorToolbar }
        .onReceive(NotificationCenter.default.publisher(for: .capturedPlayDidChange)
            .receive(on: RunLoop.main)) { note in
            reanalyzeDidUpdate(note.object as? String)
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

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14.0) {
                Text("Sessions.Detail.Chart")
                    .sectionListHeader()
                songField
                FilterChipGroup(title: chipTitle("Shared.Level", needsAttention: levelNeedsAttention)) {
                    ForEach(IIDXLevel.sorted, id: \.self) { option in
                        let tint = IIDXLevelLabel(levelType: option, score: IIDXLevelScore()).foregroundColor()
                        FilterChip(isOn: level == option,
                                   isDimmed: level != .unknown && level != option, fill: tint) {
                            level = option
                        } label: {
                            Text(LocalizedStringKey(option.rawValue))
                                .font(.system(size: 11.0, weight: .black))
                                .foregroundStyle(.white)
                                .strokeText(color: tint.mix(with: .black, by: 0.55), width: 0.55)
                        }
                    }
                }
                FilterChipGroup(title: chipTitle("Shared.Difficulty", needsAttention: difficultyNeedsAttention)) {
                    ForEach(IIDXDifficulty.sortedInts, id: \.self) { option in
                        FilterChip(isOn: difficulty == option,
                                   isDimmed: difficulty > 0 && difficulty != option) {
                            difficulty = option
                        } label: {
                            LevelNumber(level: String(option), size: 15.0)
                        }
                    }
                }
                FilterChipGroup(title: Text("Shared.PlayType")) {
                    FilterTextChip(title: Text(verbatim: "SP"), isOn: playType == .single) {
                        playType = .single
                    }
                    FilterTextChip(title: Text(verbatim: "DP"), isOn: playType == .double) {
                        playType = .double
                    }
                }
                Text("Sessions.Detail.Result")
                    .sectionListHeader()
                    .padding(.top, 6.0)
                FilterChipGroup(title: chipTitle("Sessions.Detail.ClearType",
                                                 needsAttention: clearTypeNeedsAttention)) {
                    ForEach(IIDXClearType.ascending.reversed(), id: \.self) { option in
                        FilterChip(isOn: clearType == option,
                                   isDimmed: clearType != .unknown && clearType != option) {
                            clearType = option
                        } label: {
                            IIDXMetallicText.clearType(option.rawValue)
                                .font(.system(size: 12.0))
                        }
                    }
                }
                FilterChipGroup(title: chipTitle("Sessions.Detail.DJLevel", needsAttention: djLevelNeedsAttention)) {
                    ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { option in
                        FilterChip(isOn: djLevel == option,
                                   isDimmed: djLevel != .none && djLevel != option) {
                            djLevel = option
                        } label: {
                            IIDXMetallicText.djLevel(option.rawValue)
                                .font(.system(size: 14.0))
                        }
                    }
                }
                resultEditor
            }
            .padding(.horizontal)
            .padding(.top, 8.0)
            .padding(.bottom, 24.0)
            .background {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { dismissKeyboard() }
            }
        }
        .contentMargins(.bottom, 72.0, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .disabled(isReanalyzing)
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        if let capturedImage {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: Image(uiImage: capturedImage),
                    preview: SharePreview("Sessions.Detail.Title", image: Image(uiImage: capturedImage))
                )
            }
        }
        ToolbarItem(placement: .bottomBar) { reanalyzeButton }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) { acceptAllButton }
    }

    @ViewBuilder
    private var reanalyzeButton: some View {
        Button(action: reanalyze) {
            if isReanalyzing {
                ProgressView()
            } else {
                Label("Sessions.Detail.Reprocess", systemImage: "arrow.clockwise")
            }
        }
        .disabled(isReanalyzing)
    }

    private var acceptAllButton: some View {
        Button(action: acceptAll) {
            Label("Sessions.Detail.AcceptAll", systemImage: "checkmark")
        }
        .disabled(isReanalyzing || !needsReview)
    }

    private var songNeedsAttention: Bool {
        needsReview && songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var levelNeedsAttention: Bool { needsReview && level == .unknown }
    private var difficultyNeedsAttention: Bool { needsReview && difficulty <= 0 }
    private var clearTypeNeedsAttention: Bool {
        needsReview && (clearType == .noPlay || clearType == .unknown)
    }
    private var djLevelNeedsAttention: Bool { needsReview && djLevel == .none }
    private var exScoreNeedsAttention: Bool { needsReview && exScore <= 0 }
    private var judgmentNeedsAttention: Bool { needsReview && perfectGreat + great <= 0 }

    @ViewBuilder
    private func responsiveLayout(in proxy: GeometryProxy) -> some View {
        if proxy.size.width > proxy.size.height {
            HStack(spacing: 0.0) {
                dockedImage(in: proxy, landscape: true)
                editorForm
            }
        } else {
            VStack(spacing: 0.0) {
                dockedImage(in: proxy, landscape: false)
                editorForm
            }
        }
    }

    @ViewBuilder
    private func dockedImage(in proxy: GeometryProxy, landscape: Bool) -> some View {
        if let capturedImage {
            if landscape {
                DetectorOverlayImage(image: capturedImage, imageFilename: play.rawImageFilename)
                    .frame(maxHeight: .infinity)
                    .frame(width: min(
                        proxy.size.height * capturedImage.size.width / capturedImage.size.height,
                        proxy.size.width / 2.0
                    ))
            } else {
                DetectorOverlayImage(image: capturedImage, imageFilename: play.rawImageFilename)
                    .frame(maxWidth: .infinity)
                    .frame(height: min(
                        proxy.size.width * capturedImage.size.height / capturedImage.size.width,
                        proxy.size.height / 2.0
                    ))
            }
            Divider()
                .ignoresSafeArea()
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
        needsReview = play.state == .needsReview
        DispatchQueue.main.async { hasLoaded = true }
    }

    private func reanalyze() {
        guard !isReanalyzing else { return }
        songFieldFocused = false
        searchTask?.cancel()
        songSuggestions = []
        hasLoaded = false
        isReanalyzing = true
        store.reprocess(play)
    }

    private func acceptAll() {
        songFieldFocused = false
        searchTask?.cancel()
        songSuggestions = []
        needsReview = false
        save()
    }

    private func reanalyzeDidUpdate(_ changedID: String?) {
        guard isReanalyzing, changedID == play.id,
              let fresh = store.play(id: play.id), fresh.state.isTerminal else { return }
        play.adopt(from: fresh)
        loadFields()
        isReanalyzing = false
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

extension CapturedPlayDetailView {
    private func dismissKeyboard() {
        songFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var ink: Color { colorScheme == .dark ? .white : .black }

    private var songField: some View {
        VStack(spacing: 0.0) {
            HStack(spacing: 8.0) {
                TextField("Sessions.Detail.Song", text: $songTitle)
                    .fontWeight(.heavy)
                    .fontWidth(.compressed)
                    .focused($songFieldFocused)
                attentionMark(songNeedsAttention)
            }
            .padding(.horizontal, 12.0)
            .padding(.vertical, 10.0)
            if songFieldFocused {
                ForEach(songSuggestions, id: \.title) { song in
                    Divider()
                    Button {
                        songTitle = song.title
                        songSuggestions = []
                        songFieldFocused = false
                    } label: {
                        Text(verbatim: song.title)
                            .fontWeight(.heavy)
                            .fontWidth(.compressed)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12.0)
                            .padding(.vertical, 8.0)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(ink.opacity(0.06), in: .rect(cornerRadius: 8.0))
    }

    private func chipTitle(_ key: LocalizedStringKey, needsAttention: Bool) -> Text {
        if needsAttention {
            return Text(key) + Text(verbatim: " ") + Text(Image(systemName: "exclamationmark.circle.fill"))
                .foregroundColor(.orange)
        }
        return Text(key)
    }

    @ViewBuilder
    private func attentionMark(_ needsAttention: Bool) -> some View {
        if needsAttention {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel(Text("Sessions.Detail.NeedsAttention"))
        }
    }

    private var resultEditor: some View {
        VStack(spacing: 10.0) {
            Divider()
            HStack(alignment: .center, spacing: 8.0) {
                Text("Sessions.Detail.ExScore")
                    .cardLabel()
                    .foregroundStyle(.secondary)
                attentionMark(exScoreNeedsAttention)
                Spacer(minLength: 8.0)
                StyledNumberField(value: $exScore, font: .scoreline(.title3)) { value in
                    IIDXScoreText(value, style: .title3)
                }
            }
            Divider()
            judgmentRow(.perfectGreat, value: $perfectGreat, needsAttention: judgmentNeedsAttention)
            Divider()
            judgmentRow(.great, value: $great, needsAttention: judgmentNeedsAttention)
            Divider()
            judgmentRow(.good, value: $good)
            Divider()
            judgmentRow(.bad, value: $bad)
            Divider()
            judgmentRow(.poor, value: $poor)
            Divider()
        }
    }

    private func judgmentRow(_ judgment: IIDXJudgment, value: Binding<Int>,
                             needsAttention: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 8.0) {
            IIDXJudgmentLabel(judgment: judgment, size: 20.0, outlineScale: 0.4)
            attentionMark(needsAttention)
            Spacer(minLength: 8.0)
            StyledNumberField(value: value, font: HitlineFont.swiftUI(size: 22.0)) { number in
                IIDXJudgmentLabel(judgment: judgment, text: String(number), size: 22.0, outlineScale: 0.44)
            }
        }
    }
}

private struct StyledNumberField<Label: View>: View {
    @Binding var value: Int
    let font: Font
    @ViewBuilder let label: (Int) -> Label
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", value: $value, format: .number.grouping(.never))
                .font(font)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .fixedSize()
                .focused($isFocused)
                .opacity(isFocused ? 1.0 : 0.0)
            if !isFocused {
                label(value)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }
}

private struct SongEntry: Sendable {
    let song: IIDXSong
    let compact: String
}
