import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @State private var renaming: PushTemplate?
    @State private var renameText = ""
    @State private var deleting: PushTemplate?

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selectedTemplateId) {
            Section("Templates") {
                ForEach(store.templates) { template in
                    row(template)
                        .tag(template.id)
                        .contextMenu {
                            Button("Duplicate") { store.duplicate(template) }
                            Button("Rename…") {
                                renameText = template.name
                                renaming = template
                            }
                            Divider()
                            Button("Delete", role: .destructive) { deleting = template }
                        }
                }
                .onMove { store.move(from: $0, to: $1) }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.templates.isEmpty {
                ContentUnavailableView {
                    Label("No templates", systemImage: "tray")
                } description: {
                    Text("Click + to create a new template")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Menu {
                    Button { store.addTemplate(platform: .apns) } label: { Label("Apple · APNs", systemImage: "apple.logo") }
                    Button { store.addTemplate(platform: .fcm) } label: { Label("Android · FCM", systemImage: "flame.fill") }
                } label: {
                    Label("New Template", systemImage: "plus")
                } primaryAction: {
                    store.addTemplate()
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .alert("Rename Template", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { template in
            TextField("Name", text: $renameText)
            Button("Rename") {
                store.rename(template, to: renameText)
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: { _ in
            Text("Enter a new name for this template.")
        }
        .confirmationDialog("Delete “\(deleting?.name ?? "")”?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { template in
            Button("Delete", role: .destructive) {
                store.delete(template)
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { _ in
            Text("The template and its send history will be removed.")
        }
    }

    private func row(_ template: PushTemplate) -> some View {
        HStack(spacing: 10) {
            platformIcon(template.input)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .lineLimit(1)
                Text(template.input.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            let count = store.historyCount(for: template.id)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func platformIcon(_ input: PushInput) -> some View {
        switch input.platform {
        case .apns:
            Image(systemName: "apple.logo")
                .foregroundStyle(input.environment == .sandbox ? .orange : .green)
                .help(input.environment.title)
        case .fcm:
            Image(systemName: "flame.fill")
                .foregroundStyle(.yellow)
                .help("Firebase Cloud Messaging")
        }
    }
}
