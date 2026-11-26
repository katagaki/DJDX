import SwiftUI

// swiftlint:disable:next type_body_length
struct TierListView: View {

    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: GITADORAVersion.galaxyWaveDelta, "Global.GITADORA.Version")
    var gitadoraVersion: GITADORAVersion
    @AppStorage(wrappedValue: GITADORAInstrument.guitar, "Global.GITADORA.Instrument")
    var gitadoraInstrument: GITADORAInstrument

    var store = TierListStore.shared
    let initialShare: TierListShare?

    @State var game: Game
    @State var playType: TierListPlayType
    @State var level: String = ""
    @State var charts: [TierListChart] = []
    @State var isLoading: Bool = true
    @State var searchTerm: String = ""

    @State var isEnteringShareCode: Bool = false
    @State var shareCodeEntry: String = ""
    @State var pendingShare: TierListShare?
    @State var isConfirmingImport: Bool = false
    @State var isImportFailed: Bool = false
    @State var isConfirmingReset: Bool = false

    init(game: Game, playType: IIDXPlayType? = nil, initialShare: TierListShare? = nil) {
        let playType = playType ?? UserDefaults.standard.string(forKey: "ScoresView.PlayTypeFilter")
            .flatMap(IIDXPlayType.init) ?? .single
        self.initialShare = initialShare
        let initialGame = initialShare.flatMap { Game(tierListCode: $0.game) } ?? game
        _game = State(initialValue: initialGame)
        let initialPlayType = initialShare.flatMap { TierListPlayType(rawValue: $0.playType) }
            ?? (playType == .double ? .double : .single)
        _playType = State(initialValue: initialPlayType)
        _level = State(initialValue: initialShare?.level ?? "")
    }

    var key: TierListKey {
        TierListKey(
            game: game.tierListCode,
            playType: tierListPlayTypeCode,
            level: level
        )
    }

    var tierListPlayTypeCode: String {
        if game == .gitadora { return gitadoraInstrument.rawValue }
        return game.supportsTierListPlayType ? playType.rawValue : ""
    }

    var list: TierList { store.list(for: key) }

    var levels: [String] {
        let prefix = "\(game.tierListCode)/\(key.playType)/"
        let storedLevels = store.lists.keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
        return Set(charts.map(\.level) + storedLevels)
            .sorted { TierListChartProvider.levelSortKey($0) < TierListChartProvider.levelSortKey($1) }
    }

    var chartsAtLevel: [TierListChart] { charts.filter { $0.level == level } }

    var chartsByID: [String: TierListChart] {
        Dictionary(chartsAtLevel.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var unplacedCharts: [TierListChart] {
        let list = list
        return chartsAtLevel
            .filter { list.tier(of: $0.id) == nil && matchesSearch($0) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var loadTaskID: String {
        [game.tierListCode, playType.rawValue, iidxVersion.rawValue, sdvxVersion.rawValue,
         polarisChordVersion.rawValue, ddrVersion.rawValue, gitadoraVersion.rawValue,
         gitadoraInstrument.rawValue].map { "\($0)" }.joined(separator: "/")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8.0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if charts.isEmpty && list.isEmpty {
                    ContentUnavailableView(
                        "TierList.NoData.Title",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("TierList.NoData.Subtitle")
                    )
                } else {
                    tiers
                }
            }
            .padding(.vertical)
        }
        .background(Color.tierListBackground)
        .preferredColorScheme(.dark)
        .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Scores.Search.Prompt")
        .navigationTitle("TierList.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                actionsMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 26.0, *) {
                    Button(role: .close) {
                        dismiss()
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .tint(.primary)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            controls
        }
        .task(id: loadTaskID) {
            await loadCharts()
        }
        .onAppear {
            store.reload()
            if let initialShare {
                pendingShare = initialShare
                isConfirmingImport = true
            }
        }
        .alert("TierList.Import.EnterCode", isPresented: $isEnteringShareCode) {
            TextField("TierList.Import.Placeholder", text: $shareCodeEntry)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Shared.Import") {
                beginImport(shareCodeEntry)
            }
            Button("Shared.Cancel", role: .cancel) {
                shareCodeEntry = ""
            }
        }
        .alert("TierList.Import.Confirm.Title", isPresented: $isConfirmingImport, presenting: pendingShare) { share in
            Button("TierList.Import.Confirm.Replace", role: .destructive) {
                applyImport(share)
            }
            Button("Shared.Cancel", role: .cancel) {
                pendingShare = nil
            }
        } message: { share in
            Text("TierList.Import.Confirm.Subtitle.\(description(of: share))")
        }
        .alert("TierList.Import.Failed", isPresented: $isImportFailed) {
            Button("Shared.OK", role: .cancel) {
                // Dismisses the alert; no further action needed
            }
        }
        .alert("TierList.Reset.Title", isPresented: $isConfirmingReset) {
            Button("TierList.Reset.Confirm", role: .destructive) {
                store.replace(key, with: TierList())
            }
            Button("Shared.Cancel", role: .cancel) {
                // Dismisses the alert; no further action needed
            }
        }
    }

    @ToolbarContentBuilder
    var controls: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Menu {
                Picker("TierList.Game", selection: $game) {
                    ForEach(Game.allCases.filter(\.isAvailable)) { game in
                        if let iconResource = game.iconResource {
                            Label {
                                Text(game.shortName)
                            } icon: {
                                Image(iconResource)
                            }
                            .tag(game)
                        } else {
                            Text(game.shortName).tag(game)
                        }
                    }
                }
            } label: {
                pickerLabel(Text(game.shortName))
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .bottomBar)
        }
        ToolbarItem(placement: .bottomBar) {
            if !levels.isEmpty {
                Menu {
                    Picker(selection: $level) {
                        ForEach(levels, id: \.self) { value in
                            Text(verbatim: "LEVEL \(value)").tag(value)
                        }
                    } label: {
                        Text(verbatim: "LEVEL")
                    }
                } label: {
                    pickerLabel(Text(verbatim: "LEVEL \(level)"))
                }
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .bottomBar)
        } else {
            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }
        }
        ToolbarItem(placement: .bottomBar) {
            playTypePicker
        }
    }

    @ViewBuilder
    var playTypePicker: some View {
        if game == .gitadora {
            Menu {
                Picker("Shared.GITADORA.Instrument", selection: $gitadoraInstrument) {
                    ForEach(GITADORAInstrument.allCases, id: \.self) { instrument in
                        Text(instrument.displayName).tag(instrument)
                    }
                }
            } label: {
                pickerLabel(Text(gitadoraInstrument.displayName))
            }
        } else if game.supportsTierListPlayType {
            Menu {
                Picker("TierList.PlayType", selection: $playType) {
                    ForEach(TierListPlayType.allCases) { playType in
                        Text(playType.rawValue).tag(playType)
                    }
                }
            } label: {
                pickerLabel(Text(playType.rawValue))
            }
        }
    }

    func pickerLabel(_ text: Text) -> some View {
        HStack(spacing: 4.0) {
            text
                .fontWeight(.semibold)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    var tiers: some View {
        VStack(spacing: 2.0) {
            ForEach(TierListTier.allCases) { tier in
                TierListRow(tier: tier, charts: charts(in: tier), onPlace: place) {
                    Text(tier.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(width: 64.0)
                        .frame(maxHeight: .infinity)
                        .background(tier.color)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2.0)
        .background(.black)
        Text("TierList.Unplaced.\(unplacedCharts.count)")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.top, 12.0)
            .padding(.horizontal)
        TierListRow(tier: nil, charts: unplacedCharts, onPlace: place) {
            EmptyView()
        }
        .padding(.vertical, 2.0)
        .background(.black)
        Text("TierList.Hint")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }

    var actionsMenu: some View {
        Menu {
            if let share = TierListShare(key: key, list: list).url {
                ShareLink(item: share) {
                    Label("TierList.Share.Link", systemImage: "link")
                }
            }
            Button("TierList.Share.CopyCode", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = TierListShare(key: key, list: list).code
            }
            .disabled(list.isEmpty)
            Divider()
            Button("TierList.Import.FromClipboard", systemImage: "doc.on.clipboard") {
                beginImport(UIPasteboard.general.string ?? "")
            }
            Button("TierList.Import.EnterCode", systemImage: "keyboard") {
                shareCodeEntry = ""
                isEnteringShareCode = true
            }
            Divider()
            Button("TierList.Reset", systemImage: "arrow.counterclockwise", role: .destructive) {
                isConfirmingReset = true
            }
            .disabled(list.isEmpty)
        } label: {
            Label("TierList.Actions", systemImage: "square.and.arrow.up")
        }
    }

    func charts(in tier: TierListTier) -> [TierListChart] {
        let chartsByID = chartsByID
        return list.charts(in: tier)
            .map { id in chartsByID[id] ?? placeholderChart(id: id) }
            .filter(matchesSearch)
    }

    func matchesSearch(_ chart: TierListChart) -> Bool {
        let term = searchTerm.trimmingCharacters(in: .whitespaces)
        return term.isEmpty || chart.title.localizedStandardContains(term)
    }

    func placeholderChart(id: String) -> TierListChart {
        let parts = id.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let difficulty = parts.count > 1 ? String(parts[1]) : ""
        return TierListChart(
            id: id,
            title: parts.first.map(String.init) ?? id,
            level: level,
            difficultyLabel: String(difficulty.prefix(game.isIIDXFamily ? 1 : 3)),
            difficultyColor: .secondary,
            lampLabel: "",
            lampColor: Color(.systemGray3),
            grade: "",
            gradeColor: .secondary,
            iidxLevel: game.isIIDXFamily ? IIDXLevel(csvValue: difficulty) : nil
        )
    }

    func place(_ id: String, in tier: TierListTier?, before targetID: String?) {
        withAnimation(.smooth.speed(2.0)) {
            store.update(key) { $0.place(id, in: tier, before: targetID) }
        }
    }

    func loadCharts() async {
        isLoading = true
        let loaded = await TierListChartProvider.charts(
            for: game,
            playType: playType,
            iidxVersion: iidxVersion,
            sdvxVersion: sdvxVersion,
            polarisChordVersion: polarisChordVersion,
            ddrVersion: ddrVersion,
            gitadoraVersion: gitadoraVersion,
            gitadoraInstrument: gitadoraInstrument
        )
        charts = loaded
        if !levels.contains(level) {
            level = levels.last ?? ""
        }
        isLoading = false
    }

    func beginImport(_ input: String) {
        guard let share = TierListShare.decode(input) else {
            isImportFailed = true
            return
        }
        pendingShare = share
        isConfirmingImport = true
    }

    func applyImport(_ share: TierListShare) {
        if let target = Game(tierListCode: share.game) {
            game = target
        }
        if let target = TierListPlayType(rawValue: share.playType) {
            playType = target
        }
        if let target = GITADORAInstrument(rawValue: share.playType) {
            gitadoraInstrument = target
        }
        level = share.level
        store.replace(share.key, with: TierList(tiers: share.tiers))
        pendingShare = nil
    }

    func description(of share: TierListShare) -> String {
        let gameName = Game(tierListCode: share.game)?.shortName ?? share.game
        return [gameName, share.playType, "LEVEL \(share.level)"]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

extension Color {
    static let tierListBackground = Color(red: 0.1, green: 0.1, blue: 0.09)
}
