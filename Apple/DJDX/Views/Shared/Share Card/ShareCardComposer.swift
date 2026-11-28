import PhotosUI
import SwiftUI

struct ShareCardComposer: View {

    @Environment(\.dismiss) var dismiss

    @AppStorage(wrappedValue: IIDXVersion.zinrai, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: SDVXVersion.nabla, "Global.SDVX.Version") var sdvxVersion: SDVXVersion
    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: true, "ShareCard.ProfileVisible") var isProfileVisible: Bool
    @AppStorage(wrappedValue: true, "ShareCard.ChartsVisible") var isChartsVisible: Bool
    @AppStorage(wrappedValue: 10, "ShareCard.RowLimit") var rowLimit: Int
    @AppStorage(wrappedValue: 0x7A4DFF, "ShareCard.CustomColor") var customColorValue: Int

    let game: Game
    let profile: ShareCardProfile
    let entries: [ShareCardEntry]
    var playStyle: String?

    static let rowLimits: [Int] = [3, 5, 10, 20, 30, 50]
    static let todayOnlyRowLimit: Int = 0

    var hasPlayDates: Bool {
        entries.contains { $0.playDate != nil }
    }

    var isTodayOnly: Bool {
        rowLimit == Self.todayOnlyRowLimit && hasPlayDates
    }

    var visibleEntries: [ShareCardEntry] {
        if !isChartsVisible {
            return []
        }
        if isTodayOnly {
            return entries.filter { $0.playDate.map(Calendar.current.isDateInToday) ?? false }
        }
        return Array(entries.prefix(rowLimit == Self.todayOnlyRowLimit ? 10 : rowLimit))
    }

    @State var background: ShareCardBackground = .gradient(.accent)
    @State var photoItem: PhotosPickerItem?
    @State var isShowingPhotoPicker: Bool = false
    @State var photo: UIImage?
    @State var renderedImage: UIImage?

    var accentColor: Color {
        game.accentColor(
            iidxVersion: iidxVersion,
            sdvxVersion: sdvxVersion,
            polarisChordVersion: polarisChordVersion,
            ddrVersion: ddrVersion
        )
    }

    var customColor: Binding<Color> {
        Binding {
            Color(hex: UInt32(customColorValue))
        } set: { newValue in
            var red: CGFloat = 0.0
            var green: CGFloat = 0.0
            var blue: CGFloat = 0.0
            UIColor(newValue).getRed(&red, green: &green, blue: &blue, alpha: nil)
            let component: (CGFloat) -> Int = { Int((min(max($0, 0.0), 1.0) * 255.0).rounded()) }
            customColorValue = (component(red) << 16) | (component(green) << 8) | component(blue)
        }
    }

    var renderKey: String {
        "\(background.hashValue).\(customColorValue).\(photo?.hash ?? 0).\(isProfileVisible).\(isChartsVisible).\(rowLimit)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Group {
                        if let renderedImage {
                            Image(uiImage: renderedImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.rect(cornerRadius: 12.0))
                                .shadow(color: .black.opacity(0.2), radius: 8.0, y: 4.0)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 460.0)
                    .listRowBackground(Color.clear)
                }
                Section {
                    backgroundCarousel()
                    if background == .custom {
                        ColorPicker("ShareCard.Color", selection: customColor, supportsOpacity: false)
                    }
                } header: {
                    Text("ShareCard.Background")
                }
                Section {
                    if !profile.isEmpty {
                        Toggle("ShareCard.ShowProfile", isOn: $isProfileVisible)
                    }
                    Toggle("ShareCard.ShowCharts", isOn: $isChartsVisible)
                    if isChartsVisible {
                        Picker("ShareCard.RowLimit", selection: $rowLimit) {
                            ForEach(Self.rowLimits, id: \.self) { limit in
                                Text(verbatim: String(limit))
                                    .tag(limit)
                            }
                            if hasPlayDates {
                                Text("ShareCard.RowLimit.Today")
                                    .tag(Self.todayOnlyRowLimit)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ShareCard.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) {
                            dismiss()
                        }
                    } else {
                        Button("Shared.Cancel") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if let renderedImage {
                        let image = Image(uiImage: renderedImage)
                        ShareLink(
                            item: image,
                            preview: SharePreview(Text(verbatim: game.displayName), image: image)
                        ) {
                            Text("ShareCard.Share")
                        }
                    }
                }
            }
            .task(id: renderKey) {
                render()
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photo = image
                        background = .photo
                    }
                }
            }
        }
    }

    @ViewBuilder
    func backgroundCarousel() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12.0) {
                ForEach(ShareCardGradient.allCases) { gradient in
                    swatch(for: .gradient(gradient)) {
                        LinearGradient(
                            colors: gradient.colors(accentColor: accentColor),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .accessibilityLabel(Text(verbatim: gradient.rawValue.capitalized))
                }
                swatch(for: .custom) {
                    ZStack {
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                        Circle()
                            .fill(Color(hex: UInt32(customColorValue)))
                            .stroke(.white, lineWidth: 2.0)
                            .frame(width: 22.0, height: 22.0)
                    }
                }
                .accessibilityLabel(Text("ShareCard.Color"))
                photoSwatch()
            }
            .padding(8.0)
        }
        .listRowInsets(EdgeInsets(top: 0.0, leading: 8.0, bottom: 0.0, trailing: 8.0))
    }

    @ViewBuilder
    func photoSwatch() -> some View {
        Button {
            if photo != nil, background != .photo {
                withAnimation(.smooth.speed(2.0)) {
                    background = .photo
                }
            } else {
                isShowingPhotoPicker = true
            }
        } label: {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.2)
                }
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .shadow(radius: 2.0)
            }
            .frame(width: 52.0, height: 52.0)
            .clipShape(.rect(cornerRadius: 12.0))
            .overlay {
                selectionRing(isSelected: background == .photo)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("ShareCard.Background.Photo"))
    }

    @ViewBuilder
    func swatch(for option: ShareCardBackground, @ViewBuilder content: () -> some View) -> some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                background = option
            }
        } label: {
            content()
                .frame(width: 52.0, height: 52.0)
                .clipShape(.rect(cornerRadius: 12.0))
                .overlay {
                    selectionRing(isSelected: background == option)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func selectionRing(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 15.0)
            .stroke(.primary, lineWidth: isSelected ? 3.0 : 0.0)
            .padding(-4.0)
    }

    @MainActor
    func render() {
        let card = ShareCardView(
            game: game,
            profile: isProfileVisible ? profile : nil,
            entries: visibleEntries,
            playStyle: playStyle,
            background: background,
            photo: photo,
            accentColor: accentColor,
            customColor: Color(hex: UInt32(customColorValue))
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderedImage = renderer.uiImage
    }
}
