//
//  JiggleEffect.swift
//  DJDX
//
//  Created on 2026/02/19.
//

import SwiftUI

struct JiggleEffect: ViewModifier {
    let isActive: Bool
    let seed: Int

    @State private var degrees: Double = 0

    private var amount: Double {
        1.0 + Double(abs(seed) % 5) * 0.2
    }

    private var duration: Double {
        0.10 + Double(abs(seed) % 4) * 0.015
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(degrees))
            .onChange(of: isActive) { _, active in
                if active {
                    degrees = -amount
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        degrees = amount
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        degrees = 0
                    }
                }
            }
            .onAppear {
                if isActive {
                    degrees = -amount
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        degrees = amount
                    }
                }
            }
    }
}

extension View {
    func jiggle(isActive: Bool, seed: Int) -> some View {
        modifier(JiggleEffect(isActive: isActive, seed: seed))
    }
}
