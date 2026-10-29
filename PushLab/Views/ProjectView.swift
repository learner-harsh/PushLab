import SwiftUI

/// The editor for one template: authentication, APNs headers, device tokens, and payload.
struct ProjectView: View {
    @Binding var template: PushTemplate

    private var errors: [InputError] { InputValidator.validate(template.input) }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $template.name, prompt: Text("My app · staging"))
            } header: {
                SectionHeader(title: "Template", symbol: "doc.text")
            }

            AuthSection(input: $template.input)
            HeaderSection(input: $template.input)
            BodySection(input: $template.input)

            Section {
                if errors.isEmpty {
                    Label("Ready to send", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    ForEach(errors) { error in
                        Label(error.errorDescription ?? "", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
            } header: {
                SectionHeader(title: "Validation", symbol: "checklist")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Authentication

struct AuthSection: View {
    @Binding var input: PushInput
    @Environment(AppStore.self) private var store
    @State private var certificateCheck: String?

    var body: some View {
        Section {
            Picker("Method", selection: $input.authentication) {
                ForEach(AuthenticationMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch input.authentication {
            case .key: keyFields
            case .certificate: certificateFields
            case .keychain: keychainFields
            }
        } header: {
            SectionHeader(title: "Authentication", symbol: input.authentication.symbol)
        }
    }

    // Key (.p8)

    @ViewBuilder
    private var keyFields: some View {
        LabeledContent {
            HStack {
                Text(keyFileDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose .p8…") { chooseKeyFile() }
                Button("Paste") { pasteKey() }
                    .help("Paste the content of the .p8 file from the clipboard")
                if input.keyAuthentication.keyContent != nil {
                    Button {
                        input.keyAuthentication.file = nil
                        input.keyAuthentication.cachedContent = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        } label: {
            HelpLabel("Key file", FieldHelp.keyFile)
        }

        if let pem = input.keyAuthentication.keyContent {
            keyStatus(pem)
        }

        TextField(text: $input.keyAuthentication.teamId, prompt: Text("ABCDE12345")) {
            HelpLabel("Team ID", FieldHelp.teamId)
        }
        .autocorrectionDisabled()

        TextField(text: $input.keyAuthentication.keyId, prompt: Text("ABC123DEFG")) {
            HelpLabel("Key ID", FieldHelp.keyId)
        }
        .autocorrectionDisabled()
    }

    private var keyFileDescription: String {
        if let name = input.keyAuthentication.file?.name, !name.isEmpty { return name }
        if input.keyAuthentication.cachedContent != nil { return "Pasted key" }
        return "No key selected"
    }

    @ViewBuilder
    private func keyStatus(_ pem: String) -> some View {
        if (try? JWTSigner.es256Token(teamId: "check", keyId: "check", pem: pem)) != nil {
            Label("Valid P-256 private key", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .font(.callout)
        } else {
            Label("The key is not a valid APNs .p8 private key", systemImage: "xmark.circle")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    private func chooseKeyFile() {
        guard let file = FilePicker.pickFile(extensions: ["p8", "pem"], message: "Choose the APNs auth key (.p8)") else { return }
        input.keyAuthentication.file = file
        input.keyAuthentication.cachedContent = file.data.flatMap { String(data: $0, encoding: .utf8) }
        // AuthKey_ABC123DEFG.p8 → Key ID ABC123DEFG
        let name = file.name
        if input.keyAuthentication.keyId.isEmpty, name.hasPrefix("AuthKey_") {
            let keyId = name.dropFirst("AuthKey_".count).split(separator: ".").first.map(String.init) ?? ""
            if keyId.count == 10 { input.keyAuthentication.keyId = keyId }
        }
    }

    private func pasteKey() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        input.keyAuthentication.cachedContent = text
        input.keyAuthentication.file = nil
    }

    // Certificate (.p12)

    @ViewBuilder
    private var certificateFields: some View {
        LabeledContent {
            HStack {
                Text(input.certificateAuthentication.file?.name.isEmpty == false ? input.certificateAuthentication.file!.name : "No certificate file selected")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose .p12…") {
                    if let file = FilePicker.pickFile(extensions: ["p12", "pfx"], message: "Choose the APNs certificate (.p12)") {
                        input.certificateAuthentication.file = file
                        certificateCheck = nil
                    }
                }
            }
        } label: {
            HelpLabel("Certificate", FieldHelp.certificate)
        }

        SecureField(text: $input.certificateAuthentication.passphrase, prompt: Text("Optional")) {
            HelpLabel("Passphrase", FieldHelp.passphrase)
        }

        HStack {
            Button("Verify certificate") { verifyCertificate() }
                .disabled(input.certificateAuthentication.file?.data == nil)
            if let certificateCheck {
                Text(certificateCheck)
                    .font(.callout)
                    .foregroundStyle(certificateCheck.hasPrefix("Valid") ? .green : .red)
            }
        }
    }

    private func verifyCertificate() {
        guard let data = input.certificateAuthentication.file?.data else { return }
        do {
            let identity = try IdentityProvider.identity(fromP12: data, passphrase: input.certificateAuthentication.passphrase)
            var certificate: SecCertificate?
            SecIdentityCopyCertificate(identity, &certificate)
            let summary = certificate.flatMap { SecCertificateCopySubjectSummary($0) as String? } ?? "identity"
            let expiry = certificate.flatMap(IdentityProvider.expiry(of:))
            let expiryText = expiry.map { " · expires \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
            certificateCheck = "Valid: \(summary)\(expiryText)"
        } catch {
            certificateCheck = error.localizedDescription
        }
    }

    // Keychain

    @ViewBuilder
    private var keychainFields: some View {
        LabeledContent {
            HStack {
                Picker("", selection: $input.keychainAuthentication.identityLabel) {
                    Text("None").tag("")
                    ForEach(store.keychainIdentities) { identity in
                        Text(identity.label + (identity.isExpired ? " (expired)" : ""))
                            .tag(identity.label)
                    }
                }
                .labelsHidden()
                Button {
                    store.refreshKeychainIdentities()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload identities from Keychain")
            }
        } label: {
            HelpLabel("Identity", FieldHelp.keychain)
        }
        .onAppear { store.refreshKeychainIdentities() }

        if store.keychainIdentities.isEmpty {
            Text("No push notification certificates were found in Keychain")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else if let selected = store.keychainIdentities.first(where: { $0.label == input.keychainAuthentication.identityLabel }), let expires = selected.expires {
            Text("Expires \(expires.formatted(date: .abbreviated, time: .omitted))")
                .font(.callout)
                .foregroundStyle(selected.isExpired ? .red : .secondary)
        }
    }
}

// MARK: - Headers

struct HeaderSection: View {
    @Binding var input: PushInput

    var body: some View {
        Section {
            Picker(selection: $input.environment) {
                ForEach(APNsEnvironment.allCases) { environment in
                    Text(environment.title).tag(environment)
                }
            } label: {
                HelpLabel("Environment", FieldHelp.environment)
            }
            .pickerStyle(.segmented)

            TextField(text: $input.bundleId, prompt: Text("com.example.app")) {
                HelpLabel("Bundle ID / topic", FieldHelp.bundleId)
            }
            .autocorrectionDisabled()

            if input.topicNeedsSuffix, let suffix = input.pushType.topicSuffix {
                HStack {
                    Label("\(input.pushType.title) pushes need the topic to end with \(suffix)", systemImage: "lightbulb")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Append \(suffix)") { input.bundleId = input.topic + suffix }
                        .controlSize(.small)
                }
            }

            Picker(selection: $input.pushType) {
                ForEach(PushType.allCases) { type in
                    Text("\(type.title) · \(type.rawValue)").tag(type)
                }
            } label: {
                HelpLabel("Push type", FieldHelp.pushType)
            }

            Text(input.pushType.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker(selection: $input.priority) {
                ForEach(PushPriority.allCases) { priority in
                    Text(priority.title).tag(priority)
                }
            } label: {
                HelpLabel("Priority", FieldHelp.priority)
            }

            LabeledContent {
                HStack {
                    TextField("", text: $input.expiration, prompt: Text("Omitted"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                    Menu {
                        Button("0 · deliver once, don't store") { input.expiration = "0" }
                        Button("Now + 1 hour") { input.expiration = String(Int(Date().timeIntervalSince1970) + 3600) }
                        Button("Now + 1 day") { input.expiration = String(Int(Date().timeIntervalSince1970) + 86400) }
                        Button("Omit header") { input.expiration = "" }
                    } label: {
                        Image(systemName: "clock")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }
            } label: {
                HelpLabel("Expiration", FieldHelp.expiration)
            }

            TextField(text: $input.collapseId, prompt: Text("Optional, max 64 bytes")) {
                HelpLabel("Collapse ID", FieldHelp.collapseId)
            }

            LabeledContent {
                HStack {
                    TextField("", text: $input.notificationId, prompt: Text("Optional, generated by APNs when empty"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                    Button {
                        input.notificationId = UUID().uuidString.lowercased()
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .buttonStyle(.borderless)
                    .help("Generate a UUID")
                }
            } label: {
                HelpLabel("Notification ID", FieldHelp.notificationId)
            }
        } header: {
            SectionHeader(title: "Headers", symbol: "list.bullet.rectangle")
        }
    }
}

// MARK: - Body

struct BodySection: View {
    @Binding var input: PushInput

    private var payloadBytes: Int { input.message.utf8.count }
    private var payloadLimit: Int { input.pushType == .voip ? 5120 : 4096 }
    private var jsonProblem: String? {
        input.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "payload is empty" : InputValidator.jsonProblem(in: input.message)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HelpLabel("Device tokens", FieldHelp.deviceToken)
                    Spacer()
                    let count = input.deviceTokens.count
                    Text(count == 1 ? "1 token" : "\(count) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextEditor(text: $input.deviceToken)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 56, maxHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HelpLabel("Payload", FieldHelp.message)
                    Spacer()
                    Menu("Presets") {
                        ForEach(PayloadPresets.all) { preset in
                            Button(preset.name) {
                                input.message = preset.json
                                input.pushType = preset.pushType
                                if preset.pushType == .background { input.priority = .conserve }
                            }
                        }
                    }
                    .fixedSize()
                    Button("Format") {
                        if let pretty = InputValidator.prettyPrinted(input.message) { input.message = pretty }
                    }
                    .disabled(jsonProblem != nil)
                }
                TextEditor(text: $input.message)
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
                        Label("Valid JSON", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Text("\(payloadBytes) / \(payloadLimit) bytes")
                        .foregroundStyle(payloadBytes > payloadLimit ? .red : .secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        } header: {
            SectionHeader(title: "Body", symbol: "curlybraces")
        }
    }
}
