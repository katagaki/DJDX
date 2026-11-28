import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var popnHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                PopnProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 10.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            PopnAnalyticsView(model: popnAnalyticsModel,
                              isEditing: $isEditingAnalytics,
                              analyticsNamespace: popnAnalyticsNamespace)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.snappy, value: showProfileHeader)
    }
}
