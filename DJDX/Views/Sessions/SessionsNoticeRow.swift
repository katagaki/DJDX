import SwiftUI

struct SessionsNoticeRow<Accessory: View>: View {
    var systemImage: String
    var color: Color
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    @ViewBuilder var accessory: () -> Accessory

    init(systemImage: String,
         color: Color,
         title: LocalizedStringKey,
         message: LocalizedStringKey,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.systemImage = systemImage
        self.color = color
        self.title = title
        self.message = message
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image(systemName: systemImage)
                .font(.system(size: 18.0, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36.0, height: 36.0)
                .background(color, in: RoundedRectangle(cornerRadius: 9.0, style: .continuous))
            VStack(alignment: .leading, spacing: 3.0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                accessory()
            }
            Spacer(minLength: 0.0)
        }
        .padding(.vertical, 4.0)
    }
}
