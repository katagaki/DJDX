//
//  OpenYouTubeButton.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Komponents
import SwiftUI

struct OpenYouTubeButton: View {

    @Environment(\.openURL) var openURL

    var songTitle: String
    var level: String

    var body: some View {
        Button {
            let searchQuery: String = "IIDX SP\(level) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        } label: {
            HStack {
                ListRow(image: "ListIcon.YouTube", title: "Scores.Viewer.OpenYouTube", includeSpacer: true)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
