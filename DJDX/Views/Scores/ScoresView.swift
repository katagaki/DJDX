//
//  ScoresView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI
import SwiftData

struct ScoresView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @Query(sort: \EPOLISSongRecord.title) var songRecords: [EPOLISSongRecord]

    @State var searchTerm: String = ""
    @AppStorage(wrappedValue: true, "LevelShowcaseVisibleInScoresView") var isLevelShowcaseVisible: Bool
    @AppStorage(wrappedValue: true, "GenreVisibleInScoresView") var isGenreVisible: Bool

    var body: some View {
        NavigationStack(path: $navigationManager.scoresTabPath) {
            List {
                ForEach(songRecords) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            VStack(alignment: .leading, spacing: 2.0) {
                                DetailedSongTitle(songRecord: songRecord,
                                                  isGenreVisible: isGenreVisible)
                            }
                            if isLevelShowcaseVisible {
                                HStack {
                                    Spacer()
                                    LevelShowcase(songRecord: songRecord)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("譜面一覧")
            .listStyle(.plain)
            .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Text("表示設定")
                        Picker("レベル", selection: $isLevelShowcaseVisible) {
                            Text("表示")
                                .tag(true)
                            Text("非表示")
                                .tag(false)
                        }
                        .pickerStyle(.menu)
                        Picker("ジャンル", selection: $isGenreVisible) {
                            Text("表示")
                                .tag(true)
                            Text("非表示")
                                .tag(false)
                        }
                        .pickerStyle(.menu)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord): ScoreViewer(songRecord: songRecord)
                default: Color.clear
                }
            }
        }
    }
}
