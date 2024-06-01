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
                            Text("Shared.SongCount.\(importGroup.iidxData?.count ?? 0)")
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
            .navigationTitle("ViewTitle.Calendar")
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
                            Label("Calendar.BackToToday", systemImage: "arrowshape.turn.up.backward.badge.clock")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink(value: ViewPath.importerWeb) {
                            Label("Calendar.Import.FromWeb", systemImage: "globe")
                        }
                        NavigationLink(value: ViewPath.importerManual) {
                            Label("Calendar.Import.FromCSV", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Text("Calendar.Import")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0.0) {
                VStack(spacing: 0.0) {
                    if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                        DatePicker("Shared.Date",
                                   selection: $calendar.selectedDate.animation(.snappy.speed(2.0)),
                                   in: ...Date.now,
                                   displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding([.leading, .trailing], 10.0)
                    } else {
                        DatePicker("Shared.Date",
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
                        .ignoresSafeArea(edges: [.leading, .trailing])
                }
            }
            .alert(
                "Alert.Import.Success.Title",
                isPresented: $didImportSucceed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
                        didImportSucceed = false
                        navigationManager.popToRoot(for: .calendar)
                    }
                },
                message: {
                    Text("Alert.Import.Success.Subtitle")
                }
            )
            .alert(
                "Alert.Import.Error.Title",
                isPresented: $isAutoImportFailed,
                actions: {
                    Button("Shared.OK", role: .cancel) {
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
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPremiumCourse", comment: "")
        case .noEAmusementPass:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoEAmusementPass", comment: "")
        case .noPlayData:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPlayData", comment: "")
        case .serverError:
            return NSLocalizedString("Alert.Import.Error.Subtitle.ServerError", comment: "")
        case .maintenance:
            return NSLocalizedString("Alert.Import.Error.Subtitle.Maintenance", comment: "")
        }
    }
}
