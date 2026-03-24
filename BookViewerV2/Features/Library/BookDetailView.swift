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
                            HStack(alignment: .top, spacing: Space.md) {
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .fill(Color.wash)
                                    .frame(width: 78, height: 112)
                                    .overlay {
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(.inkSoft)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                            .stroke(Color.line, lineWidth: 1)
                                    }

                                VStack(alignment: .leading, spacing: Space.sm) {
                                    HStack {
                                        CapsuleTag(label: book.status)

                                        Spacer()

                                        Text("\(book.quoteCount) saved")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.inkMuted)
                                    }

                                    Text(book.title)
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(.ink)
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
                        }

                        VStack(alignment: .leading, spacing: Space.md) {
                            HStack {
                                Text("Saved quotes")
                                    .font(.headline)
                                    .foregroundStyle(.ink)

                                Spacer()

                                if !book.quotes.isEmpty {
                                    Text("\(book.quotes.count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.inkMuted)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.wash, in: Capsule())
                                }
                            }

                            if book.quotes.isEmpty {
                                SectionCard {
                                    Text("No saved passages yet. Capture a marked page when you are ready.")
                                        .font(.subheadline)
                                        .foregroundStyle(.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
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
                    .padding(.bottom, Space.xl)
                    .appContentColumn()
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
