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
                    .padding(.top, 10.0)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            AnalyticsView(model: analyticsModel,
                          isEditing: $isEditingAnalytics,
                          analyticsNamespace: analyticsNamespace,
                          towerNamespace: towerNamespace)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            AnalyticsGoalsSection(game: selectedGame, playStyle: playTypeToShow.rawValue)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            if !isEditingAnalytics {
                IIDXSuggestionsSection(model: analyticsModel, analyticsNamespace: analyticsNamespace)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.smooth.speed(2.0), value: showProfileHeader)
    }
}
