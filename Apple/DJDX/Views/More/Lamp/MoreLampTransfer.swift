import SwiftUI

struct MoreLampTransfer: View {

    @Environment(\.dismiss) var dismiss

    @State var identity: LampIdentity? = LampKeychain.load()
    @State var isSending: Bool = false
    @State var isReceiving: Bool = false
    @State var receivedIdentity: LampIdentity?
    @State var receivedPairingNumber: String = ""
    @State var isConfirmingReceive: Bool = false
    @State var isReceivedInvalid: Bool = false

    var body: some View {
        List {
            Section {
                if let identity {
                    LabeledContent("Lamp.ContributorID") {
                        Text(verbatim: identity.contributorID)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("Lamp.DeletionCode") {
                        Text(verbatim: identity.deletionCode)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                } else {
                    Text("Lamp.NoIdentity")
                        .foregroundStyle(.secondary)
                    Button("Lamp.CreateIdentity", systemImage: "plus.circle") {
                        let newIdentity = LampIdentity()
                        if LampKeychain.save(newIdentity) { identity = newIdentity }
                    }
                }
            } header: {
                Text("Lamp.ContributorID.Header")
            } footer: {
                Text("Lamp.ContributorID.Footer")
            }
            Section {
                Button("Lamp.Send", systemImage: "music.note.list") {
                    isSending = true
                }
                .disabled(identity == nil)
                Button("Lamp.Receive", systemImage: "camera.viewfinder") {
                    isReceiving = true
                }
            } header: {
                Text("Lamp.Transfer.Header")
            } footer: {
                Text("Lamp.Transfer.Footer")
            }
        }
        .navigationTitle("Lamp.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $isSending) {
            if let identity {
                ChartSenderView(message: identity.transferMessage)
            }
        }
        .fullScreenCover(isPresented: $isReceiving) {
            ChartReceiverView { message in
                receive(message)
            }
        }
        .alert("Lamp.Received.Title", isPresented: $isConfirmingReceive) {
            Button("Lamp.Received.Use", role: isReplacing ? .destructive : nil) {
                if let receivedIdentity { save(receivedIdentity) }
            }
            Button("Shared.Cancel", role: .cancel) {
                receivedIdentity = nil
            }
        } message: {
            if isReplacing {
                Text("Lamp.Received.Replace.\(receivedPairingNumber).\(receivedIdentity?.contributorID ?? "")")
            } else {
                Text("Lamp.Received.Message.\(receivedPairingNumber).\(receivedIdentity?.contributorID ?? "")")
            }
        }
        .alert("Lamp.Receive.Invalid", isPresented: $isReceivedInvalid) {
            Button("Shared.OK", role: .cancel) {
                // Dismisses the alert; no further action needed
            }
        }
    }

    func receive(_ message: [UInt8]) {
        guard let received = LampIdentity(transferMessage: message) else {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                isReceivedInvalid = true
            }
            return
        }
        receivedIdentity = received
        receivedPairingNumber = ChartCodec.pairingNumber(for: message)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            isConfirmingReceive = true
        }
    }

    var isReplacing: Bool {
        guard let identity, let receivedIdentity else { return false }
        return identity != receivedIdentity
    }

    func save(_ newIdentity: LampIdentity) {
        if LampKeychain.save(newIdentity) {
            identity = newIdentity
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        receivedIdentity = nil
    }
}
