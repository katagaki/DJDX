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

    @State var isAutoImportFailed: Bool = false
    @State var didImportSucceed: Bool = false
    @State var autoImportFailedReason: ImportFailedReason?

    var body: some View {
        NavigationStack(path: $navigationManager[.calendar]) {
            List {
                Section {
                }
            }
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
                        .buttonStyle(.plain)
                        .clipShape(RoundedRectangle(cornerRadius: 99.0))
                        .padding([.bottom, .leading, .trailing], 20.0)
                    }
                    NavigationLink(value: ViewPath.importerWeb) {
                        Label("選択した日のデータをインポート", systemImage: "square.and.arrow.down")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.text)
                    .clipShape(RoundedRectangle(cornerRadius: 99.0))
                    .padding([.bottom, .leading, .trailing], 20.0)
                }
                .frame(maxWidth: .infinity)
                .background(Material.bar)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1/3)
                        .foregroundColor(.primary.opacity(0.2))
                }
            }
            .alert("インポートが成功しました。", isPresented: $didImportSucceed, actions: {
                Button("OK", role: .cancel) {
                    didImportSucceed = false
                }
            })
            .alert(errorMessage(for: autoImportFailedReason ?? .serverError), isPresented: $isAutoImportFailed, actions: {
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
}
