//
//  CloseToolbarButton.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

struct CloseToolbarButton: View {

    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close, action: action)
        } else {
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
