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

    var body: some View {
        NavigationStack(path: $navigationManager.scoresTabPath) {
            List {
                ForEach(songRecords) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            VStack(alignment: .leading, spacing: 2.0) {
                                DetailedSongTitle(songRecord: songRecord)
                            }
                            HStack {
                                Spacer()
                                LevelShowcase(songRecord: songRecord)
                            }
                        }
                    }
                }
            }
            .navigationTitle("譜面一覧")
            .listStyle(.plain)
            .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always))
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord): ScoreViewer(songRecord: songRecord)
                default: Color.clear
                }
            }
        }
    }
}
