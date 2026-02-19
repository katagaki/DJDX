//
//  ImportDetailView.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import SwiftUI

struct ImportDetailView: View {

    var importGroup: ImportGroup

    var sortedSongRecords: [IIDXSongRecord] {
        (importGroup.iidxData ?? []).sorted { $0.title < $1.title }
    }

    var body: some View {
        List {
            ForEach(sortedSongRecords) { songRecord in
                songRecordRow(songRecord)
                    .listRowBackground(Color.clear)
            }
        }
        .navigator("\(importGroup.importDate, style: .date)", group: false, inline: true)
        .safeAreaInset(edge: .bottom) {
            if #available(iOS 26.0, *) {
                Text("Importer.Detail.SongCount.\(sortedSongRecords.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16.0)
                    .padding(.vertical, 8.0)
                    .glassEffect(.regular, in: Capsule())
                    .padding(.bottom, 16.0)
            } else {
                Text("Importer.Detail.SongCount.\(sortedSongRecords.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.0)
                    .background(.bar)
            }
        }
    }

    @ViewBuilder
    func songRecordRow(_ songRecord: IIDXSongRecord) -> some View {
        VStack(alignment: .leading, spacing: 6.0) {
            // Song title, genre, artist
            VStack(alignment: .leading, spacing: 2.0) {
                Text(songRecord.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6.0) {
                    Text(songRecord.genre)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(verbatim: "·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(songRecord.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            // Play count + last play date
            HStack(spacing: 8.0) {
                if songRecord.lastPlayDate != .distantPast {
                    Text(songRecord.lastPlayDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("Importer.Detail.PlayCount.\(songRecord.playCount)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // Level score columns
            HStack(alignment: .top, spacing: 4.0) {
                ForEach(IIDXLevel.sorted, id: \.self) { level in
                    levelScoreCell(songRecord.score(for: level), level: level)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .padding(.vertical, 4.0)
    }

    @ViewBuilder
    func levelScoreCell(_ score: IIDXLevelScore?, level: IIDXLevel) -> some View {
        let isEmpty = (score == nil || score?.difficulty == 0)
        VStack(alignment: .center, spacing: 2.0) {
            // Level code badge
            Text(level.code())
                .font(.system(size: 9.0, weight: .black))
                .foregroundStyle(isEmpty ? Color.secondary.opacity(0.4) : levelColor(level))
                .frame(maxWidth: .infinity)
            if let score, !isEmpty {
                // Difficulty number
                Text("\(score.difficulty)")
                    .font(.system(size: 9.0, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                // Score
                Text("\(score.score)")
                    .font(.system(size: 9.0, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                // DJ Level
                Text(score.djLevel == "---" ? "-" : score.djLevel)
                    .font(.system(size: 9.0, weight: .heavy))
                    .foregroundStyle(djLevelColor(score.djLevel))
                    .frame(maxWidth: .infinity)
                // Clear Type (abbreviated)
                Text(clearTypeAbbreviation(score.clearType))
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundStyle(clearTypeColor(score.clearType))
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Text(verbatim: "-")
                    .font(.system(size: 9.0))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(4.0)
        .background(isEmpty ? Color.secondary.opacity(0.05) : levelColor(level).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6.0))
    }

    func levelColor(_ level: IIDXLevel) -> Color {
        switch level {
        case .beginner: return .green
        case .normal: return .blue
        case .hyper: return .yellow
        case .another: return .red
        case .leggendaria: return .purple
        default: return .secondary
        }
    }

    func djLevelColor(_ djLevel: String) -> Color {
        switch djLevel {
        case "AAA": return .yellow
        case "AA": return .orange
        case "A": return .green
        default: return .secondary
        }
    }

    func clearTypeColor(_ clearType: String) -> Color {
        switch clearType {
        case "FULLCOMBO CLEAR": return .yellow
        case "HARD CLEAR", "EX HARD CLEAR": return .red
        case "CLEAR": return .green
        case "EASY CLEAR": return .mint
        case "ASSIST CLEAR": return .purple
        case "FAILED": return .secondary
        default: return .secondary
        }
    }

    func clearTypeAbbreviation(_ clearType: String) -> String {
        switch clearType {
        case "FULLCOMBO CLEAR": return "FC"
        case "HARD CLEAR": return "HARD"
        case "EX HARD CLEAR": return "EXH"
        case "CLEAR": return "CLR"
        case "EASY CLEAR": return "EASY"
        case "ASSIST CLEAR": return "AST"
        case "FAILED": return "FAIL"
        case "NO PLAY": return "---"
        default: return "-"
        }
    }
}
