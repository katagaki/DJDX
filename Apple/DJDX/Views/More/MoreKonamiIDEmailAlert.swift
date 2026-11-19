import SwiftUI

struct MoreKonamiIDEmailAlert: ViewModifier {

    @AppStorage(wrappedValue: "", "Global.KonamiID.Email") var konamiIDEmail: String

    @Binding var isPresented: Bool
    @Binding var entry: String

    func body(content: Content) -> some View {
        content
            .alert("Alert.KonamiIDEmail.Title", isPresented: $isPresented) {
                TextField("Alert.KonamiIDEmail.Placeholder", text: $entry)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Alert.KonamiIDEmail.Save") {
                    konamiIDEmail = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                Button("Alert.KonamiIDEmail.Clear", role: .destructive) {
                    konamiIDEmail = ""
                    entry = ""
                }
                Button("Shared.Cancel", role: .cancel) {
                    entry = ""
                }
            } message: {
                Text("Alert.KonamiIDEmail.Subtitle")
            }
    }
}

extension View {
    func konamiIDEmailAlert(isPresented: Binding<Bool>, entry: Binding<String>) -> some View {
        modifier(MoreKonamiIDEmailAlert(isPresented: isPresented, entry: entry))
    }
}
