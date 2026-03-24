import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var showingAddBook = false
    @State private var searchText = ""

    private var totalQuotes: Int {
        store.books.reduce(0) { $0 + $1.quoteCount }
    }

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.books }

        return store.books.filter { book in
            let haystacks = [
                book.title,
                book.author,
                book.summary,
                book.quotes.map(\.text).joined(separator: "\n"),
                book.quotes.compactMap(\.note).joined(separator: "\n")
            ]

            return haystacks.joined(separator: "\n").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    LibrarySummaryCard(
                        bookCount: store.books.count,
                        quoteCount: totalQuotes,
                        onAddBook: { showingAddBook = true }
                    )

                    if store.books.isEmpty {
                        EmptyLibraryCard {
                            showingAddBook = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: Space.md) {
                            SectionIntro(
                                eyebrow: "Shelf",
                                title: searchText.isEmpty ? "Books" : "Search results",
                                subtitle: searchText.isEmpty
                                    ? "Open a book, skim the saved lines, and keep capture one tap away."
                                    : "\(filteredBooks.count) match\(filteredBooks.count == 1 ? "" : "es") for “\(searchText)”."
                            )

                            if filteredBooks.isEmpty {
                                SectionCard {
                                    Text("No books or saved quotes match that search yet.")
                                        .font(.subheadline)
                                        .foregroundStyle(.inkSoft)
                                }
                            } else {
                                LazyVStack(spacing: Space.md) {
                                    ForEach(filteredBooks) { book in
                                        NavigationLink(value: book) {
                                            BookRowView(book: book)
                                        }
                                        .buttonStyle(.plain)
                                    }
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
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search books and saved quotes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.brand)
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookSheet { title, author, status, summary in
                    store.addBook(title: title, author: author, status: status, summary: summary)
                }
            }
        }
    }
}

private struct LibrarySummaryCard: View {
    let bookCount: Int
    let quoteCount: Int
    let onAddBook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                CapsuleTag(label: "OCR Library", tone: .accent)

                Text("A quiet shelf for the lines you marked on paper.")
                    .font(.appHero)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Keep books visible, quotes readable, and the next capture close at hand.")
                    .font(.subheadline)
                    .foregroundStyle(.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.sm) {
                    summaryPills
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    summaryPills
                }
            }

            Button(action: onAddBook) {
                Label("Add Book", systemImage: "plus")
                    .font(.headline.weight(.semibold))
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.card, Color.paper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(Color.quoteBorder.opacity(0.85), lineWidth: StrokeWidth.hairline)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 6)
    }

    @ViewBuilder
    private var summaryPills: some View {
        SummaryPill(systemImage: "books.vertical", text: "\(bookCount) \(bookCount == 1 ? "book" : "books")")
        SummaryPill(systemImage: "text.quote", text: "\(quoteCount) saved")
        SummaryPill(systemImage: "viewfinder.circle", text: "OCR ready")
    }
}

private struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: Space.lg) {
            CoverArtworkView(title: book.title, author: book.author)
                .frame(width: 86, height: 118)

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .top) {
                    CapsuleTag(label: book.status, tone: .brand)

                    Spacer(minLength: 0)

                    SummaryPill(systemImage: "text.quote", text: "\(book.quoteCount)")
                }

                Text(book.title)
                    .font(.appTitle)
                    .foregroundStyle(.ink)
                    .lineLimit(2)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.inkSoft)
                    .lineLimit(1)

                Text(book.summary)
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(Space.lg)
        .paperCard()
    }
}

private struct EmptyLibraryCard: View {
    let onAddBook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionIntro(
                eyebrow: "Start",
                title: "No books yet",
                subtitle: "Create the first book, then capture marked pages into something worth reopening."
            )

            Button(action: onAddBook) {
                Label("Add your first book", systemImage: "plus")
                    .font(.headline.weight(.semibold))
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .padding(Space.xl)
        .paperCard(cornerRadius: Radius.xl)
    }
}

private struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var summary = ""
    @State private var status = Book.statusOptions[0]

    let onSave: (String, String, String, String) -> Void

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    SectionIntro(
                        eyebrow: "New Book",
                        title: "Add a book before you scan against it.",
                        subtitle: "Keep this quick: title, author, status, and a short reason it belongs on the shelf."
                    )

                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("Book")
                            .font(.appSection)
                            .foregroundStyle(.ink)

                        TextField("Title", text: $title)
                            .font(.body)
                            .fieldChrome(minHeight: 52)

                        TextField("Author", text: $author)
                            .font(.body)
                            .fieldChrome(minHeight: 52)
                    }
                    .padding(Space.lg)
                    .paperCard()

                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("Status")
                            .font(.appSection)
                            .foregroundStyle(.ink)

                        FlowLayout(spacing: Space.sm) {
                            ForEach(Book.statusOptions, id: \.self) { option in
                                Button {
                                    status = option
                                } label: {
                                    CapsuleTag(
                                        label: option,
                                        tone: status == option ? .accent : .neutral
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(Space.lg)
                    .paperCard()

                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("Why keep it here?")
                            .font(.appSection)
                            .foregroundStyle(.ink)

                        TextField(
                            "A short note about the kind of lines you want to save from this book",
                            text: $summary,
                            axis: .vertical
                        )
                        .font(.body)
                        .lineLimit(4...6)
                        .fieldChrome(minHeight: 110)
                    }
                    .padding(Space.lg)
                    .paperCard()
                }
                .padding(Space.lg)
                .padding(.bottom, 120)
                .appContentColumn(maxWidth: 680)
            }
            .appScreenBackground()
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(title, author, status, summary)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()

                    Button {
                        onSave(title, author, status, summary)
                        dismiss()
                    } label: {
                        Text("Save Book")
                            .font(.headline.weight(.semibold))
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!canSave)
                    .padding(Space.lg)
                    .background(Color.card.opacity(0.98))
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LibraryView()
        .environment(AppStore())
}
