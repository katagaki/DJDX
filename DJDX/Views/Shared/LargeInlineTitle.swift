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
            .fontWeight(.bold)
            .font(.title)
    }
}
