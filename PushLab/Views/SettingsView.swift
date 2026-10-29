import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ImportSettingsView()
                .tabItem { Label("Import & Export", systemImage: "square.and.arrow.up.on.square") }
        }
        .frame(width: 480)
        .padding(.bottom, 6)
    }
}

struct GeneralSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Picker("Appearance", selection: $store.preference.appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("Accent color") {
                HStack {
                    ColorPicker("", selection: Binding(
                        get: { store.preference.accentColor ?? .accentColor },
                        set: { store.preference.accentColorHex = $0.hexString }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    Button("Reset") { store.preference.accentColorHex = nil }
                        .disabled(store.preference.accentColorHex == nil)
                }
            }

            Stepper(value: $store.preference.fetchLimit, in: 1...500, step: 5) {
                LabeledContent("History fetch limit", value: "\(store.preference.fetchLimit)")
            }

            Toggle("Show debug error details in toasts", isOn: $store.preference.showDebugError)
        }
        .formStyle(.grouped)
        .onChange(of: store.preference) { _, _ in store.preferenceDidChange() }
    }
}

struct ImportSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section {
                LabeledContent("Export push templates") {
                    Button("Export…") { store.exportTemplates() }
                        .disabled(store.templates.isEmpty)
                }
                LabeledContent("Import push templates") {
                    Button("Import…") { store.importTemplates() }
                }
                Text("Templates include key and certificate material, so treat exported files like secrets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Templates")
            }

            Section {
                LabeledContent("Import from Push Hero") {
                    Button("Choose folder…") { store.importTemplates(fromPushHero: true) }
                }
                Text("Pick the “Default” folder inside Push Hero's container. Its templates, keys, and certificates are converted in place.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Migration")
            }

            Section {
                LabeledContent("Send history") {
                    Button("Clear all history", role: .destructive) { store.clearAllHistory() }
                        .disabled(store.history.isEmpty)
                }
            } header: {
                Text("Data")
            }
        }
        .formStyle(.grouped)
    }
}
