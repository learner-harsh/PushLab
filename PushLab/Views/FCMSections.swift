import SwiftUI
import AppKit

// MARK: - Credentials

struct FCMCredentialsSection: View {
    @Binding var fcm: FCMInput
    @Environment(AppStore.self) private var store
    @State private var checkResult: String?
    @State private var isChecking = false

    private var account: GoogleServiceAccount? { fcm.serviceAccount }

    var body: some View {
        Section {
            LabeledContent {
                HStack {
                    Text(fileDescription)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose JSON…") { chooseFile() }
                    Button("Paste") { pasteJSON() }
                        .help("Paste the service-account JSON from the clipboard")
                    if fcm.serviceAccountFile != nil {
                        Button {
                            fcm.serviceAccountFile = nil
                            checkResult = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            } label: {
                HelpLabel("Service account", FieldHelp.serviceAccount)
            }

            if let account {
                LabeledContent("Project ID") { Text(account.projectId).textSelection(.enabled) }
                LabeledContent("Client email") {
                    Text(account.clientEmail)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let keyId = account.privateKeyId {
                    LabeledContent("Key ID") { Text(keyId).monospaced().lineLimit(1).truncationMode(.middle) }
                }
                HStack {
                    Button("Test credentials") { Task { await testCredentials(account) } }
                        .disabled(isChecking)
                    if isChecking {
                        ProgressView().controlSize(.small)
                    } else if let checkResult {
                        Text(checkResult)
                            .font(.callout)
                            .foregroundStyle(checkResult.hasPrefix("Valid") ? .green : .red)
                            .textSelection(.enabled)
                    }
                }
            } else if fcm.serviceAccountFile != nil {
                Label("This file is not a service-account key. It needs project_id, client_email, and private_key.", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        } header: {
            SectionHeader(title: "Credentials", symbol: "person.badge.key")
        }
    }

    private var fileDescription: String {
        if let name = fcm.serviceAccountFile?.name, !name.isEmpty { return name }
        if fcm.serviceAccountFile != nil { return "Pasted service account" }
        return "No service account selected"
    }

    private func chooseFile() {
        guard let file = FilePicker.pickFile(extensions: ["json"], message: "Choose the Firebase service-account key (.json)") else { return }
        fcm.serviceAccountFile = file
        checkResult = nil
    }

    private func pasteJSON() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        fcm.serviceAccountFile = FileReference(url: nil, data: Data(text.utf8))
        checkResult = nil
    }

    private func testCredentials(_ account: GoogleServiceAccount) async {
        isChecking = true
        defer { isChecking = false }
        switch await store.testFCMCredentials(account) {
        case .success(let token):
            checkResult = "Valid: access token issued (\(token.prefix(12))…)"
        case .failure(let error):
            checkResult = error.localizedDescription
        }
    }
}

// MARK: - Target

struct FCMTargetSection: View {
    @Binding var fcm: FCMInput

    var body: some View {
        Section {
            Picker(selection: $fcm.targetKind) {
                ForEach(FCMTargetKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            } label: {
                HelpLabel("Send to", FieldHelp.fcmTarget)
            }
            .pickerStyle(.segmented)

            switch fcm.targetKind {
            case .token:
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Registration tokens")
                        Spacer()
                        let count = fcm.targets.count
                        Text(count == 1 ? "1 token" : "\(count) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: $fcm.target)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 56, maxHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                }
            case .topic:
                TextField("Topic", text: $fcm.target, prompt: Text(FCMTargetKind.topic.prompt))
                    .autocorrectionDisabled()
            case .condition:
                TextField("Condition", text: $fcm.target, prompt: Text(FCMTargetKind.condition.prompt))
                    .autocorrectionDisabled()
            }

            Toggle(isOn: $fcm.validateOnly) {
                HelpLabel("Validate only (dry run)", FieldHelp.fcmValidateOnly)
            }
        } header: {
            SectionHeader(title: "Target", symbol: "scope")
        }
    }
}

// MARK: - Message

struct FCMMessageSection: View {
    @Binding var fcm: FCMInput

    private var payloadBytes: Int { fcm.message.utf8.count }
    private var jsonProblem: String? {
        fcm.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "message is empty" : InputValidator.jsonProblem(in: fcm.message)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HelpLabel("Message", FieldHelp.fcmMessage)
                    Spacer()
                    Menu("Presets") {
                        ForEach(FCMPresets.all) { preset in
                            Button(preset.name) { fcm.message = preset.json }
                        }
                    }
                    .fixedSize()
                    Button("Format") {
                        if let pretty = InputValidator.prettyPrinted(fcm.message) { fcm.message = pretty }
                    }
                    .disabled(jsonProblem != nil)
                }
                TextEditor(text: $fcm.message)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                HStack {
                    if let jsonProblem {
                        Label(jsonProblem, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Label("Valid JSON · the \(fcm.targetKind.rawValue) key is added when sending", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text("\(payloadBytes) / \(FCMClient.payloadLimit) bytes")
                        .foregroundStyle(payloadBytes > FCMClient.payloadLimit ? .red : .secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        } header: {
            SectionHeader(title: "Message", symbol: "curlybraces")
        }
    }
}
