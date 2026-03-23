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
                    HStack(alignment: .center) {
                        Text("Extracted quotes")
                            .font(.headline)
                            .foregroundStyle(.ink)

                        Spacer()

                        Button {
                            addManualQuote()
                        } label: {
                            Label("Add quote", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.ink)
                    }

                    Text("OCR should give you a fast first draft, not a final answer. Keep the marked passage, delete the noise, and add anything it missed.")
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)

                    if draft.extractedQuotes.isEmpty {
                        EmptyReviewState {
                            addManualQuote()
                        }
                    } else {
                        ForEach(Array(draft.extractedQuotes.enumerated()), id: \.element.id) { index, quote in
                            EditableDraftQuoteCard(
                                quote: $draft.extractedQuotes[index],
                                onRemove: {
                                    removeQuote(id: quote.id)
                                }
                            )
                        }
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

    private func addManualQuote() {
        draft.extractedQuotes.append(
            DraftQuote(
                text: "",
                page: draft.extractedQuotes.first?.page ?? 1,
                confidence: "Manual",
                marginNote: nil
            )
        )
    }

    private func removeQuote(id: UUID) {
        draft.extractedQuotes.removeAll { $0.id == id }
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
    let onRemove: () -> Void

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(alignment: .center) {
                    Text("Draft passage")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.ink)

                    Spacer()

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.inkMuted)
                }

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

private struct EmptyReviewState: View {
    let onAddQuote: () -> Void

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("No usable quote yet")
                    .font(.headline)
                    .foregroundStyle(.ink)

                Text("OCR could not find a clean passage worth saving. Add the marked quote manually and keep moving.")
                    .font(.body)
                    .foregroundStyle(.inkSoft)

                Button {
                    onAddQuote()
                } label: {
                    Label("Add quote manually", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(Color.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
