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
                VStack(alignment: .leading, spacing: Space.lg) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: Space.md) {
                            CapsuleTag(label: "OCR-first")

                            Text("Capture should feel lighter than writing the quote down.")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.ink)

                            Text("Pick the book, frame one marked page, and move straight into review.")
                                .font(.subheadline)
                                .foregroundStyle(.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if store.books.isEmpty {
                        SectionCard {
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text("No books yet")
                                    .font(.headline)
                                    .foregroundStyle(.ink)

                                Text("Library comes first. Add one book, then capture against it.")
                                    .font(.subheadline)
                                    .foregroundStyle(.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        SectionCard {
                            VStack(alignment: .leading, spacing: Space.md) {
                                HStack {
                                    Text("Target book")
                                        .font(.headline)
                                        .foregroundStyle(.ink)

                                    Spacer()

                                    if let selectedBook {
                                        Text("\(selectedBook.quoteCount) saved")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.inkMuted)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.wash, in: Capsule())
                                    }
                                }

                                Picker("Book", selection: selectedBookID) {
                                    ForEach(store.books) { book in
                                        Text(book.title).tag(book.id)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text("One page, one marked passage, one clean review.")
                                    .font(.subheadline)
                                    .foregroundStyle(.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        CapturePreviewCard(
                            imageData: capturedImageData,
                            captureNote: $captureNote,
                            isLoadingImage: isLoadingImage
                        )

                        captureActionButtons

                        SectionCard {
                            VStack(alignment: .leading, spacing: Space.md) {
                                Text("Flow")
                                    .font(.headline)
                                    .foregroundStyle(.ink)

                                ForEach(Array(store.draftCapture.guidance.enumerated()), id: \.offset) { index, step in
                                    CaptureStepRow(number: index + 1, text: step)
                                }
                            }
                        }

                        if capturedImageData != nil {
                            Button {
                                beginReview()
                            } label: {
                                HStack(alignment: .center, spacing: Space.md) {
                                    if isExtractingText {
                                        ProgressView()
                                            .tint(.paper)
                                    }

                                    Image(systemName: "sparkles.rectangle.stack")
                                        .font(.headline)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isExtractingText ? "Extracting text…" : "Review extraction")
                                            .font(.headline.weight(.semibold))

                                        Text("Run local OCR and edit the marked passage.")
                                            .font(.caption)
                                            .foregroundStyle(Color.paper.opacity(0.78))
                                    }
                                }
                                .foregroundStyle(.paper)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Space.lg)
                                .padding(.vertical, Space.md)
                                .background(Color.ink, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isExtractingText)
                        }
                    }
                }
                .padding(Space.lg)
                .padding(.bottom, Space.xl)
                .appContentColumn()
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Capture")
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
            CaptureActionButtonLabel(
                title: cameraButtonTitle,
                subtitle: cameraButtonSubtitle,
                systemImage: "camera"
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCameraAvailable)
    }

    private var photoLibraryActionButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            CaptureActionButtonLabel(
                title: "Photo Library",
                subtitle: "Import an existing page shot",
                systemImage: "photo.on.rectangle"
            )
        }
        .buttonStyle(.plain)
    }

    private var cameraButtonTitle: String {
        isCameraAvailable ? "Camera" : "Camera Unavailable"
    }

    private var cameraButtonSubtitle: String {
        isCameraAvailable ? "Capture a page now" : "Use a device camera"
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

#Preview {
    CaptureHomeView()
        .environment(AppStore())
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
        SectionCard {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack {
                    Text("Captured page")
                        .font(.headline)
                        .foregroundStyle(.ink)

                    Spacer()

                    if imageData != nil {
                        Text("1 page")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.inkMuted)
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(Color.wash.opacity(0.75))

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

                            Text(isLoadingImage ? "Preparing image…" : "Capture or import one page")
                                .font(.headline)
                                .foregroundStyle(.ink)

                            Text("One obvious marked passage works best.")
                                .font(.subheadline)
                                .foregroundStyle(.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Space.lg)
                        }
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(Color.line, lineWidth: 1)
                        .overlay(alignment: .center) {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(Color.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                                .padding(Space.md)
                        }
                }

                Text("Page note")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.inkMuted)

                TextField("Optional note about the page or marking", text: $captureNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
    }
}

private struct CaptureActionButtonLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.paper)
                .frame(width: 38, height: 38)
                .background(Color.ink, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(minHeight: 82)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card.opacity(0.86), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Color.line, lineWidth: 1)
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
                .foregroundStyle(.paper)
                .frame(width: 24, height: 24)
                .background(Color.ink, in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }

            parent.dismiss()
        }
    }
}

private extension UIImage {
    func preparedCaptureData(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.72) -> Data? {
        let longestSide = max(size.width, size.height)
        let scale = min(1, maxDimension / max(longestSide, 1))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return image.jpegData(compressionQuality: compressionQuality)
    }
}
