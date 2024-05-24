//
//  CalendarView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Komponents
import SwiftData
import SwiftUI

struct CalendarView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.openURL) var openURL

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @State var isSelectingCSVFile: Bool = false
    @State var isAutoImportFailed: Bool = false
    @State var didAutoImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        NavigationStack(path: $navigationManager[.calendar]) {
            List {
                Section {
                    NavigationLink(value: ViewPath.importerWeb) {
                        Label("選択した日のデータをインポート", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .importerWeb:
                    WebImporter(
                        didAutoImportSucceed: $didAutoImportSucceed,
                        isAutoImportFailed: $isAutoImportFailed,
                        autoImportFailedReason: $autoImportFailedReason
                    )
                    .navigationTitle("自動インポート")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(.hidden, for: .tabBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(value: ViewPath.importerManual) {
                                Text("お困りですか？")
                            }
                        }
                    }
                    .background {
                        ProgressView("読み込み中…")
                    }
                    .padding(0.0)
                    .safeAreaInset(edge: .bottom, spacing: 0.0) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("認証情報はこの端末外に送信することはありません。")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding([.leading, .trailing], 12.0)
                        .padding([.top, .bottom], 8.0)
                        .background(.bar)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .frame(height: 1/3)
                                .foregroundColor(.primary.opacity(0.2))
                        }
                    }
                case .importerManual:
                    List {
                        Section {
                            Group {
                                Button {
                                    openURL(URL(string: "https://p.eagate.573.jp/game/2dx/31/djdata/score_download.html")!)
                                } label: {
                                    HStack {
                                        Label("CSVをダウンロード", systemImage: "arrow.down.circle")
                                        Spacer()
                                        Image(systemName: "safari")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(.rect)
                                }
                                Button {
                                    isSelectingCSVFile = true
                                } label: {
                                    HStack {
                                        Label("CSVを読み込む", systemImage: "folder")
                                        Spacer()
                                    }
                                    .contentShape(.rect)
                                }
                            }
                            .buttonStyle(.plain)
                        } header: {
                            VStack(alignment: .leading, spacing: 4.0) {
                                Text("""
手動でCSVファイルをダウンロードすることもできます。
""")
                                .foregroundStyle(.primary)
                                .font(.body)
                                .textCase(.none)
                            }
                        }
                        Section {
                            Button {
                                loadCSVData()
                            } label: {
                                HStack {
                                    Label("サンプルデータを書き込む", systemImage: "sparkles")
                                    Spacer()
                                }
                                .contentShape(.rect)
                            }
                        } header: {
                            Text("""
アプリを試したい場合、サンプルデータを読み込んでご利用いただけます。
""")
                            .foregroundStyle(.primary)
                            .font(.body)
                            .textCase(.none)
                        }
                    }
                    .navigationTitle("手動でインポート")
                    .navigationBarTitleDisplayMode(.inline)
                default: Color.clear
                }
            }
            .listStyle(.plain)
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0.0) {
                VStack(spacing: 0.0) {
                    DatePicker("カレンダー",
                               selection: $calendar.selectedDate.animation(.snappy.speed(2.0)),
                               in: ...Date.now,
                               displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    if !Calendar.current.isDate(calendar.selectedDate, inSameDayAs: .now) {
                        Button {
                            withAnimation(.snappy.speed(2.0)) {
                                calendar.selectedDate = .now
                            }
                        } label: {
                            Label("今日の日付に戻る", systemImage: "arrowshape.turn.up.backward.badge.clock")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(.text)
                        .clipShape(RoundedRectangle(cornerRadius: 99.0))
                    }
                }
                .padding([.bottom, .leading, .trailing], 20.0)
                .frame(maxWidth: .infinity)
                .background(Material.bar)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1/3)
                        .foregroundColor(.primary.opacity(0.2))
                }
            }
            .sheet(isPresented: $isSelectingCSVFile) {
                DocumentPicker(allowedUTIs: [.commaSeparatedText], onDocumentPicked: { url in
                    let isAccessSuccessful = url.startAccessingSecurityScopedResource()
                    if isAccessSuccessful {
                        loadCSVData(from: url)
                    } else {
                        url.stopAccessingSecurityScopedResource()
                    }
                })
                .ignoresSafeArea(edges: [.bottom])
            }
            .alert("インポートが成功しました。",
                   isPresented: $didAutoImportSucceed,
                   actions: {
                Button("OK", role: .cancel) {
                    didAutoImportSucceed = false
                }
            })
            .alert(errorMessage(for: autoImportFailedReason ?? .serverError),
                   isPresented: $isAutoImportFailed,
                   actions: {
                Button("OK", role: .cancel) {
                    isAutoImportFailed = false
                }
            })
        }
    }

    func errorMessage(for reason: ImportFailedReason) -> String {
        switch reason {
        case .noPremiumCourse:
            return "e-amusementプレミアムコースに入会されていないため、インポートが失敗しました。"
        case .noEAmusementPass:
            return "e-amusement passが登録されていないため、インポートが失敗しました。"
        case .noPlayData:
            return "プレーデータがないため、インポートが失敗しました。"
        case .serverError:
            return "サーバーエラーが発生したため、インポートが失敗しました。"
        case .maintenance:
            return "e-amusementはただいまメンテナンス中のため、ご利用いただけません。"
        }
    }

    func loadCSVData(from url: URL? = Bundle.main.url(forResource: "SampleData", withExtension: "csv")) {
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {
                // Delete selected date's import group
                let fetchDescriptor = FetchDescriptor<ImportGroup>(
                    predicate: importGroups(in: calendar)
                    )
                if let importGroupsOnSelectedDate: [ImportGroup] = try? modelContext.fetch(fetchDescriptor) {
                    for importGroup in importGroupsOnSelectedDate {
                        modelContext.delete(importGroup)
                    }
                }
                // Create new import group for selected date
                let newImportGroup: ImportGroup = ImportGroup(importDate: calendar.selectedDate, iidxData: [])
                modelContext.insert(newImportGroup)
                try? modelContext.save()
                // Read song records
                for keyedRow in keyedRows {
                    let scoreForSong: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                    modelContext.insert(scoreForSong)
                    scoreForSong.importGroup = newImportGroup
                }
                try? modelContext.save()
            }
        }
    }
}
