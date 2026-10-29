import Foundation

/// Reads templates from a PushLab export, a bare template array, or Push Hero's on-disk template files.
enum TemplateImporter {
    enum ImportError: LocalizedError {
        case unreadable
        case malformed

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Could not read the selected file or folder."
            case .malformed: return "Could not import. This file may be malformed or empty."
            }
        }
    }

    /// Push Hero keeps one JSON array per group in
    /// ~/Library/Containers/com.onmyway133.PushHero/Data/Documents/com.onmyway133.PushHero/Default
    static var pushHeroTemplatesDirectory: URL {
        // Inside the sandbox the home directory is the app container; strip that to reach the real home.
        var home = FileManager.default.homeDirectoryForCurrentUser.path
        if let range = home.range(of: "/Library/Containers/") {
            home = String(home[..<range.lowerBound])
        }
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Containers/com.onmyway133.PushHero/Data/Documents/com.onmyway133.PushHero/Default")
    }

    static func importTemplates(from url: URL) throws -> [PushTemplate] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { throw ImportError.unreadable }

        if isDirectory.boolValue {
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            var all: [PushTemplate] = []
            for child in children where child.lastPathComponent != "Pref" && !child.hasDirectoryPath {
                if let data = try? Data(contentsOf: child), let templates = try? decode(data) {
                    all.append(contentsOf: templates)
                }
            }
            if all.isEmpty { throw ImportError.malformed }
            return all
        }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> [PushTemplate] {
        let decoder = Persistence.decoder
        if let export = try? decoder.decode(TemplateExport.self, from: data) {
            return export.templates
        }
        if let templates = try? decoder.decode([PushTemplate].self, from: data) {
            return templates
        }
        if let pushHero = try? JSONDecoder().decode([PushHeroTemplate].self, from: data) {
            return pushHero.map { $0.asTemplate() }
        }
        throw ImportError.malformed
    }
}

// MARK: - Push Hero's file format

struct PushHeroTemplate: Decodable {
    struct File: Decodable {
        var url: URL?
        var data: Data?
    }

    struct KeyAuth: Decodable {
        var file: File?
        var teamId: String?
        var keyId: String?
        var cachedContent: String?
    }

    struct CertAuth: Decodable {
        var file: File?
        var passphrase: String?
    }

    struct Input: Decodable {
        var id: UUID?
        var bundleId: String?
        var message: String?
        var environment: Int?
        var authentication: Int?
        var keyAuthentication: KeyAuth?
        var certifcateAuthentication: CertAuth?
        var collapseId: String?
        var pushType: String?
        var priority: String?
        var deviceToken: String?
        var notificationId: String?
        var expiration: String?
    }

    var id: UUID?
    var name: String?
    var input: Input

    func asTemplate() -> PushTemplate {
        var result = PushInput()
        let id = id ?? input.id ?? UUID()
        result.id = id
        result.bundleId = input.bundleId ?? ""
        result.message = input.message ?? PayloadPresets.defaultMessage
        // Push Hero encodes its Environment enum by case index: production, sandbox.
        result.environment = input.environment == 0 ? .production : .sandbox
        result.pushType = PushType(rawValue: input.pushType ?? "alert") ?? .alert
        result.priority = (input.priority ?? "immediately").hasPrefix("imm") ? .immediate : .conserve
        result.collapseId = input.collapseId ?? ""
        result.deviceToken = input.deviceToken ?? ""
        result.notificationId = input.notificationId ?? ""
        result.expiration = input.expiration ?? ""

        if let key = input.keyAuthentication {
            result.keyAuthentication.teamId = key.teamId ?? ""
            result.keyAuthentication.keyId = key.keyId ?? ""
            result.keyAuthentication.cachedContent = key.cachedContent
            if let file = key.file {
                result.keyAuthentication.file = FileReference(url: file.url, data: file.data)
                if result.keyAuthentication.cachedContent == nil, let data = file.data {
                    result.keyAuthentication.cachedContent = String(data: data, encoding: .utf8)
                }
            }
        }
        if let cert = input.certifcateAuthentication {
            result.certificateAuthentication.passphrase = cert.passphrase ?? ""
            if let file = cert.file {
                result.certificateAuthentication.file = FileReference(url: file.url, data: file.data)
            }
        }

        // The authentication index is not documented, so decide from the data that is actually present.
        let hasKey = result.keyAuthentication.keyContent != nil
        let hasCert = result.certificateAuthentication.file?.data != nil
        switch (input.authentication, hasKey, hasCert) {
        case (0, _, _): result.authentication = hasKey || !hasCert ? .key : .certificate
        case (_, false, true): result.authentication = .certificate
        case (_, true, false): result.authentication = .key
        case (1, _, _): result.authentication = .keychain
        case (2, _, _): result.authentication = .certificate
        default: result.authentication = .key
        }

        return PushTemplate(id: id, name: name ?? "Imported", input: result)
    }
}
