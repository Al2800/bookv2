import PhotosUI
import SwiftUI
import UIKit

struct CaptureHomeView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImageData: Data?
    @State private var captureNote = ""
    @State private var showCamera = false
    @State private var showReview = false
    @State private var isLoadingImage = false
    @State private var isExtractingText = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    CaptureSummaryCard()

                    if store.books.isEmpty {
                        SectionCard {
                            SectionIntro(
                                eyebrow: "Library",
                                title: "Add a book before you scan.",
                                subtitle: "Capture stays cleaner when every page already has a destination."
                            )
                        }
                    } else {
                        CaptureBookSelectionCard(
                            books: store.books,
                            selectedBookID: selectedBookID
                        )

                        CapturePreviewCard(
                            imageData: capturedImageData,
                            captureNote: $captureNote,
                            isLoadingImage: isLoadingImage
                        )

                        captureActionButtons

                        CaptureGuideCard(guidance: store.draftCapture.guidance)
                    }
                }
                .padding(Space.lg)
                .padding(.bottom, 140)
                .appContentColumn()
            }
            .appScreenBackground()
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showReview) {
                CaptureReviewView(draft: store.draftCapture)
            }
            .onAppear {
                syncFromStore()
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                loadPhotoItem(newValue)
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    capturedImageData = image.preparedCaptureData()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if capturedImageData != nil, !store.books.isEmpty {
                    reviewBar
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

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var selectedBook: Book? {
        store.books.first(where: { $0.id == selectedBookID.wrappedValue })
    }

    @ViewBuilder
    private var captureActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.md) {
                cameraActionButton
                photoLibraryActionButton
            }

            VStack(spacing: Space.md) {
                cameraActionButton
                photoLibraryActionButton
            }
        }
    }

    private var cameraActionButton: some View {
        Button {
            showCamera = true
        } label: {
            CaptureModeButtonLabel(
                title: isCameraAvailable ? "Use Camera" : "Camera Unavailable",
                subtitle: isCameraAvailable ? "Take a page shot right now" : "Use a device with a camera",
                systemImage: "camera.fill",
                tone: .brand
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCameraAvailable)
    }

    private var photoLibraryActionButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            CaptureModeButtonLabel(
                title: "Import Photo",
                subtitle: "Pull in an existing page capture",
                systemImage: "photo.on.rectangle.angled",
                tone: .accent
            )
        }
        .buttonStyle(.plain)
    }

    private var reviewBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: Space.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready for review")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.ink)

                        Text(selectedBook?.title ?? "Select a book")
                            .font(.caption)
                            .foregroundStyle(.inkSoft)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isExtractingText {
                        ProgressView()
                            .tint(.brand)
                    }
                }

                Button {
                    beginReview()
                } label: {
                    Label(
                        isExtractingText ? "Extracting text…" : "Run OCR and Review",
                        systemImage: "text.viewfinder"
                    )
                    .font(.headline.weight(.semibold))
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(isExtractingText)
            }
            .padding(Space.lg)
            .background(Color.card.opacity(0.98))
        }
    }

    private func syncFromStore() {
        if store.draftCapture.selectedBookID == nil,
           let firstBook = store.books.first {
            store.prepareDraft(for: firstBook.id)
        }

        captureNote = store.draftCapture.sourceNote
        capturedImageData = store.draftCapture.capturedImageData
    }

    private func loadPhotoItem(_ item: PhotosPickerItem) {
        isLoadingImage = true

        Task {
            defer { isLoadingImage = false }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let preparedData = image.preparedCaptureData()
            else {
                return
            }

            await MainActor.run {
                capturedImageData = preparedData
            }
        }
    }

    private func beginReview() {
        guard let selectedBook = store.books.first(where: { $0.id == selectedBookID.wrappedValue }),
              let capturedImageData
        else {
            return
        }

        isExtractingText = true

        Task {
            let extraction = await PageTextExtractor.extract(from: capturedImageData)
            var draft = CaptureDraft.template(for: selectedBook)

            let trimmedNote = captureNote.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.sourceNote = trimmedNote.isEmpty ? extraction.suggestedSourceNote : trimmedNote
            draft.capturedImageData = capturedImageData
            draft.extractedQuotes = extraction.quotes

            await MainActor.run {
                isExtractingText = false
                store.replaceDraft(draft)
                showReview = true
            }
        }
    }
}

