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

                                Text("Keep this step narrow. The goal is a clean handoff from page capture into review, not a feature-heavy camera screen.")
                                    .font(.subheadline)
                                    .foregroundStyle(.inkMuted)
                            }
                        }

                        CapturePreviewCard(
                            imageData: capturedImageData,
                            captureNote: $captureNote,
                            isLoadingImage: isLoadingImage
                        )

                        HStack(spacing: Space.md) {
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

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                CaptureActionButtonLabel(
                                    title: "Photo Library",
                                    subtitle: "Import an existing page shot",
                                    systemImage: "photo.on.rectangle"
                                )
                            }
                            .buttonStyle(.plain)
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

                        if capturedImageData != nil {
                            Button {
                                beginReview()
                            } label: {
                                HStack(alignment: .center, spacing: Space.md) {
                                    if isExtractingText {
                                        ProgressView()
                                            .tint(.paper)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isExtractingText ? "Extracting text…" : "Continue to review")
                                            .font(.headline.weight(.semibold))

                                        Text("Run local OCR, then carry this page straight into the editable review screen.")
                                            .font(.caption)
                                            .foregroundStyle(Color.paper.opacity(0.78))
                                    }
                                }
                                .foregroundStyle(.paper)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Space.lg)
                                .padding(.vertical, Space.md)
                                .background(Color.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isExtractingText)
                        }
                    }
                }
                .padding(Space.lg)
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

    private var cameraButtonTitle: String {
        isCameraAvailable ? "Camera" : "Camera Unavailable"
    }

    private var cameraButtonSubtitle: String {
        isCameraAvailable ? "Capture a page now" : "Use a real device for live capture"
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
                Text("Captured page")
                    .font(.headline)
                    .foregroundStyle(.ink)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.wash.opacity(0.75))

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: Space.sm) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(.inkMuted)

                            Text(isLoadingImage ? "Preparing image…" : "Capture or import one page")
                                .font(.headline)
                                .foregroundStyle(.ink)

                            Text("Keep it to one page and one obvious marked passage. Simpler input produces a better review screen.")
                                .font(.subheadline)
                                .foregroundStyle(.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Space.lg)
                        }
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        .overlay(alignment: .center) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                                .padding(Space.md)
                        }
                }

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
                .background(Color.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.inkMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
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
