import SwiftUI

extension UnifiedView {
    @ViewBuilder
    var iidxHeader: some View {
        VStack(spacing: 0.0) {
            if selectedGame.supportsPlayType {
                Picker("Shared.PlayType", selection: $playTypeToShow) {
                    Text(verbatim: "SP")
                        .tag(IIDXPlayType.single)
                    Text(verbatim: "DP")
                        .tag(IIDXPlayType.double)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8.0)
            }
            if selectedGame.supportsProfile && showProfileHeader {
                IIDXProfileHeaderView()
                    .padding(.horizontal)
                    .padding(.top, 16.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if showAnalytics {
                AnalyticsView(model: analyticsModel,
                              isEditing: $isEditingAnalytics,
                              analyticsNamespace: analyticsNamespace,
                              towerNamespace: towerNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8.0)
        .animation(.smooth.speed(2.0), value: showProfileHeader)
        .animation(.smooth.speed(2.0), value: showAnalytics)
    }
}
