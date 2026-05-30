//
//  ClearTypeOverviewListView.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import OrderedCollections
import SwiftUI

struct ClearTypeOverviewListView: View {

    @Binding var graphData: [Int: OrderedDictionary<String, Int>]

    var populatedDifficulties: [Int] {
        graphData.filter { _, counts in
            counts.values.contains(where: { $0 > 0 })
        }.keys.sorted()
    }

    var body: some View {
        List {
            Section {
                OverviewClearTypeOverallGraph(
                    graphData: $graphData,
                    isInteractive: true
                )
                .chartLegend(.hidden)
                .frame(height: 280.0)
                .padding(.vertical, 8.0)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                ClearTypeLegend()
                    .listRowInsets(EdgeInsets(top: 0.0, leading: 16.0, bottom: 8.0, trailing: 16.0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(populatedDifficulties, id: \.self) { difficulty in
                    ClearTypeLevelRow(counts: graphData[difficulty] ?? [:], difficulty: difficulty)
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text("Shared.Level")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct ClearTypeLegend: View {

    let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4.0) {
            ForEach(IIDXClearType.sortedWithoutNoPlay, id: \.self) { clearType in
                HStack(spacing: 6.0) {
                    Circle()
                        .fill(IIDXClearType.color(for: clearType.rawValue))
                        .frame(width: 8.0, height: 8.0)
                    Text(verbatim: clearType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0.0)
                }
            }
        }
        .padding(.vertical, 2.0)
    }
}

struct ClearTypeLevelRow: View {

    let counts: OrderedDictionary<String, Int>
    let difficulty: Int

    var total: Int {
        counts.values.reduce(0, +)
    }

    // Clear types present in this level, in display order, with non-zero counts.
    var segments: [(type: String, count: Int)] {
        IIDXClearType.sortedStringsWithoutNoPlay.compactMap { type in
            let count = counts[type] ?? 0
            return count > 0 ? (type, count) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            HStack {
                Text(verbatim: "LEVEL \(difficulty)")
                    .font(.subheadline.bold())
                Spacer()
                Text("Shared.SongCount.\(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                HStack(spacing: 0.0) {
                    ForEach(segments, id: \.type) { segment in
                        IIDXClearType.color(for: segment.type)
                            .frame(width: geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1)))
                    }
                }
                .clipShape(.rect(cornerRadius: 4.0))
            }
            .frame(height: 16.0)
        }
        .padding(.vertical, 4.0)
    }
}
