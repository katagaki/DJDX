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

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var importPlayType: IIDXPlayType

    @State var importGroups: [ImportGroup] = []

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
                            Text("Shared.SongCount.\(countOfIIDXSongRecords(in: importGroup))")
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
                    calendar.didUserPerformChangesRequiringDisplayDataReload = true
                })
            }
            .listStyle(.plain)
            .navigationTitle("ViewTitle.Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
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
                        Section {
                            Button("Calendar.Import.LoadSamples.Button", systemImage: "sparkles") {
                                Task.detached {
                                    await calendar.importCSV(reportingTo: progressAlertManager, for: .single)
                                    await MainActor.run {
                                        didImportSucceed = true
                                    }
                                }
                            }
                        } header: {
                            Text("Calendar.Import.LoadSamples.Description")
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
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
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8.0) {
                        PlayTypePicker(playTypeToShow: $importPlayType)
                        Group {
                            switch importPlayType {
                            case .single:
                                NavigationLink(value: ViewPath.importerWebIIDXSingle) {
                                    Label("Calendar.Import.FromWeb", systemImage: "globe")
                                        .fontWeight(.medium)
                                        .padding(4.0)
                                }
                            case .double:
                                NavigationLink(value: ViewPath.importerWebIIDXDouble) {
                                    Label("Calendar.Import.FromWeb", systemImage: "globe")
                                        .fontWeight(.medium)
                                        .padding(4.0)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(.capsule)
                        .foregroundStyle(.text)
                        NavigationLink(value: ViewPath.importerManual) {
                            Label("Calendar.Import.FromCSV", systemImage: "doc.badge.plus")
                                .fontWeight(.medium)
                                .padding(4.0)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(.capsule)
                        .foregroundStyle(.text)
                    }
                    .padding([.leading, .trailing], 16.0)
                    .padding([.top, .bottom], 12.0)
                }
                .scrollIndicators(.hidden)
                .background(Material.bar)
                .overlay(alignment: .top) {
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
            .task {
                importGroups = calendar.allImportGroups(in: modelContext)
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .importerWebIIDXSingle:
                    WebImporter(importMode: .single,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                case .importerWebIIDXDouble:
                    WebImporter(importMode: .double,
                                isAutoImportFailed: $isAutoImportFailed,
                                didImportSucceed: $didImportSucceed,
                                autoImportFailedReason: $autoImportFailedReason)
                case .importerManual:
                    ManualImporter(importPlayType: $importPlayType,
                                   didImportSucceed: $didImportSucceed)
                default: Color.clear
                }
            }
        }
    }

    func countOfIIDXSongRecords(in importGroup: ImportGroup) -> Int {
        let importGroupID = importGroup.id
        let fetchDescriptor = FetchDescriptor<IIDXSongRecord>(
            predicate: #Predicate<IIDXSongRecord> {
                $0.importGroup?.id == importGroupID
            }
        )
        return (try? modelContext.fetchCount(fetchDescriptor)) ?? 0
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
