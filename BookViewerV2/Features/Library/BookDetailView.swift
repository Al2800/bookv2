import SwiftUI

struct BookDetailView: View {
    @Environment(AppStore.self) private var store

    private let bookID: UUID

    init(book: Book) {
        self.bookID = book.id
    }

    var body: some View {
        Group {
            if let book = store.books.first(where: { $0.id == bookID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        SectionCard {
                            VStack(alignment: .leading, spacing: Space.sm) {
                                CapsuleTag(label: book.status)

                                Text(book.title)
                                    .font(.largeTitle.weight(.semibold))
                                    .foregroundStyle(.ink)

                                Text(book.author)
                                    .font(.title3)
                                    .foregroundStyle(.inkSoft)

                                Text(book.summary)
                                    .font(.body)
                                    .foregroundStyle(.inkMuted)
                            }
                        }

                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Saved quotes")
                                .font(.headline)
                                .foregroundStyle(.ink)

                            if book.quotes.isEmpty {
                                SectionCard {
                                    Text("This book is still empty. In v2, empty states stay simple and keep the next action obvious: capture a page.")
                                        .font(.body)
                                        .foregroundStyle(.inkSoft)
                                }
                            } else {
                                ForEach(book.quotes) { quote in
                                    QuoteCardView(
                                        text: quote.text,
                                        note: quote.note,
                                        footer: "Page \(quote.page)"
                                    )
                                }
                            }
                        }
                    }
                    .padding(Space.lg)
                }
                .background(Color.paper.ignoresSafeArea())
                .navigationTitle(book.title)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Book not found", systemImage: "book.closed")
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: SeedData.books[0])
    }
    .environment(AppStore())
}
