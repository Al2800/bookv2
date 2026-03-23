import Foundation

struct Quote: Identifiable, Hashable, Codable {
    let id: UUID
    var text: String
    var page: Int
    var note: String?

    init(
        id: UUID = UUID(),
        text: String,
        page: Int,
        note: String?
    ) {
        self.id = id
        self.text = text
        self.page = page
        self.note = note
    }
}
