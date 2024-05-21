//
//  ImportView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftData
import SwiftUI

struct ImportView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.openURL) var openURL
    @EnvironmentObject var navigationManager: NavigationManager

    @Query var songRecords: [EPOLISSongRecord]

    @State var isSelectingCSVFile: Bool = false
    @State var isAutoImportFailed: Bool = false
    @State var didAutoImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        NavigationStack(path: $navigationManager.importerTabPath) {
            List {
                Section {
                    VStack(spacing: 16.0) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 64.0))
                            .foregroundStyle(.accent)
                        Group {
                            if songRecords.count == 0 {
                                Text("""
アプリをご利用いただく前に、お客様のCSVデータをインポートすることをおすすめします。
お手数ですが、データのインポートを手動で実行してください。
""")
                            } else {
                                Text("""
beatmaniaIIDXをやり終わった後、CSVデータのインポートをおすすめします。
""")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: " ")
                }
                Section {
                    NavigationLink(value: ViewPath.autoImporter) {
                        Label("インポート開始", systemImage: "square.and.arrow.down")
                    }
                }
                if songRecords.count == 0 {
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
                            Button {
                                loadCSVData()
                            } label: {
                                HStack {
                                    Label("サンプルデータを書き込む", systemImage: "sparkles")
                                    Spacer()
                                }
                                .contentShape(.rect)
                            }
                        }
                        .buttonStyle(.plain)
                    } header: {
                        VStack(alignment: .leading, spacing: 4.0) {
                            ListSectionHeader(text: "お困りですか？")
                                .font(.body)
                            Text("""
手動でCSVファイルをダウンロードすることもできます。
アプリを試したい場合、サンプルデータを読み込んでご利用いただけます。
""")
                                .font(.subheadline)
                                .textCase(.none)
                        }
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("データインポート")
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .autoImporter:
                    WebImporter(
                        didAutoImportSucceed: $didAutoImportSucceed,
                        isAutoImportFailed: $isAutoImportFailed,
                        autoImportFailedReason: $autoImportFailedReason
                    )
                    .navigationTitle("自動インポート")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(.hidden, for: .tabBar)
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
                default: Color.clear
                }
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
                try? modelContext.delete(model: EPOLISSongRecord.self)
                for keyedRow in keyedRows {
                    let scoreForSong: EPOLISSongRecord = EPOLISSongRecord(csvRowData: keyedRow)
                    modelContext.insert(scoreForSong)
                }
            }
        }
    }
}
