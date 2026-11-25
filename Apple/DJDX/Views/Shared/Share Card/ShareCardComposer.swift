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
    @AppStorage(wrappedValue: 20, "ShareCard.RowLimit") var rowLimit: Int

    let game: Game
    let profile: ShareCardProfile
    let entries: [ShareCardEntry]

    static let rowLimits: [Int] = [10, 20, 30, 50]

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

    var renderKey: String {
        "\(background.hashValue).\(photo?.hash ?? 0).\(isProfileVisible).\(rowLimit)"
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
                } header: {
                    Text("ShareCard.Background")
                }
                Section {
                    if !profile.isEmpty {
                        Toggle("ShareCard.ShowProfile", isOn: $isProfileVisible)
                    }
                    Picker("ShareCard.RowLimit", selection: $rowLimit) {
                        ForEach(Self.rowLimits, id: \.self) { limit in
                            Text(verbatim: String(limit))
                                .tag(limit)
                        }
                    }
                }
            }
            .navigationTitle("ShareCard.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    if let renderedImage {
                        let image = Image(uiImage: renderedImage)
                        ShareLink(
                            item: image,
                            preview: SharePreview(Text(verbatim: game.displayName), image: image)
                        )
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
                ForEach(AppIconChoice.all, id: \.name) { icon in
                    swatch(for: .appIcon(icon.previewImageName)) {
                        Image(icon.previewImageName)
                            .resizable()
                            .scaledToFill()
                    }
                    .accessibilityLabel(
                        icon.isNameLocalized ? Text(LocalizedStringKey(icon.name)) : Text(verbatim: icon.name)
                    )
                }
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
            entries: Array(entries.prefix(rowLimit)),
            totalCount: entries.count,
            background: background,
            photo: photo,
            accentColor: accentColor
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderedImage = renderer.uiImage
    }
}
