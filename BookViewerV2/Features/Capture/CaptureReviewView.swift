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
            VStack(alignment: .leading, spacing: Space.xl) {
                ReviewSummaryCard(
                    draft: $draft,
                    books: store.books,
                    selectedBookTitle: selectedBookTitle
                )

                if let capturedImage {
                    SectionCard {
                        VStack(alignment: .leading, spacing: Space.md) {
                            SectionIntro(
                                eyebrow: "Captured Page",
                                title: "Source image",
                                subtitle: "Keep this as the visual check while you trim the OCR draft."
                            )

                            Image(uiImage: capturedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                        .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
                                }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Space.md) {
                    SectionIntro(
                        eyebrow: "Draft Quotes",
                        title: draft.extractedQuotes.isEmpty ? "No clean passage yet" : "\(draft.extractedQuotes.count) draft passage\(draft.extractedQuotes.count == 1 ? "" : "s")",
                        subtitle: "Keep the real line. Remove page furniture, OCR noise, and anything you do not want to revisit."
                    )

                    Button {
                        addManualQuote()
                    } label: {
                        Label("Add quote manually", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.brand)

                    if draft.extractedQuotes.isEmpty {
                        EmptyReviewState {
                            addManualQuote()
                        }
                    } else {
                        LazyVStack(spacing: Space.md) {
                            ForEach(Array(draft.extractedQuotes.enumerated()), id: \.element.id) { index, quote in
                                EditableDraftQuoteCard(
                                    index: index + 1,
                                    quote: $draft.extractedQuotes[index],
                                    onRemove: {
                                        removeQuote(id: quote.id)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(Space.lg)
            .padding(.bottom, 140)
            .appContentColumn()
        }
        .appScreenBackground()
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()

                VStack(spacing: Space.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ready to save")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.ink)

                            Text("\(validQuoteCount) quote\(validQuoteCount == 1 ? "" : "s") for \(selectedBookTitle)")
                                .font(.caption)
                                .foregroundStyle(.inkSoft)
                                .lineLimit(1)
                        }

                        Spacer()
                    }

                    Button {
                        didSave = true
                        draft.bookTitle = selectedBookTitle
                        store.saveDraftToLibrary(draft)
                        showSavedMessage = true
                    } label: {
                        Label("Save to Library", systemImage: "tray.and.arrow.down.fill")
                            .font(.headline.weight(.semibold))
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!canSave)
                }
                .padding(Space.lg)
                .background(Color.card.opacity(0.98))
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

    private var validQuoteCount: Int {
        draft.extractedQuotes.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    private var canSave: Bool {
        draft.selectedBookID != nil && validQuoteCount > 0
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

private struct ReviewSummaryCard: View {
    @Binding var draft: CaptureDraft
    let books: [Book]
    let selectedBookTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionIntro(
                eyebrow: "Review",
                title: selectedBookTitle,
                subtitle: "Tighten the OCR result before it becomes a saved quote."
            )

            if !books.isEmpty {
                Picker("Book", selection: $draft.selectedBookID) {
                    ForEach(books) { book in
                        Text(book.title).tag(Optional(book.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.brand)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Page note")
                    .font(.appMeta)
                    .foregroundStyle(.inkMuted)

                TextField("What did this page contain?", text: $draft.sourceNote, axis: .vertical)
                    .lineLimit(3...5)
                    .fieldChrome(minHeight: 88)
            }
        }
        .padding(Space.xl)
        .paperCard(cornerRadius: Radius.xl)
    }
}

private struct EditableDraftQuoteCard: View {
    let index: Int
    @Binding var quote: DraftQuote
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                CapsuleTag(label: "Draft \(index)", tone: .accent)
                Spacer()
                CapsuleTag(label: quote.confidence, tone: confidenceTone)
            }

            TextField("Extracted text", text: $quote.text, axis: .vertical)
                .font(.quoteBody)
                .lineLimit(4...10)
                .fieldChrome(minHeight: 120)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.md) {
                    pageField
                    noteField
                }

                VStack(spacing: Space.md) {
                    pageField
                    noteField
                }
            }

            Button(role: .destructive, action: onRemove) {
                Label("Remove this draft", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.inkMuted)
        }
        .padding(Space.lg)
        .paperCard()
    }

    private var confidenceTone: CapsuleTag.Tone {
        quote.confidence == "Manual" ? .brand : .neutral
    }

    private var pageField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Page")
                .font(.appMeta)
                .foregroundStyle(.inkMuted)

            TextField("Page", value: $quote.page, format: .number)
                .keyboardType(.numberPad)
                .fieldChrome(minHeight: 52)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Margin note")
                .font(.appMeta)
                .foregroundStyle(.inkMuted)

            TextField(
                "Optional note",
                text: Binding(
                    get: { quote.noteText },
                    set: { quote.noteText = $0 }
                ),
                axis: .vertical
            )
            .lineLimit(2...4)
            .fieldChrome(minHeight: 52)
        }
    }
}

private struct EmptyReviewState: View {
    let onAddQuote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionIntro(
                eyebrow: "Fallback",
                title: "OCR didn’t isolate the passage cleanly.",
                subtitle: "Keep moving. Add the quote manually, then save it into the library."
            )

            Button(action: onAddQuote) {
                Label("Add quote manually", systemImage: "square.and.pencil")
                    .font(.headline.weight(.semibold))
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .padding(Space.xl)
        .paperCard(cornerRadius: Radius.xl)
    }
}

#Preview {
    NavigationStack {
        CaptureReviewView(draft: CaptureDraft.template(for: SeedData.books[0]))
    }
    .environment(AppStore())
}
