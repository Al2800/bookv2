import SwiftUI
import UIKit

struct CaptureReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CaptureDraft
    @State private var showSavedMessage = false
    @State private var didSave = false

    init(draft: CaptureDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                if let capturedImage {
                    SectionCard {
                        VStack(alignment: .leading, spacing: Space.md) {
                            HStack {
                                Label("Captured page", systemImage: "viewfinder")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.ink)

                                Spacer()

                                Text(selectedBookTitle)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.inkMuted)
                            }

                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                }
                        }
                    }
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        if !store.books.isEmpty {
                            Picker("Book", selection: $draft.selectedBookID) {
                                ForEach(store.books) { book in
                                    Text(book.title).tag(Optional(book.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Text(selectedBookTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.ink)

                        TextField("What did this page contain?", text: $draft.sourceNote, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(.inkSoft)
                            .lineLimit(2...4)

                        Text("The review screen is where trust is won or lost. Each extracted passage should be immediately readable, editable, and worth saving.")
                            .font(.subheadline)
                            .foregroundStyle(.inkMuted)
                    }
                }

                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Extracted quotes")
                        .font(.headline)
                        .foregroundStyle(.ink)

                    ForEach($draft.extractedQuotes) { $quote in
                        EditableDraftQuoteCard(quote: $quote)
                    }
                }
            }
            .padding(Space.lg)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    didSave = true
                    draft.bookTitle = selectedBookTitle
                    store.saveDraftToLibrary(draft)
                    showSavedMessage = true
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: draft.selectedBookID) { _, newValue in
            guard let newValue,
                  let book = store.books.first(where: { $0.id == newValue })
            else {
                return
            }

            draft.bookTitle = book.title
        }
        .alert("Saved to library", isPresented: $showSavedMessage) {
            Button("Back to capture") {
                dismiss()
            }
        } message: {
            Text("The edited quotes were added to \(selectedBookTitle).")
        }
        .onDisappear {
            if !didSave {
                store.replaceDraft(draft)
            }
        }
    }

    private var selectedBookTitle: String {
        guard let selectedBookID = draft.selectedBookID,
              let book = store.books.first(where: { $0.id == selectedBookID })
        else {
            return draft.bookTitle
        }

        return book.title
    }

    private var canSave: Bool {
        draft.selectedBookID != nil &&
        draft.extractedQuotes.contains {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var capturedImage: UIImage? {
        guard let imageData = draft.capturedImageData else { return nil }
        return UIImage(data: imageData)
    }
}

#Preview {
    NavigationStack {
        CaptureReviewView(draft: CaptureDraft.template(for: SeedData.books[0]))
    }
    .environment(AppStore())
}

private struct EditableDraftQuoteCard: View {
    @Binding var quote: DraftQuote

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Space.md) {
                TextField("Extracted text", text: $quote.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.ink)
                    .lineLimit(3...8)

                HStack(spacing: Space.md) {
                    TextField("Page", value: $quote.page, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    TextField("Confidence", text: $quote.confidence)
                        .textFieldStyle(.roundedBorder)
                }

                TextField(
                    "Margin note",
                    text: Binding(
                        get: { quote.noteText },
                        set: { quote.noteText = $0 }
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            }
        }
    }
}
