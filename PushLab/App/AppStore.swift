import SwiftUI
import Observation
import AppKit

struct Toast: Equatable, Identifiable {
    enum Style { case success, failure, info }
    var id = UUID()
    var style: Style
    var title: String
    var detail: String?
}

@MainActor
@Observable
final class AppStore {
    var templates: [PushTemplate] = []
    var history: [SendHistoryItem] = []
    var preference = Preference()
    var selectedTemplateId: UUID?
    var showsHistory = true
    var isSending = false
    var toast: Toast?
    var keychainIdentities: [KeychainIdentity] = []
    var lastErrorMessage: String?

    @ObservationIgnored private let persistence = Persistence()
    @ObservationIgnored private let client = APNsClient()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init() {
        templates = persistence.load([PushTemplate].self, file: "templates.json") ?? []
        history = persistence.load([SendHistoryItem].self, file: "history.json") ?? []
        preference = persistence.load(Preference.self, file: "preferences.json") ?? Preference()
        selectedTemplateId = templates.first?.id
    }

    // MARK: Templates

    var selectedTemplate: PushTemplate? {
        templates.first { $0.id == selectedTemplateId }
    }

    func templateBinding(_ id: UUID) -> Binding<PushTemplate> {
        Binding(
            get: { [weak self] in
                self?.templates.first { $0.id == id } ?? PushTemplate(name: "")
            },
            set: { [weak self] value in
                guard let self, let index = self.templates.firstIndex(where: { $0.id == id }) else { return }
                var updated = value
                updated.updatedAt = Date()
                self.templates[index] = updated
                self.scheduleSave()
            }
        )
    }

    @discardableResult
    func addTemplate(name: String? = nil, input: PushInput = PushInput()) -> PushTemplate {
        let count = templates.count + 1
        var input = input
        input.id = UUID()
        let template = PushTemplate(id: input.id, name: name ?? "Template \(count)", input: input)
        templates.append(template)
        selectedTemplateId = template.id
        scheduleSave()
        return template
    }

    func duplicate(_ template: PushTemplate) {
        let copy = template.duplicated()
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates.insert(copy, at: index + 1)
        } else {
            templates.append(copy)
        }
        selectedTemplateId = copy.id
        scheduleSave()
    }

    func duplicateSelected() {
        if let selectedTemplate { duplicate(selectedTemplate) }
    }

    func rename(_ template: PushTemplate, to name: String) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index].name = name.trimmingCharacters(in: .whitespaces).isEmpty ? template.name : name
        templates[index].updatedAt = Date()
        scheduleSave()
    }

    func delete(_ template: PushTemplate) {
        templates.removeAll { $0.id == template.id }
        history.removeAll { $0.inputId == template.id }
        if selectedTemplateId == template.id {
            selectedTemplateId = templates.first?.id
        }
        scheduleSave()
    }

    func move(from source: IndexSet, to destination: Int) {
        templates.move(fromOffsets: source, toOffset: destination)
        scheduleSave()
    }

    // MARK: History

    func historyItems(for templateId: UUID?) -> [SendHistoryItem] {
        guard let templateId else { return [] }
        return Array(history.filter { $0.inputId == templateId }.prefix(max(1, preference.fetchLimit)))
    }

    func historyCount(for templateId: UUID?) -> Int {
        guard let templateId else { return 0 }
        return history.filter { $0.inputId == templateId }.count
    }

    func clearHistory(for templateId: UUID?) {
        guard let templateId else { return }
        history.removeAll { $0.inputId == templateId }
        scheduleSave()
    }

    func clearAllHistory() {
        history.removeAll()
        scheduleSave()
    }

    private func nextNumber() -> Int {
        let key = "SendHistoryItem.number"
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
        return next
    }

    // MARK: Sending

    func sendSelected() async {
        guard let template = selectedTemplate else { return }
        let errors = InputValidator.validate(template.input)
        if let first = errors.first {
            showToast(Toast(style: .failure, title: "Cannot send", detail: first.errorDescription))
            return
        }

        isSending = true
        defer { isSending = false }

        var sent = 0
        var failures: [SendHistoryItem] = []
        var localError: Error?
        for token in template.input.deviceTokens {
            do {
                let item = try await client.send(input: template.input, deviceToken: token, number: nextNumber())
                history.insert(item, at: 0)
                if item.isSuccess { sent += 1 } else { failures.append(item) }
            } catch {
                localError = error
                break
            }
        }
        scheduleSave()

        if let localError {
            showToast(Toast(style: .failure, title: "Cannot send", detail: localError.localizedDescription))
        } else if failures.isEmpty {
            let apnsId = history.first?.apnsId
            showToast(Toast(style: .success, title: sent == 1 ? "Push request sent" : "\(sent) push requests sent", detail: apnsId.map { "apns-id \($0)" }))
        } else {
            let first = failures[0]
            let detail = first.reason?.explanation ?? first.localError ?? first.statusTitle
            showToast(Toast(style: .failure, title: "\(first.statusTitle)" + (sent > 0 ? " · \(sent) sent" : ""), detail: detail))
        }
    }

    func copyCurlForSelected() {
        guard let template = selectedTemplate else { return }
        let command = CurlExporter.command(for: template.input)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        showToast(Toast(style: .info, title: "cURL command copied"))
    }

    // MARK: Keychain

    func refreshKeychainIdentities() {
        keychainIdentities = IdentityProvider.pushIdentities()
    }

    // MARK: Import / export

    func exportTemplates() {
        guard let url = FilePicker.pickExportDestination(suggestedName: "PushLab Templates.json") else { return }
        let export = TemplateExport(templates: templates)
        do {
            let data = try Persistence.encoder.encode(export)
            try data.write(to: url, options: .atomic)
            showToast(Toast(style: .success, title: "Push templates have been exported successfully"))
        } catch {
            showToast(Toast(style: .failure, title: "Export failed", detail: error.localizedDescription))
        }
    }

    func importTemplates(fromPushHero: Bool = false) {
        let start = fromPushHero ? TemplateImporter.pushHeroTemplatesDirectory : nil
        guard let url = FilePicker.pickImportSource(startingAt: start) else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            var imported = try TemplateImporter.importTemplates(from: url)
            let existing = Set(templates.map(\.id))
            for index in imported.indices where existing.contains(imported[index].id) {
                imported[index].id = UUID()
                imported[index].input.id = imported[index].id
            }
            templates.append(contentsOf: imported)
            if selectedTemplateId == nil { selectedTemplateId = imported.first?.id }
            scheduleSave()
            showToast(Toast(style: .success, title: "Push templates have been imported successfully", detail: "\(imported.count) template\(imported.count == 1 ? "" : "s")"))
        } catch {
            showToast(Toast(style: .failure, title: "Import failed", detail: error.localizedDescription))
        }
    }

    // MARK: Preferences

    func preferenceDidChange() {
        applyAppearance()
        scheduleSave()
    }

    func applyAppearance() {
        switch preference.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: Persistence

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        persistence.save(templates, file: "templates.json")
        persistence.save(history, file: "history.json")
        persistence.save(preference, file: "preferences.json")
    }

    // MARK: Toast

    func showToast(_ toast: Toast) {
        withAnimation(.spring(duration: 0.3)) {
            self.toast = toast
        }
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(toast.style == .failure ? 5 : 3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self?.toast = nil
            }
        }
    }
}
