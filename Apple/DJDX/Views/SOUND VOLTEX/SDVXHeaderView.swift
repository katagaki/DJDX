import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var sdvxHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                SDVXProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                SDVXAnalyticsView(model: sdvxAnalyticsModel, isEditing: $isEditingAnalytics,
                                  analyticsNamespace: sdvxAnalyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.smooth.speed(2.0), value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }
}
