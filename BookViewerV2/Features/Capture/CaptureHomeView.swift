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
                    CaptureHeaderView()

                    if store.books.isEmpty {
                        EmptyCaptureState()
                    } else {
                        CaptureWorkspaceCard(
                            books: store.books,
                            selectedBookID: selectedBookID,
                            imageData: capturedImageData,
                            captureNote: $captureNote,
                            isLoadingImage: isLoadingImage,
                            isCameraAvailable: isCameraAvailable,
                            onCameraTap: { showCamera = true },
                            selectedPhotoItem: $selectedPhotoItem
                        )

                        CaptureTipsStrip()
                    }
                }
                .padding(Space.lg)
                .padding(.bottom, 148)
                .appContentColumn()
            }
            .appScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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

    private var reviewBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: Space.sm) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
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
                        isExtractingText ? "Extracting OCR…" : "Review OCR Draft",
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

private struct CaptureHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            CapsuleTag(label: "Capture", tone: .accent)

            Text("One page in. One clean quote out.")
                .font(.appHero)
                .foregroundStyle(.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Choose the book, frame the marked passage, and move straight into OCR review.")
                .font(.subheadline)
                .foregroundStyle(.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyCaptureState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionIntro(
                eyebrow: "Library First",
                title: "Add a book before you capture.",
                subtitle: "The OCR flow works better when each page already has a destination."
            )
        }
        .padding(Space.xl)
        .paperCard(cornerRadius: Radius.xl)
    }
}

private struct CaptureWorkspaceCard: View {
    let books: [Book]
    let selectedBookID: Binding<UUID>
    let imageData: Data?
    @Binding var captureNote: String
    let isLoadingImage: Bool
    let isCameraAvailable: Bool
    let onCameraTap: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?

    private var selectedBook: Book? {
        books.first(where: { $0.id == selectedBookID.wrappedValue })
    }

    private var previewImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .top, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target book")
                        .font(.appMeta)
                        .foregroundStyle(.inkMuted)

                    Text(selectedBook?.title ?? "Choose a book")
                        .font(.appTitle)
                        .foregroundStyle(.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let selectedBook {
                    SummaryPill(systemImage: "text.quote", text: "\(selectedBook.quoteCount) saved")
                }
            }

            Picker("Book", selection: selectedBookID) {
                ForEach(books) { book in
                    Text(book.title).tag(book.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.brand)

            ZStack {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .fill(Color.paperSecondary)

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .padding(Space.sm)
                } else {
                    VStack(spacing: Space.sm) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.inkMuted)

                        Text(isLoadingImage ? "Preparing image…" : "Capture or import a marked page")
                            .font(.headline)
                            .foregroundStyle(.ink)

                        Text("Keep the page square and the marked line fully in frame.")
                            .font(.subheadline)
                            .foregroundStyle(.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                    }
                }
            }
            .frame(height: 380)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.md) {
                    cameraButton
                    libraryButton
                }

                VStack(spacing: Space.md) {
                    cameraButton
                    libraryButton
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Page note")
                    .font(.appMeta)
                    .foregroundStyle(.inkMuted)

                TextField("Optional note about the passage or the marking", text: $captureNote, axis: .vertical)
                    .lineLimit(2...4)
                    .fieldChrome(minHeight: 70)
            }
        }
        .padding(Space.lg)
        .paperCard(cornerRadius: Radius.xl)
    }

    private var cameraButton: some View {
        Button(action: onCameraTap) {
            CaptureActionButton(
                title: isCameraAvailable ? "Use Camera" : "Camera Unavailable",
                subtitle: isCameraAvailable ? "Take a page shot now" : "Use a device camera",
                systemImage: "camera.fill",
                tone: .brand
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCameraAvailable)
    }

    private var libraryButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            CaptureActionButton(
                title: "Import Photo",
                subtitle: "Use an existing page image",
                systemImage: "photo.on.rectangle.angled",
                tone: .accent
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CaptureActionButton: View {
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
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(iconForeground)
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
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.quoteBorder.opacity(0.9), lineWidth: StrokeWidth.hairline)
        }
    }

    private var iconBackground: Color {
        switch tone {
        case .brand:
            return .brand.opacity(0.10)
        case .accent:
            return .accentSoft
        }
    }

    private var iconForeground: Color {
        switch tone {
        case .brand:
            return .brand
        case .accent:
            return .brandLight
        }
    }
}

private struct CaptureTipsStrip: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.sm) {
                SummaryPill(systemImage: "sun.max", text: "Even light")
                SummaryPill(systemImage: "viewfinder", text: "Square frame")
                SummaryPill(systemImage: "highlighter", text: "One marked passage")
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                SummaryPill(systemImage: "sun.max", text: "Even light")
                SummaryPill(systemImage: "viewfinder", text: "Square frame")
                SummaryPill(systemImage: "highlighter", text: "One marked passage")
            }
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
