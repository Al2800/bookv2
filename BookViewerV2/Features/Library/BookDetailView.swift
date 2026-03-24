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
                    VStack(alignment: .leading, spacing: Space.xl) {
                        BookHeaderCard(book: book)

                        VStack(alignment: .leading, spacing: Space.md) {
                            SectionIntro(
                                eyebrow: "Saved",
                                title: "Quotes",
                                subtitle: book.quotes.isEmpty
                                    ? "No passages saved yet."
                                    : "\(book.quotes.count) passage\(book.quotes.count == 1 ? "" : "s") saved from this book."
                            )

                            if book.quotes.isEmpty {
                                SectionCard {
                                    Text("Capture a marked page when you’re ready. The OCR draft will land here after review.")
                                        .font(.subheadline)
                                        .foregroundStyle(.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                LazyVStack(spacing: Space.md) {
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
                    }
                    .padding(Space.lg)
                    .padding(.bottom, Space.xxl)
                    .appContentColumn()
                }
                .appScreenBackground()
                .navigationTitle(book.title)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Book not found", systemImage: "book.closed")
            }
        }
    }
}

private struct BookHeaderCard: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            CoverArtworkView(title: book.title, author: book.author)
                .frame(width: 112, height: 154)

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    CapsuleTag(label: book.status, tone: .brand)
                    Spacer(minLength: 0)
                    SummaryPill(systemImage: "text.quote", text: "\(book.quoteCount) saved")
                }

                Text(book.title)
                    .font(.appHero)
                    .foregroundStyle(.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.inkSoft)

                Text(book.summary)
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.xl)
        .paperCard(cornerRadius: Radius.xl)
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: SeedData.books[0])
    }
    .environment(AppStore())
}
