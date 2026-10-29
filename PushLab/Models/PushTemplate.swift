import Foundation

struct PushTemplate: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var input: PushInput
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, input: PushInput = PushInput(), createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.input = input
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: PushTemplate, rhs: PushTemplate) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.input == rhs.input
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func duplicated() -> PushTemplate {
        var copy = self
        copy.id = UUID()
        copy.input.id = copy.id
        copy.name = name + " copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        return copy
    }
}

struct TemplateExport: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var templates: [PushTemplate]
}
