import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var sdvxHeader: some View {
        VStack(spacing: 0.0) {
            if showProfileHeader {
                SDVXProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 10.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            SDVXAnalyticsView(model: sdvxAnalyticsModel, isEditing: $isEditingAnalytics,
                              analyticsNamespace: sdvxAnalyticsNamespace)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            AnalyticsGoalsSection(game: .soundVoltex, playStyle: "")
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            SDVXSuggestionsSection(model: sdvxAnalyticsModel,
                                   isEditing: $isEditingAnalytics,
                                   analyticsNamespace: sdvxAnalyticsNamespace)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.smooth.speed(2.0), value: showProfileHeader)
    }
}
