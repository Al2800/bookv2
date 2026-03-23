import Foundation

struct CaptureDraft: Hashable, Codable {
    var selectedBookID: UUID?
    var bookTitle: String
    var sourceNote: String
    var capturedImageData: Data?
    var guidance: [String]
    var extractedQuotes: [DraftQuote]

    static let defaultGuidance = [
        "Choose the book before opening the camera.",
        "Capture one page at a time until the review flow feels effortless.",
        "Edit extracted text immediately instead of hiding corrections later."
    ]

    static func template(for book: Book?) -> CaptureDraft {
        CaptureDraft(
            selectedBookID: book?.id,
            bookTitle: book?.title ?? "Select a book",
            sourceNote: "",
            capturedImageData: nil,
            guidance: defaultGuidance,
            extractedQuotes: [
                DraftQuote(
                    text: "The real work of the artist is a way of being in the world.",
                    page: 12,
                    confidence: "High",
                    marginNote: "This is the line to save."
                ),
                DraftQuote(
                    text: "Awareness is the instrument of choice.",
                    page: 45,
                    confidence: "Medium",
                    marginNote: nil
                )
            ]
        )
    }
}

struct DraftQuote: Identifiable, Hashable, Codable {
    let id: UUID
    var text: String
    var page: Int
    var confidence: String
    var marginNote: String?

    init(
        id: UUID = UUID(),
        text: String,
        page: Int,
        confidence: String,
        marginNote: String?
    ) {
        self.id = id
        self.text = text
        self.page = page
        self.confidence = confidence
        self.marginNote = marginNote
    }

    var noteText: String {
        get { marginNote ?? "" }
        set { marginNote = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue }
    }
}
