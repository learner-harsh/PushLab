import SwiftUI

struct HistoryView: View {
    let templateId: UUID
    @Environment(AppStore.self) private var store
    @State private var selection: UUID?

    private var items: [SendHistoryItem] { store.historyItems(for: templateId) }
    private var selectedItem: SendHistoryItem? { items.first { $0.id == selection } ?? items.first }

    var body: some View {
        VSplitView {
            VStack(spacing: 0) {
                HStack {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    let total = store.historyCount(for: templateId)
                    if total > items.count {
                        Text("latest \(items.count) of \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.clearHistory(for: templateId)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(items.isEmpty)
                    .help("Clear history for this template")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
                List(items, selection: $selection) { item in
                    HistoryRow(item: item).tag(item.id)
                }
                .overlay {
                    if items.isEmpty {
                        ContentUnavailableView {
                            Label("No pushes yet", systemImage: "paperplane")
                        } description: {
                            Text("Every request and APNs response for this template is kept here.")
                        }
                    }
                }
            }
            .frame(minHeight: 160)

            Group {
                if let item = selectedItem {
                    SendHistoryItemView(item: item)
                } else {
                    Text("Select a request to inspect it")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minHeight: 220)
        }
    }
}

struct HistoryRow: View {
    let item: SendHistoryItem

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(item: item)
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(item.number) · \(item.statusTitle)")
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(item.platform == .fcm
                     ? "\(item.shortToken) · \(item.destinationTitle) · \(item.createdAt.formatted(date: .omitted, time: .standard))"
                     : "\(item.shortToken) · \(item.environment.title) · \(item.pushType.rawValue) · \(item.createdAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if item.durationMs > 0 {
                Text("\(item.durationMs) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SendHistoryItemView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case request = "Request"
        case response = "Response"
        case raw = "Raw"
        var id: String { rawValue }
    }

    let item: SendHistoryItem
    @State private var tab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            ScrollView {
                switch tab {
                case .general: general
                case .request: request
                case .response: response
                case .raw: raw
                }
            }
        }
    }

    private var general: some View {
        Form {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    StatusDot(item: item)
                    Text(item.localError ?? "\(item.statusCode) · \(ReasonCode.httpStatusTitle(item.statusCode))")
                }
            }
            if let reasonCode = item.responseReasonCode {
                LabeledContent("Reason") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reasonCode).font(.body.weight(.semibold))
                        if let explanation = item.reasonExplanation {
                            Text(explanation)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            LabeledContent("Platform") { Text(item.platform.title) }
            switch item.platform {
            case .apns:
                if let apnsId = item.apnsId {
                    LabeledContent("apns-id") { Text(apnsId).textSelection(.enabled).monospaced() }
                }
                if let uniqueId = item.apnsUniqueId {
                    LabeledContent("apns-unique-id") { Text(uniqueId).textSelection(.enabled).monospaced() }
                }
                LabeledContent("Environment") { Text("\(item.environment.title) · \(item.environment.host)") }
                LabeledContent("Push type") { Text(item.pushType.rawValue) }
            case .fcm:
                if let name = item.fcmMessageName {
                    LabeledContent("Message name") { Text(name).textSelection(.enabled).monospaced().lineLimit(2).truncationMode(.middle) }
                }
                if let projectId = item.projectId {
                    LabeledContent("Project") { Text(projectId).textSelection(.enabled) }
                }
            }
            LabeledContent(item.platform == .fcm ? "Target" : "Device token") {
                Text(item.deviceToken)
                    .monospaced()
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            LabeledContent("URL") {
                Text(item.requestUrl)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            LabeledContent("Sent") { Text(item.createdAt.formatted(date: .abbreviated, time: .standard)) }
            if item.durationMs > 0 {
                LabeledContent("Duration") { Text("\(item.durationMs) ms") }
            }
        }
        .formStyle(.grouped)
    }

    private var request: some View {
        VStack(alignment: .leading, spacing: 12) {
            headers(item.requestHeaders, title: "Request headers")
            HStack {
                Text("Body").font(.headline)
                Spacer()
                CopyButton(text: item.requestMessage)
            }
            MonospacedBlock(text: item.requestMessage)
        }
        .padding(12)
    }

    private var response: some View {
        VStack(alignment: .leading, spacing: 12) {
            headers(item.responseHeaders, title: "Response headers")
            HStack {
                Text("Body").font(.headline)
                Spacer()
                CopyButton(text: item.responseData ?? "")
            }
            MonospacedBlock(text: item.responseData ?? (item.isSuccess ? "(empty body — success)" : ""))
        }
        .padding(12)
    }

    private var raw: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Request").font(.headline)
                Spacer()
                CopyButton(text: item.requestString)
            }
            MonospacedBlock(text: item.requestString)
            HStack {
                Text("Response").font(.headline)
                Spacer()
                CopyButton(text: item.responseString)
            }
            MonospacedBlock(text: item.responseString)
        }
        .padding(12)
    }

    private func headers(_ headers: [SendHistoryItem.KeyValue], title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if headers.isEmpty {
                Text("(none)").foregroundStyle(.secondary).font(.callout)
            }
            ForEach(headers) { header in
                HStack(alignment: .firstTextBaseline) {
                    Text(header.key)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .frame(width: 150, alignment: .leading)
                    Text(header.value)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
