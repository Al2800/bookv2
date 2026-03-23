import Foundation
import ImageIO
import UIKit
@preconcurrency import Vision

struct PageExtractionResult {
    var quotes: [DraftQuote]
    var suggestedSourceNote: String
}

enum PageTextExtractor {
    static func extract(from imageData: Data) async -> PageExtractionResult {
        do {
            return try await recognizeText(from: imageData)
        } catch {
            return PageExtractionResult(
                quotes: [
                    DraftQuote(
                        text: "",
                        page: 1,
                        confidence: "Low",
                        marginNote: "No text was detected. Type the marked passage manually."
                    )
                ],
                suggestedSourceNote: "No readable text was detected on the page. Review manually."
            )
        }
    }

    private static func recognizeText(from imageData: Data) async throws -> PageExtractionResult {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw ExtractionError.unreadableImage
        }

        let observations = try await performRequest(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )

        let lines = observations
            .compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let normalized = normalize(candidate.string)
                guard !normalized.isEmpty else { return nil }

                return RecognizedLine(
                    text: normalized,
                    confidence: candidate.confidence,
                    bounds: observation.boundingBox
                )
            }
            .sorted(by: readingOrder)

        guard !lines.isEmpty else {
            throw ExtractionError.noTextFound
        }

        let pageNumber = detectPageNumber(in: lines)
        let contentLines = stripPageNumber(from: lines.map(\.text), pageNumber: pageNumber)
        let quoteTexts = buildQuoteTexts(from: contentLines)
        let averageConfidence = lines.map(\.confidence).reduce(0, +) / Float(lines.count)
        let confidenceLabel = label(for: averageConfidence)

        let quotes = quoteTexts.enumerated().map { _, text in
            DraftQuote(
                text: text,
                page: pageNumber ?? 1,
                confidence: confidenceLabel,
                marginNote: nil
            )
        }

        return PageExtractionResult(
            quotes: quotes.isEmpty
                ? [
                    DraftQuote(
                        text: "",
                        page: pageNumber ?? 1,
                        confidence: confidenceLabel,
                        marginNote: "OCR ran, but the result needs manual cleanup."
                    )
                ]
                : quotes,
            suggestedSourceNote: "Local OCR detected \(lines.count) lines. Trim this down to the marked passage."
        )
    }

    private static func performRequest(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.015

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readingOrder(_ lhs: RecognizedLine, _ rhs: RecognizedLine) -> Bool {
        if abs(lhs.bounds.midY - rhs.bounds.midY) > 0.02 {
            return lhs.bounds.midY > rhs.bounds.midY
        }

        return lhs.bounds.minX < rhs.bounds.minX
    }

    private static func detectPageNumber(in lines: [RecognizedLine]) -> Int? {
        for line in lines.suffix(4).reversed() {
            let cleaned = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.range(of: #"^(?:p\.?\s*)?\d{1,4}$"#, options: .regularExpression) != nil {
                return Int(cleaned.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))
            }
        }

        return nil
    }

    private static func stripPageNumber(from lines: [String], pageNumber: Int?) -> [String] {
        guard let pageNumber else { return lines }
        let pageToken = String(pageNumber)

        var remaining = lines
        if let lastIndex = remaining.lastIndex(where: { line in
            let digitsOnly = line.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return digitsOnly == pageToken
        }) {
            remaining.remove(at: lastIndex)
        }

        return remaining
    }

    private static func buildQuoteTexts(from lines: [String]) -> [String] {
        var chunks: [String] = []
        var current = ""

        for line in lines {
            let next = current.isEmpty ? line : "\(current) \(line)"

            if next.count > 260, !current.isEmpty {
                chunks.append(current)
                current = line
            } else {
                current = next
            }

            if current.count >= 180,
               line.last.map({ ".!?".contains($0) }) == true {
                chunks.append(current)
                current = ""
            }

            if chunks.count == 2 {
                break
            }
        }

        if !current.isEmpty && chunks.count < 2 {
            chunks.append(current)
        }

        return chunks
            .map(normalize)
            .filter { !$0.isEmpty }
    }

    private static func label(for confidence: Float) -> String {
        switch confidence {
        case 0.82...:
            return "High"
        case 0.6...:
            return "Medium"
        default:
            return "Low"
        }
    }
}

private struct RecognizedLine {
    var text: String
    var confidence: Float
    var bounds: CGRect
}

private enum ExtractionError: Error {
    case unreadableImage
    case noTextFound
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