private struct CaptureSummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                CapsuleTag(label: "OCR First", tone: .accent)

                Text("Scan one marked page and keep the review clean.")
                    .font(.appHero)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use the faster v1-style flow: choose the book, frame the page, then trim the OCR draft before saving.")
                    .font(.subheadline)
                    .foregroundStyle(.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.sm) {
                    SummaryPill(systemImage: "camera", text: "Single page")
                    SummaryPill(systemImage: "text.viewfinder", text: "OCR review")
                    SummaryPill(systemImage: "books.vertical", text: "Book-linked")
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    SummaryPill(systemImage: "camera", text: "Single page")
                    SummaryPill(systemImage: "text.viewfinder", text: "OCR review")
                    SummaryPill(systemImage: "books.vertical", text: "Book-linked")
                }
            }
        }
        .padding(Space.xl)
        .paperCard(cornerRadius: Radius.xl)
    }
}

private struct CaptureBookSelectionCard: View {
    let books: [Book]
    let selectedBookID: Binding<UUID>

    private var selectedBook: Book? {
        books.first(where: { $0.id == selectedBookID.wrappedValue })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionIntro(
                eyebrow: "Target Book",
                title: selectedBook?.title ?? "Choose a book",
                subtitle: "Keep every scan attached to the right book from the start."
            )

            Picker("Book", selection: selectedBookID) {
                ForEach(books) { book in
                    Text(book.title).tag(book.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.brand)

            if let selectedBook {
                HStack(spacing: Space.md) {
                    CoverArtworkView(title: selectedBook.title, author: selectedBook.author)
                        .frame(width: 72, height: 100)

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(selectedBook.author)
                            .font(.subheadline)
                            .foregroundStyle(.inkSoft)

                        Text(selectedBook.summary)
                            .font(.footnote)
                            .foregroundStyle(.inkMuted)
                            .lineLimit(3)

                        SummaryPill(systemImage: "text.quote", text: "\(selectedBook.quoteCount) saved")
                    }
                }
                .padding(.top, Space.xs)
            }
        }
        .padding(Space.lg)
        .paperCard()
    }
}

private struct CapturePreviewCard: View {
    let imageData: Data?
    @Binding var captureNote: String
    let isLoadingImage: Bool

    private var previewImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionIntro(
                eyebrow: "Captured Page",
                title: previewImage == nil ? "No page selected yet" : "Page ready for review",
                subtitle: "One clear marked passage works best."
            )

            ZStack {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Color.paperSecondary)

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .padding(Space.md)
                } else {
                    VStack(spacing: Space.sm) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.inkMuted)

                        Text(isLoadingImage ? "Preparing image…" : "Capture or import a page")
                            .font(.headline)
                            .foregroundStyle(.ink)

                        Text("Keep the page square and the marked line fully visible.")
                            .font(.subheadline)
                            .foregroundStyle(.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                    }
                }
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Page note")
                    .font(.appMeta)
                    .foregroundStyle(.inkMuted)

                TextField("Optional note about the page or the marking", text: $captureNote, axis: .vertical)
                    .lineLimit(2...4)
                    .fieldChrome(minHeight: 72)
            }
        }
        .padding(Space.lg)
        .paperCard()
    }
}

private struct CaptureGuideCard: View {
    let guidance: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionIntro(
                eyebrow: "Flow",
                title: "Keep the capture loop simple.",
                subtitle: nil
            )

            ForEach(Array(guidance.enumerated()), id: \.offset) { index, step in
                CaptureStepRow(number: index + 1, text: step)
            }
        }
        .padding(Space.lg)
        .paperCard()
    }
}

private struct CaptureModeButtonLabel: View {
    enum Tone {
        case brand
        case accent
    }

    let title: String
    let subtitle: String
    let systemImage: String
    let tone: Tone

    var body: some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)

                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.inkSoft)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.inkMuted)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    private var iconBackground: Color {
        switch tone {
        case .brand:
            return .brand.opacity(0.10)
        case .accent:
            return .accentSoft
        }
    }

    private var iconColor: Color {
        switch tone {
        case .brand:
            return .brand
        case .accent:
            return .brandLight
        }
    }
}

private struct CaptureStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.brand)
                .frame(width: 26, height: 26)
                .background(Color.brand.opacity(0.10), in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        controller.cameraCaptureMode = .photo
        controller.modalPresentationStyle = .fullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }

            picker.dismiss(animated: true)
        }
    }
}

private extension UIImage {
    func preparedCaptureData(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.72) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let size = self.size
        let longestSide = max(size.width, size.height)
        let scaleRatio = min(1, maxDimension / longestSide)
        let scaledSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)

        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        let image = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }

        return image.jpegData(compressionQuality: compressionQuality)
    }
}

#Preview {
    CaptureHomeView()
        .environment(AppStore())
}
