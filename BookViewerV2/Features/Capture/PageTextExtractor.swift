import Foundation
import ImageIO
import UIKit
@preconcurrency import Vision

struct PageExtractionResult {
    var quotes: [DraftQuote]
    var suggestedSourceNote: String
}

enum PageTextExtractor {
    private static let pageNumberPattern = #"^(?:p\.?\s*)?\d{1,4}$"#

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
        let contentLines = filterContentLines(from: lines, pageNumber: pageNumber)
        let candidates = candidateBlocks(from: contentLines)
        let quotes = makeDraftQuotes(from: candidates, pageNumber: pageNumber)
        let averageConfidence = (contentLines.isEmpty ? lines : contentLines)
            .map(\.confidence)
            .reduce(0, +) / Float((contentLines.isEmpty ? lines : contentLines).count)
        let confidenceLabel = label(for: averageConfidence)

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
            suggestedSourceNote: suggestedSourceNote(
                detectedLineCount: lines.count,
                selectedQuoteCount: quotes.count
            )
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
            if cleaned.range(of: pageNumberPattern, options: .regularExpression) != nil {
                return Int(cleaned.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))
            }
        }

        return nil
    }

    private static func filterContentLines(from lines: [RecognizedLine], pageNumber: Int?) -> [RecognizedLine] {
        var remaining = lines

        if let pageNumber,
           let lastIndex = remaining.lastIndex(where: { line in
               let digitsOnly = line.text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
               return digitsOnly == String(pageNumber)
           }) {
            remaining.remove(at: lastIndex)
        }

        return remaining.filter { !isLikelyNoiseLine($0) }
    }

    private static func isLikelyNoiseLine(_ line: RecognizedLine) -> Bool {
        let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        if trimmed.range(of: pageNumberPattern, options: .regularExpression) != nil {
            return true
        }

        let words = trimmed.split(whereSeparator: \.isWhitespace)
        if words.isEmpty {
            return true
        }

        let letterScalars = trimmed.unicodeScalars.filter(CharacterSet.letters.contains)
        let uppercaseRatio: Double
        if letterScalars.isEmpty {
            uppercaseRatio = 0
        } else {
            let uppercaseCount = letterScalars.filter(CharacterSet.uppercaseLetters.contains).count
            uppercaseRatio = Double(uppercaseCount) / Double(letterScalars.count)
        }

        if trimmed.count <= 2 {
            return true
        }

        if words.count <= 4,
           uppercaseRatio > 0.9,
           (line.bounds.midY > 0.82 || line.bounds.midY < 0.18) {
            return true
        }

        if words.count == 1,
           trimmed.count <= 5,
           line.bounds.midY < 0.12 {
            return true
        }

        return false
    }

    private static func candidateBlocks(from lines: [RecognizedLine]) -> [RecognizedTextBlock] {
        guard !lines.isEmpty else { return [] }

        var groupedLines: [[RecognizedLine]] = []
        var currentBlock: [RecognizedLine] = []

        for line in lines {
            if let previousLine = currentBlock.last,
               shouldStartNewBlock(after: previousLine, before: line) {
                groupedLines.append(currentBlock)
                currentBlock = [line]
            } else {
                currentBlock.append(line)
            }
        }

        if !currentBlock.isEmpty {
            groupedLines.append(currentBlock)
        }

        return groupedLines
            .compactMap(makeBlock(from:))
            .filter { $0.text.count >= 24 || $0.lines.count > 1 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                return lhs.topY > rhs.topY
            }
            .prefix(2)
            .sorted { $0.topY > $1.topY }
            .map { $0 }
    }

    private static func shouldStartNewBlock(after upperLine: RecognizedLine, before lowerLine: RecognizedLine) -> Bool {
        let verticalGap = upperLine.bounds.minY - lowerLine.bounds.maxY
        let indentDelta = abs(upperLine.bounds.minX - lowerLine.bounds.minX)
        let widthDelta = abs(upperLine.bounds.width - lowerLine.bounds.width)

        return verticalGap > 0.035 || indentDelta > 0.08 || widthDelta > 0.22
    }

    private static func makeBlock(from lines: [RecognizedLine]) -> RecognizedTextBlock? {
        let text = normalize(lines.map(\.text).joined(separator: " "))
        guard !text.isEmpty else { return nil }

        let averageConfidence = lines.map(\.confidence).reduce(0, +) / Float(lines.count)
        let topY = lines.map { $0.bounds.maxY }.max() ?? 0
        let bottomY = lines.map { $0.bounds.minY }.min() ?? 0
        let centerY = (topY + bottomY) / 2
        let averageWidth = lines.map(\.bounds.width).reduce(0, +) / CGFloat(lines.count)

        let lengthScore = min(Double(text.count) / 120, 1.6)
        let confidenceScore = Double(averageConfidence)
        let positionScore = max(0, 1 - abs(Double(centerY) - 0.5))
        let lineCountScore = min(Double(lines.count) / 3, 1.0)
        let widthScore = min(Double(averageWidth), 0.95)
        let topOrBottomPenalty = centerY > 0.88 || centerY < 0.12 ? 0.45 : 0

        return RecognizedTextBlock(
            lines: lines,
            text: text,
            averageConfidence: averageConfidence,
            score: (lengthScore * 1.5) + confidenceScore + positionScore + lineCountScore + widthScore - topOrBottomPenalty,
            topY: topY
        )
    }

    private static func makeDraftQuotes(from blocks: [RecognizedTextBlock], pageNumber: Int?) -> [DraftQuote] {
        blocks.map { block in
            DraftQuote(
                text: block.text,
                page: pageNumber ?? 1,
                confidence: label(for: block.averageConfidence),
                marginNote: reviewNote(for: block)
            )
        }
    }

    private static func reviewNote(for block: RecognizedTextBlock) -> String? {
        if block.averageConfidence < 0.62 {
            return "Low OCR confidence. Compare this block against the captured page."
        }

        if block.lines.count >= 5 || block.text.count >= 220 {
            return "OCR likely pulled a full paragraph. Trim this to the marked passage."
        }

        return nil
    }

    private static func suggestedSourceNote(detectedLineCount: Int, selectedQuoteCount: Int) -> String {
        switch selectedQuoteCount {
        case 0:
            return "OCR read the page but did not isolate a clear passage. Review manually."
        case 1:
            return "OCR detected \(detectedLineCount) lines and pulled one likely passage. Confirm the marked text."
        default:
            return "OCR detected \(detectedLineCount) lines and pulled \(selectedQuoteCount) passage candidates. Keep only what was actually marked."
        }
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

private struct RecognizedTextBlock {
    var lines: [RecognizedLine]
    var text: String
    var averageConfidence: Float
    var score: Double
    var topY: CGFloat
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
