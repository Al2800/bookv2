import SwiftUI

struct CaptureHomeView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text("Capture is the product")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.ink)

                            Text("The camera flow should feel lighter than taking a note by hand. V2 focuses on a short path: pick the book, frame the page, review the extracted quote.")
                                .font(.body)
                                .foregroundStyle(.inkSoft)
                        }
                    }

                    if store.books.isEmpty {
                        SectionCard {
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text("No book selected")
                                    .font(.headline)
                                    .foregroundStyle(.ink)

                                Text("Add a book in the library first. Capture should always be anchored to a known book.")
                                    .font(.body)
                                    .foregroundStyle(.inkSoft)
                            }
                        }
                    } else {
                        SectionCard {
                            VStack(alignment: .leading, spacing: Space.md) {
                                Text("Target book")
                                    .font(.headline)
                                    .foregroundStyle(.ink)

                                Picker("Book", selection: selectedBookID) {
                                    ForEach(store.books) { book in
                                        Text(book.title).tag(book.id)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text("Drafts are intentionally simple for now. The point is to prove that review-and-save feels obvious before the real camera arrives.")
                                    .font(.subheadline)
                                    .foregroundStyle(.inkMuted)
                            }
                        }

                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("Core flow")
                                .font(.headline)
                                .foregroundStyle(.ink)

                            ForEach(Array(store.draftCapture.guidance.enumerated()), id: \.offset) { index, step in
                                SectionCard {
                                    HStack(alignment: .top, spacing: Space.md) {
                                        Text("\(index + 1)")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.paper)
                                            .frame(width: 28, height: 28)
                                            .background(Color.ink, in: Circle())

                                        Text(step)
                                            .font(.body)
                                            .foregroundStyle(.ink)

                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }

                        NavigationLink {
                            CaptureReviewView(draft: store.draftCapture)
                        } label: {
                            Text("Open editable review")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.paper)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.md)
                                .background(Color.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Space.lg)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Capture")
            .onAppear {
                if store.draftCapture.selectedBookID == nil,
                   let firstBook = store.books.first {
                    store.prepareDraft(for: firstBook.id)
                }
            }
        }
    }

    private var selectedBookID: Binding<UUID> {
        Binding(
            get: {
                store.draftCapture.selectedBookID ?? store.books.first?.id ?? UUID()
            },
            set: { newValue in
                store.prepareDraft(for: newValue)
            }
        )
    }
}

#Preview {
    CaptureHomeView()
        .environment(AppStore())
}
