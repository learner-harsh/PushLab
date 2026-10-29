import AppKit
import UniformTypeIdentifiers

@MainActor
enum FilePicker {
    static func pickFile(extensions: [String], message: String) -> FileReference? {
        let panel = NSOpenPanel()
        panel.message = message
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) } + [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try? Data(contentsOf: url)
        return FileReference(url: url, data: data)
    }

    static func pickImportSource(startingAt directory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Choose a templates JSON file, or the Push Hero “Default” folder"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func pickExportDestination(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
