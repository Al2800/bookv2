import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text("A simpler library")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.ink)

                            Text("V2 starts with one promise: it should be easy to capture a meaningful passage, trust the review screen, and find it again later.")
                                .font(.body)
                                .foregroundStyle(.inkSoft)

                            HStack(spacing: Space.md) {
                                LibraryStatView(label: "Books", value: "\(store.books.count)")
                                LibraryStatView(label: "Quotes", value: "\(store.books.reduce(0) { $0 + $1.quoteCount })")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("Library")
                            .font(.headline)
                            .foregroundStyle(.ink)

                        if store.books.isEmpty {
                            SectionCard {
                                VStack(alignment: .leading, spacing: Space.sm) {
                                    Text("No books yet")
                                        .font(.headline)
                                        .foregroundStyle(.ink)

                                    Text("Start small. Add one book and test whether saving a passage feels obviously correct.")
                                        .font(.body)
                                        .foregroundStyle(.inkSoft)

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
            HStack(alignment: .top, spacing: Space.md) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.wash)
                    .frame(width: 54, height: 76)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.title3)
                            .foregroundStyle(.inkSoft)
                    }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(.ink)

                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.inkSoft)

                    Text(book.summary)
                        .font(.subheadline)
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
        .background(Color.wash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
