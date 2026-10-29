import Foundation

/// JSON files in ~/Library/Containers/<bundle id>/Data/Library/Application Support/PushLab.
struct Persistence {
    let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("PushLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func url(for file: String) -> URL {
        directory.appendingPathComponent(file)
    }

    func load<T: Decodable>(_ type: T.Type, file: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: file)) else { return nil }
        return try? Self.decoder.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, file: String) {
        guard let data = try? Self.encoder.encode(value) else { return }
        try? data.write(to: url(for: file), options: .atomic)
    }
}
