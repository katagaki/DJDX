//
//  HeartbeatEffect.swift
//  DJDX
//
//  Created on 2026/06/21.
//

import SwiftUI

struct HeartbeatEffect: ViewModifier {
    var isActive: Bool

    @State private var beating: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(beating ? 1.18 : 1.0)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: beating
            )
            .onAppear { beating = isActive }
            .onChange(of: isActive) { _, active in beating = active }
    }
}

extension View {
    func heartbeat(isActive: Bool) -> some View {
        modifier(HeartbeatEffect(isActive: isActive))
    }
}
