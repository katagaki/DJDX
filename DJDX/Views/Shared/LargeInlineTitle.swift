//
//  LargeInlineTitle.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/22.
//

import SwiftUI

struct LargeInlineTitle: View {
    var text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.title)
            .fontWeight(.bold)
    }
}

#Preview {
    NavigationStack {
        List {
            Text("1")
            Text("2")
            Text("3")
        }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LargeInlineTitle("インポート履歴")
                }
            }
    }
}
