import Foundation

struct Book: Identifiable, Hashable, Codable {
    static let statusOptions = ["Reading", "Finished", "Want to Read"]

    let id: UUID
    var title: String
    var author: String
    var status: String
    var summary: String
    var quotes: [Quote]

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        status: String,
        summary: String,
        quotes: [Quote]
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.status = status
        self.summary = summary
        self.quotes = quotes
    }

    var quoteCount: Int {
        quotes.count
    }
}
