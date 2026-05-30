//
//  AppBackgroundGradient.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import SwiftUI

extension View {
    func appBackgroundGradient() -> some View {
        ZStack {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            self
        }
    }
}
