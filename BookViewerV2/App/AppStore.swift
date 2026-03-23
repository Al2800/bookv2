import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var books: [Book]
    var draftCapture: CaptureDraft

    private let storageURL: URL

    init() {
        self.storageURL = Self.makeStorageURL()

        if let snapshot = Self.loadSnapshot(from: storageURL) {
            self.books = snapshot.books
            self.draftCapture = snapshot.draftCapture
        } else {
            self.books = SeedData.books
            self.draftCapture = CaptureDraft.template(for: SeedData.books.first)
            persist()
        }
    }

    func addBook(
        title: String,
        author: String,
        status: String,
        summary: String
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedAuthor.isEmpty else { return }

        let book = Book(
            title: trimmedTitle,
            author: trimmedAuthor,
            status: status,
            summary: trimmedSummary.isEmpty
                ? "A newly added book waiting for its first saved passage."
                : trimmedSummary,
            quotes: []
        )

        books.insert(book, at: 0)

        if draftCapture.selectedBookID == nil {
            draftCapture = CaptureDraft.template(for: book)
        }

        persist()
    }

    func prepareDraft(for bookID: UUID) {
        guard let book = books.first(where: { $0.id == bookID }) else { return }
        draftCapture = CaptureDraft.template(for: book)
        persist()
    }

    func replaceDraft(_ draft: CaptureDraft) {
        draftCapture = draft
        persist()
    }

    func saveDraftToLibrary(_ draft: CaptureDraft) {
        guard let selectedBookID = draft.selectedBookID,
              let index = books.firstIndex(where: { $0.id == selectedBookID })
        else {
            return
        }

        let cleanedQuotes = draft.extractedQuotes.compactMap { draftQuote -> Quote? in
            let trimmedText = draftQuote.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return nil }

            let trimmedNote = draftQuote.marginNote?.trimmingCharacters(in: .whitespacesAndNewlines)

            return Quote(
                text: trimmedText,
                page: max(1, draftQuote.page),
                note: trimmedNote?.isEmpty == true ? nil : trimmedNote
            )
        }

        guard !cleanedQuotes.isEmpty else { return }

        books[index].quotes.insert(contentsOf: cleanedQuotes, at: 0)
        draftCapture = CaptureDraft.template(for: books[index])
        persist()
    }

    private func persist() {
        let snapshot = Snapshot(books: books, draftCapture: draftCapture)

        do {
            let folderURL = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let data = try JSONEncoder.snapshotEncoder.encode(snapshot)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to persist app state: \(error)")
        }
    }

    private static func loadSnapshot(from url: URL) -> Snapshot? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder.snapshotDecoder.decode(Snapshot.self, from: data)
        } catch {
            return nil
        }
    }

    private static func makeStorageURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("BookViewerV2", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }
}

private struct Snapshot: Codable {
    var books: [Book]
    var draftCapture: CaptureDraft
}

private extension JSONEncoder {
    static var snapshotEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var snapshotDecoder: JSONDecoder {
        JSONDecoder()
    }
}

enum SeedData {
    static let books: [Book] = [
        Book(
            title: "The Creative Act",
            author: "Rick Rubin",
            status: "Reading",
            summary: "A quiet library of ideas about making, attention, and staying receptive.",
            quotes: [
                Quote(
                    text: "The real work of the artist is a way of being in the world.",
                    page: 12,
                    note: "Core promise of the app: save the lines worth returning to."
                ),
                Quote(
                    text: "Awareness is the instrument of choice.",
                    page: 45,
                    note: "Short quotes should still feel valuable and visible."
                )
            ]
        ),
        Book(
            title: "Meditations",
            author: "Marcus Aurelius",
            status: "Finished",
            summary: "A compact example of why rediscovery matters more than endless organization.",
            quotes: [
                Quote(
                    text: "You have power over your mind, not outside events.",
                    page: 73,
                    note: "Book detail needs to privilege readability over controls."
                ),
                Quote(
                    text: "The impediment to action advances action.",
                    page: 81,
                    note: nil
                )
            ]
        ),
        Book(
            title: "Pilgrim at Tinker Creek",
            author: "Annie Dillard",
            status: "Want to Read",
            summary: "Included to keep the library honest: covers, status, and empty states matter.",
            quotes: []
        )
    ]
}
