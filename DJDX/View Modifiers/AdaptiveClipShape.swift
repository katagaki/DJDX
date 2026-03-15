//
//  AdaptiveClipShape.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/17.
//

import SwiftUI

struct AdaptiveClipShape: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .clipShape(.rect(cornerRadius: 12.0))
        } else {
            content
                .clipShape(.rect(cornerRadius: 12.0))
        }
    }
}

extension View {
    func adaptiveClipShape() -> some View {
        modifier(AdaptiveClipShape())
    }
}
