import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var popnHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                PopnProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                PopnAnalyticsView(model: popnAnalyticsModel,
                                  isEditing: $isEditingAnalytics,
                                  analyticsNamespace: popnAnalyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.snappy, value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }
}
