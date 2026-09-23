import SwiftUI

struct RadarMakerPalette {
    let titleKey: LocalizedStringKey
    let colors: [Color]
}

struct MoreRadarMaker: View {

    @Environment(\.dismiss) var dismiss

    static let paletteCount: Int = 2
    static let maximumValue: Double = 200.0

    let palettes: [RadarMakerPalette] = [
        RadarMakerPalette(
            titleKey: "More.RadarMaker.Palette.Player",
            colors: RadarData(notes: 0.0, chord: 0.0, peak: 0.0, charge: 0.0, scratch: 0.0, soflan: 0.0)
                .displayPoints()
                .map(\.color)
        ),
        RadarMakerPalette(
            titleKey: "More.RadarMaker.Palette.Notes",
            colors: [.cyan, .yellow, .red, .purple, .green]
        )
    ]

    @State var notes: Double = 100.0
    @State var chord: Double = 80.0
    @State var peak: Double = 120.0
    @State var charge: Double = 60.0
    @State var scratch: Double = 90.0
    @State var soflan: Double = 70.0
    @State var selectedPaletteIndex: Int = 0
    @State var selectedColorIndex: Int = 0
    @State var exportedImage: ExportedRadarImage?
    @State var isExportFailed: Bool = false

    var radarData: RadarData {
        RadarData(notes: notes, chord: chord, peak: peak, charge: charge, scratch: scratch, soflan: soflan)
    }

    var selectedColor: Color {
        let palette = palettes[selectedPaletteIndex]
        return palette.colors[min(selectedColorIndex, palette.colors.count - 1)]
    }

    var body: some View {
        List {
            Section {
                RadarChartView(radarData, color: selectedColor)
                    .frame(height: 220.0)
                    .padding(.vertical, 40.0)
                    .listRowBackground(Color.clear)
            }
            Section {
                Picker(selection: $selectedPaletteIndex) {
                    ForEach(0..<Self.paletteCount, id: \.self) { index in
                        Text(palettes[index].titleKey)
                            .tag(index)
                    }
                } label: {
                    Text("More.RadarMaker.Palette")
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12.0, leading: 16.0, bottom: 0.0, trailing: 16.0))
                colorCarousel()
            } header: {
                Text("More.RadarMaker.Color")
            }
            Section {
                valueSlider("NOTES", value: $notes, color: color(for: "NOTES"))
                valueSlider("CHORD", value: $chord, color: color(for: "CHORD"))
                valueSlider("PEAK", value: $peak, color: color(for: "PEAK"))
                valueSlider("CHARGE", value: $charge, color: color(for: "CHARGE"))
                valueSlider("SCRATCH", value: $scratch, color: color(for: "SCRATCH"))
                valueSlider("SOF-LAN", value: $soflan, color: color(for: "SOF-LAN"))
            } header: {
                Text("More.RadarMaker.Values")
            } footer: {
                HStack {
                    Text("More.NotesRadar.Total")
                    Spacer()
                    Text(verbatim: String(format: "%.2f", radarData.sum()))
                        .monospacedDigit()
                }
                .font(.system(size: 12.0, weight: .bold))
            }
            Section {
                Button {
                    exportImage()
                } label: {
                    Label("More.RadarMaker.Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("More.RadarMaker.Header")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 26.0, *) {
                    Button(role: .close) {
                        dismiss()
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .tint(.primary)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: selectedPaletteIndex)
        .onChange(of: selectedPaletteIndex) { _, _ in
            selectedColorIndex = 0
        }
        .sheet(item: $exportedImage) { image in
            ExportShareSheet(url: image.url)
        }
        .alert("Alert.RadarMaker.ExportFailed.Title", isPresented: $isExportFailed) {
            Button("Shared.OK", role: .cancel) {
                isExportFailed = false
            }
        } message: {
            Text("Alert.RadarMaker.ExportFailed.Subtitle")
        }
    }

    @ViewBuilder
    func colorCarousel() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12.0) {
                ForEach(0..<palettes[selectedPaletteIndex].colors.count, id: \.self) { index in
                    let color = palettes[selectedPaletteIndex].colors[index]
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            selectedColorIndex = index
                        }
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 40.0, height: 40.0)
                            .overlay {
                                Circle()
                                    .stroke(.primary, lineWidth: selectedColorIndex == index ? 3.0 : 0.0)
                                    .padding(-4.0)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8.0)
            .padding(.horizontal, 8.0)
        }
        .listRowInsets(EdgeInsets(top: 0.0, leading: 16.0, bottom: 10.0, trailing: 16.0))
    }

    @ViewBuilder
    func valueSlider(_ label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 2.0) {
            HStack {
                Text(verbatim: label)
                    .font(.system(size: 12.0, weight: .bold))
                    .fontWidth(.expanded)
                    .foregroundStyle(color)
                Spacer()
                Text(verbatim: String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 12.0, weight: .semibold).monospacedDigit())
            }
            Slider(value: value, in: 0.0...Self.maximumValue)
                .tint(color)
        }
    }

    func color(for label: String) -> Color {
        radarData.points().first { $0.label == label }?.color ?? .primary
    }

    @MainActor
    func exportImage() {
        let renderer = ImageRenderer(content: exportableRadar())
        renderer.scale = 3.0
        guard let image = renderer.uiImage, let data = image.pngData() else {
            isExportFailed = true
            return
        }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotesRadar-\(Int(Date.now.timeIntervalSince1970)).png")
        do {
            try data.write(to: fileURL, options: .atomic)
            exportedImage = ExportedRadarImage(url: fileURL)
        } catch {
            debugPrint(error.localizedDescription)
            isExportFailed = true
        }
    }

    @ViewBuilder
    func exportableRadar() -> some View {
        RadarChartView(radarData, color: selectedColor, labelFontSize: 20.0, lineWidth: 2.5)
            .frame(width: 480.0, height: 380.0)
            .padding(.horizontal, 80.0)
            .padding(.vertical, 110.0)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
    }
}

struct ExportedRadarImage: Identifiable {
    let url: URL
    var id: String { url.path }
}
