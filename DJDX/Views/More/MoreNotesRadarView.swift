import SwiftUI

struct MoreNotesRadarView: View {

    @Environment(\.colorScheme) var colorScheme

    let spRadarData: RadarData?
    let dpRadarData: RadarData?
    var maxHeight: CGFloat?
    var radarFontSize: CGFloat = 10.0
    var listFontSize: CGFloat = 10.0

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var selectedPlayType: IIDXPlayType

    @State private var isShowingValues: Bool = false

    var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 20.0
        } else {
            return 12.0
        }
    }

    var currentRadarData: RadarData? {
        switch selectedPlayType {
        case .single: spRadarData
        case .double: dpRadarData
        }
    }

    var body: some View {
        VStack(spacing: 12.0) {
            if let radarData = currentRadarData {
                Group {
                    if isShowingValues {
                        valueList(for: radarData)
                    } else {
                        RadarChartView(radarData, isPlayerRadar: true, labelFontSize: radarFontSize, lineWidth: 1.5)
                            .padding(8.0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: maxHeight)
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.smooth) {
                        isShowingValues.toggle()
                    }
                }
                .animation(.smooth, value: selectedPlayType)
            }
        }
        .frame(maxHeight: maxHeight)
    }

    @ViewBuilder
    func valueList(for radarData: RadarData) -> some View {
        VStack(spacing: 1.0) {
            ForEach(radarData.displayPoints(), id: \.label) { point in
                HStack {
                    Text(verbatim: point.label)
                        .font(.system(size: listFontSize, weight: .bold))
                        .foregroundStyle(point.color)
                    Spacer()
                    Text(verbatim: String(format: "%.2f", point.value))
                        .font(.system(size: listFontSize, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
            Divider()
                .padding(.vertical, 1.0)
            HStack {
                Text("More.NotesRadar.Total")
                    .font(.system(size: listFontSize, weight: .bold))
                Spacer()
                Text(verbatim: String(format: "%.2f", radarData.sum()))
                    .font(.system(size: listFontSize, weight: .bold).monospacedDigit())
            }
        }
        .padding(.horizontal, 16.0)
        .padding(.vertical, 12.0)
        .background {
            switch colorScheme {
            case .light: Color.white
            case .dark: Color.clear.background(.regularMaterial)
            @unknown default: Color.clear
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
