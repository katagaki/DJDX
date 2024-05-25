//
//  MoreView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftUI
import WebKit

struct MoreView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScorewView.GenreVisible") var isGenreVisible: Bool

    var body: some View {
        NavigationStack(path: $navigationManager[.more]) {
            MoreList(repoName: "katagaki/DJDX", viewPath: ViewPath.moreAttributions) {
                Section {
                    Toggle(isOn: $isLevelVisible) {
                        ListRow(image: "ListIcon.ShowDifficulty",
                                title: "レベルを表示",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isGenreVisible) {
                        ListRow(image: "ListIcon.ShowGenre",
                                title: "ジャンルを表示",
                                includeSpacer: true)
                    }
                } header: {
                    ListSectionHeader(text: "リスト表示")
                        .font(.body)
                }
                Section {
                    Button {
                        // TODO: Confirm before deletion
                        WKWebsiteDataStore.default()
                            .fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                                records.forEach { record in
                                    WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes,
                                                                            for: [record],
                                                                            completionHandler: {})
                                }
                            }
                    } label: {
                        Text("Webデータを消去")
                            .foregroundStyle(.red)
                    }
                    Button {
                        // TODO: Confirm before deletion
                        try? modelContext.delete(model: ImportGroup.self)
                        try? modelContext.delete(model: IIDXSongRecord.self)
                    } label: {
                        Text("スコアデータを消去")
                            .foregroundStyle(.red)
                    }
                } header: {
                    ListSectionHeader(text: "データ管理")
                        .font(.body)
                }
            }
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .moreAttributions:
                    LicensesView(licenses: [
                        License(libraryName: "CSwiftV", text:
"""
Copyright (c) 2015, Daniel Haight


All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of CSwiftV nor the names of its contributors
      may be used to endorse or promote products derived from this software
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
""")])
                default: Color.clear
                }
            })
        }
    }
}
