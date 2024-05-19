//
//  MoreView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftUI

struct MoreView: View {
    @Environment(\.modelContext) var modelContext

    var body: some View {
        NavigationStack {
            MoreList(repoName: "katagaki/DJDX") {
                Button {
                    try? modelContext.delete(model: EPOLISSongRecord.self)
                } label: {
                    Text("すべてのデータを削除")
                        .foregroundStyle(.red)
                }
                // TODO: Add CSwiftV license
            }
        }
    }
}
