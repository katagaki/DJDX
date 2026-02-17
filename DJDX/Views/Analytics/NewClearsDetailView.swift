//
//  NewClearsDetailView.swift
//  DJDX
//
//  Created on 2026/02/17.
//

import SwiftUI

struct NewClearsDetailView: View {
    @Binding var newClears: [NewClearEntry]

    var body: some View {
        List {
            if newClears.isEmpty {
                Text("Analytics.NoData")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(newClears) { entry in
                    VStack(alignment: .leading, spacing: 4.0) {
                        Text(entry.songTitle)
                            .font(.body.weight(.medium))
                        HStack(spacing: 4.0) {
                            Text(entry.level.code())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text("LV.\(entry.difficulty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4.0) {
                            Text(entry.previousClearType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(entry.clearType)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 2.0)
                }
            }
        }
        .navigationTitle("Analytics.NewClears")
        .navigationBarTitleDisplayMode(.inline)
    }
}
