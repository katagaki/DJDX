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
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @Query(sort: \ImportGroup.importDate, order: .reverse) var importGroups: [ImportGroup]

    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        NavigationStack(path: $navigationManager[.calendar]) {
            List {
                ForEach(importGroups) { importGroup in
                    Button {
                        withAnimation(.snappy.speed(2.0)) {
                            calendar.selectedDate = importGroup.importDate
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(importGroup.importDate, style: .date)
                            Text("\(importGroup.iidxData?.count ?? 0)曲")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: { indexSet in
                    var importGroupsToDelete: [ImportGroup] = []
                    indexSet.forEach { index in
                        importGroupsToDelete.append(importGroups[index])
                    }
                    importGroupsToDelete.forEach { importGroup in
                        modelContext.delete(importGroup)
                    }
                })
            }
            .navigationTitle("データ履歴")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .importerWeb:
                    WebImporter(isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                case .importerManual:
                    ManualImporter(didImportSucceed: $didImportSucceed)
                default: Color.clear
                }
            }
            .listStyle(.plain)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !Calendar.current.isDate(calendar.selectedDate, inSameDayAs: .now) {
                        Button {
                            calendar.selectedDate = .now
                        } label: {
                            Label("今日の日付に戻る", systemImage: "arrowshape.turn.up.backward.badge.clock")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink(value: ViewPath.importerWeb) {
                            Label("Webでインポート", systemImage: "globe")
                        }
                        NavigationLink(value: ViewPath.importerManual) {
                            Label("CSVファイルを開く", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Text("インポート")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0.0) {
                VStack(spacing: 0.0) {
                    if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                        DatePicker("日付",
                                   selection: $calendar.selectedDate.animation(.snappy.speed(2.0)),
                                   in: ...Date.now,
                                   displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding([.leading, .trailing], 10.0)
                    } else {
                        DatePicker("日付",
                                   selection: $calendar.selectedDate.animation(.snappy.speed(2.0)),
                                   in: ...Date.now,
                                   displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding([.top, .bottom], 10.0)
                        .padding([.leading, .trailing], 20.0)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Material.bar)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1/3)
                        .foregroundColor(.primary.opacity(0.2))
                }
            }
            .alert(
                "データ正常にインポートされました。",
                isPresented: $didImportSucceed,
                actions: {
                    Button("OK", role: .cancel) {
                        didImportSucceed = false
                        navigationManager.popToRoot(for: .calendar)
                    }
                },
                message: {
                    Text("インポートが成功しました")
                }
            )
            .alert(
                "データがインポートできませんでした",
                isPresented: $isAutoImportFailed,
                actions: {
                    Button("OK", role: .cancel) {
                        isAutoImportFailed = false
                        navigationManager.popToRoot(for: .calendar)
                    }
                },
                message: {
                    Text(errorMessage(for: autoImportFailedReason ?? .serverError))
                }
            )
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
}
