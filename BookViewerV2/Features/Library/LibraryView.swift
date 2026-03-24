import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: Space.md) {
                            HStack {
                                CapsuleTag(label: "Library")

                                Spacer()

                                Text("\(store.books.reduce(0) { $0 + $1.quoteCount }) saved")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.inkMuted)
                            }

                            Text("Keep the lines worth keeping.")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.ink)

                            Text("Capture fast. Review cleanly. Find them later.")
                                .font(.subheadline)
                                .foregroundStyle(.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: Space.md) {
                                LibraryStatView(label: "Books", value: "\(store.books.count)")
                                LibraryStatView(label: "Quotes", value: "\(store.books.reduce(0) { $0 + $1.quoteCount })")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.md) {
                        HStack {
                            Text("Books")
                                .font(.headline)
                                .foregroundStyle(.ink)

                            Spacer()

                            if !store.books.isEmpty {
                                Text("\(store.books.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.inkMuted)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.wash, in: Capsule())
                            }
                        }

                        if store.books.isEmpty {
                            SectionCard {
                                VStack(alignment: .leading, spacing: Space.sm) {
                                    Text("No books yet")
                                        .font(.headline)
                                        .foregroundStyle(.ink)

                                    Text("Add one book and make sure saving a passage feels effortless.")
                                        .font(.subheadline)
                                        .foregroundStyle(.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Button("Add your first book") {
                                        showingAddBook = true
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.paper)
                                    .padding(.horizontal, Space.md)
                                    .padding(.vertical, Space.sm)
                                    .background(Color.ink, in: Capsule())
                                }
                            }
                        } else {
                            ForEach(store.books) { book in
                                NavigationLink(value: book) {
                                    BookRowView(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Space.lg)
                .padding(.bottom, Space.xl)
                .appContentColumn()
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Book Viewer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
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

private struct BookRowView: View {
    let book: Book

    var body: some View {
        SectionCard {
            HStack(alignment: .center, spacing: Space.md) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.wash)
                    .frame(width: 58, height: 82)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.title3)
                            .foregroundStyle(.inkSoft)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.line, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(.ink)
                        .lineLimit(2)

                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.inkSoft)
                        .lineLimit(1)

                    Text(book.summary)
                        .font(.footnote)
                        .foregroundStyle(.inkMuted)
                        .lineLimit(2)

                    HStack(spacing: Space.sm) {
                        CapsuleTag(label: book.status)
                        Text("\(book.quoteCount) saved")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.inkMuted)
                    }
                    .padding(.top, Space.xs)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct LibraryStatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.ink)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(Color.wash, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
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
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)

                    Picker("Status", selection: $status) {
                        ForEach(Book.statusOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("Summary") {
                    TextField("Optional note about why this book belongs here", text: $summary, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
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
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    LibraryView()
        .environment(AppStore())
}
