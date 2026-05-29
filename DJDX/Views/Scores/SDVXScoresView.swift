//
//  SDVXScoresView.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

struct SDVXScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion

    @State var dataState: DataState = .initializing
    @State var records: [SDVXSongRecord] = []
    @State var searchTerm: String = ""

    let fetcher = SDVXDataFetcher()

    @Namespace var sdvxNamespace

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
    }

    var filteredRecords: [SDVXSongRecord] {
        guard !searchTerm.isEmpty else { return records }
        let term = searchTerm.lowercased()
        return records.filter { $0.title.lowercased().contains(term) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if searchTerm.isEmpty {
                    header
                    if !isEditingAnalytics {
                        HStack {
                            Text("Analytics.Section.ScoreData")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.bottom, 12.0)
                        .padding(.horizontal)
                        Divider()
                    }
                }
                if !isEditingAnalytics {
                    ForEach(filteredRecords, id: \.self) { record in
                        SDVXScoreRow(record: record)
                            .contentShape(.rect)
                        Divider()
                            .padding(.leading, 16.0)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .searchable(text: $searchTerm, prompt: "Scores.Search.Prompt")
        .background {
            if dataState == .presenting && records.isEmpty {
                ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
            }
        }
        .task {
            if dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: sdvxVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords()
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}
