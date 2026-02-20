//
//  MoreNotesRadarView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/21.
//

import SwiftUI

struct MoreNotesRadarView: View {

    @Environment(\.colorScheme) var colorScheme

    let spRadarData: RadarData?
    let dpRadarData: RadarData?

    @State var selectedPlayType: IIDXPlayType = .single

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
            Picker("Shared.PlayType", selection: $selectedPlayType) {
                Text(verbatim: "SP")
                    .tag(IIDXPlayType.single)
                Text(verbatim: "DP")
                    .tag(IIDXPlayType.double)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if let radarData = currentRadarData {
                RadarChartView(radarData)
                    .frame(height: 200.0)
                    .padding()
                    .animation(.smooth, value: selectedPlayType)
                VStack(spacing: 4.0) {
                    ForEach(radarData.displayPoints(), id: \.label) { point in
                        HStack {
                            Text(verbatim: point.label)
                                .font(.system(size: 13, weight: .bold))
                                .fontWidth(.expanded)
                                .foregroundStyle(point.color)
                            Spacer()
                            Text(verbatim: String(format: "%.2f", point.value))
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                    }
                    Divider()
                        .padding(.vertical, 2.0)
                    HStack {
                        Text("More.NotesRadar.Total")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text(verbatim: String(format: "%.2f", radarData.sum()))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                    }
                }
                .padding()
                .background {
                    switch colorScheme {
                    case .light: Color.white
                    case .dark: Color.clear.background(.regularMaterial)
                    @unknown default: Color.clear
                    }
                }
                .clipShape(.rect(cornerRadius: cornerRadius))
                .padding(.horizontal, 36.0)
                .animation(.smooth, value: selectedPlayType)
            }
        }
        .padding(.vertical, 12.0)
    }
}
