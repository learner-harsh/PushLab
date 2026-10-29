import SwiftUI

@main
struct PushLabApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(store)
                .tint(store.preference.accentColor ?? .accentColor)
                .frame(minWidth: 980, minHeight: 600)
                .onAppear { store.applyAppearance() }
        }
        .defaultSize(width: 1356, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Apple Template") { store.addTemplate(platform: .apns) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("New Android Template") { store.addTemplate(platform: .fcm) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Duplicate Template") { store.duplicateSelected() }
                    .keyboardShortcut("d", modifiers: .command)
                    .disabled(store.selectedTemplate == nil)
            }
            CommandMenu("Push") {
                Button("Send") { Task { await store.sendSelected() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(store.selectedTemplate == nil || store.isSending)
                Button("Copy as cURL") { store.copyCurlForSelected() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(store.selectedTemplate == nil)
                Divider()
                Toggle("Show History", isOn: $store.showsHistory)
                    .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .tint(store.preference.accentColor ?? .accentColor)
        }
    }
}
