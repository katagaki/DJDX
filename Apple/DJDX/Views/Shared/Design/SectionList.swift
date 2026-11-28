import SwiftUI

struct SectionListHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        HStack(spacing: 10.0) {
            content
                .sectionHeaderTitle()
                .foregroundStyle(.primary)
            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1.0)
        }
        .padding(.top, 6.0)
        .padding(.bottom, 4.0)
    }
}

struct SectionListHeader: View {
    let text: String

    var body: some View {
        Text(LocalizedStringKey(text))
            .sectionListHeader()
    }
}

struct TitledSection<Content: View>: View {
    let title: LocalizedStringKey
    let isClear: Bool
    let content: Content

    init(_ title: LocalizedStringKey, isClear: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isClear = isClear
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            Text(title)
                .sectionListHeader()
        }
        .sectionStyle(isClear: isClear)
    }
}

extension View {
    func sectionListHeader() -> some View {
        modifier(SectionListHeaderModifier())
    }

    @ViewBuilder
    func sectionStyle(isClear: Bool = false) -> some View {
        if isClear {
            clearSection()
        } else {
            listSectionSeparator(.hidden)
        }
    }

    func clearSection() -> some View {
        listSectionSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func insetList() -> some View {
        contentMargins(.horizontal, 16.0, for: .scrollContent)
    }

    func sectionListStyle() -> some View {
        listStyle(.grouped)
    }
}
