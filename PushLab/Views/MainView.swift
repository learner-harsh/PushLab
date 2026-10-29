import SwiftUI

struct MainView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 340)
        } detail: {
            detail
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = store.selectedTemplateId, store.templates.contains(where: { $0.id == id }) {
            HSplitView {
                ProjectView(template: store.templateBinding(id))
                    .frame(minWidth: 520, idealWidth: 640, maxWidth: .infinity)
                    .layoutPriority(1)
                if store.showsHistory {
                    HistoryView(templateId: id)
                        .frame(minWidth: 340, idealWidth: 460, maxWidth: .infinity)
                }
            }
            .id(id)
            .navigationTitle(store.selectedTemplate?.name ?? "PushLab")
            .toolbar { toolbar }
        } else {
            ContentUnavailableView {
                Label("No template selected", systemImage: "paperplane")
            } description: {
                Text("Click + to create a new template, then configure authentication, headers, and payload.")
            } actions: {
                Button("New Template") { store.addTemplate() }
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("PushLab")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                store.duplicateSelected()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .help("Duplicate this template")

            Button {
                store.copyCurlForSelected()
            } label: {
                Label("Copy as cURL", systemImage: "terminal")
            }
            .help("Copy an equivalent curl command")

            Toggle(isOn: Binding(get: { store.showsHistory }, set: { store.showsHistory = $0 })) {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .help("Show or hide the send history")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.sendSelected() }
            } label: {
                if store.isSending {
                    ProgressView().controlSize(.small).frame(width: 60)
                } else {
                    Label("Send", systemImage: "paperplane.fill")
                        .labelStyle(.titleAndIcon)
                        .frame(width: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isSending)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Send the notification (⌘↩)")
        }
    }
}
