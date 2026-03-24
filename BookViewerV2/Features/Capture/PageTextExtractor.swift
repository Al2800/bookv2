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

        let markAnalyzer = MarkSignalAnalyzer(cgImage: cgImage)

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
                    bounds: observation.boundingBox,
                    markScore: markAnalyzer?.markScore(for: observation.boundingBox) ?? 0
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
                selectedQuoteCount: quotes.count,
                markSignalsDetected: candidates.contains { $0.markScore > 0.18 }
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

        let blocks = groupedLines
            .compactMap(makeBlock(from:))
            .filter { $0.text.count >= 24 || $0.lines.count > 1 }

        let strongestMark = blocks.map(\.markScore).max() ?? 0
        let prioritizedBlocks = strongestMark > 0.18
            ? blocks.filter { $0.markScore >= strongestMark * 0.55 || $0.markedLineCount > 0 }
            : blocks

        return prioritizedBlocks
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
        let averageMark = lines.map(\.markScore).reduce(0, +) / Double(lines.count)
        let strongestMark = lines.map(\.markScore).max() ?? 0
        let markedLineCount = lines.filter { $0.markScore > 0.18 }.count
        let topY = lines.map { $0.bounds.maxY }.max() ?? 0
        let bottomY = lines.map { $0.bounds.minY }.min() ?? 0
        let centerY = (topY + bottomY) / 2
        let averageWidth = lines.map(\.bounds.width).reduce(0, +) / CGFloat(lines.count)

        let lengthScore = min(Double(text.count) / 120, 1.6)
        let confidenceScore = Double(averageConfidence)
        let positionScore = max(0, 1 - abs(Double(centerY) - 0.5))
        let lineCountScore = min(Double(lines.count) / 3, 1.0)
        let widthScore = min(Double(averageWidth), 0.95)
        let markScore = (averageMark * 2.8) + (strongestMark * 1.7) + (Double(markedLineCount) * 0.35)
        let topOrBottomPenalty = centerY > 0.88 || centerY < 0.12 ? 0.45 : 0

        return RecognizedTextBlock(
            lines: lines,
            text: text,
            averageConfidence: averageConfidence,
            markScore: strongestMark,
            markedLineCount: markedLineCount,
            score: (lengthScore * 1.5) + confidenceScore + positionScore + lineCountScore + widthScore + markScore - topOrBottomPenalty,
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
        if block.markScore > 0.28 {
            return "Visible marking was detected around this passage. Confirm the exact marked lines."
        }

        if block.averageConfidence < 0.62 {
            return "Low OCR confidence. Compare this block against the captured page."
        }

        if block.lines.count >= 5 || block.text.count >= 220 {
            return "OCR likely pulled a full paragraph. Trim this to the marked passage."
        }

        return nil
    }

    private static func suggestedSourceNote(
        detectedLineCount: Int,
        selectedQuoteCount: Int,
        markSignalsDetected: Bool
    ) -> String {
        if markSignalsDetected {
            switch selectedQuoteCount {
            case 0:
                return "OCR saw visible marks on the page but could not isolate a clean passage. Review manually."
            case 1:
                return "OCR used visible marking cues and pulled one likely marked passage from \(detectedLineCount) lines. Confirm the exact text."
            default:
                return "OCR used visible marking cues and pulled \(selectedQuoteCount) likely marked passages from \(detectedLineCount) lines. Keep only the true highlights."
            }
        }

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
    var markScore: Double
}

private struct RecognizedTextBlock {
    var lines: [RecognizedLine]
    var text: String
    var averageConfidence: Float
    var markScore: Double
    var markedLineCount: Int
    var score: Double
    var topY: CGFloat
}

private struct MarkSignalAnalyzer {
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int
    private let pixelData: [UInt8]

    init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixelData = pixelData
    }

    func markScore(for normalizedBounds: CGRect) -> Double {
        let expandedLineRect = normalizedBounds.insetBy(
            dx: -normalizedBounds.width * 0.04,
            dy: -normalizedBounds.height * 0.32
        )
        let underlineRect = CGRect(
            x: normalizedBounds.minX - (normalizedBounds.width * 0.03),
            y: normalizedBounds.minY - (normalizedBounds.height * 0.26),
            width: normalizedBounds.width * 1.06,
            height: normalizedBounds.height * 0.2
        )

        let highlightScore = coloredMarkRatio(in: expandedLineRect)
        let underlineScore = darkMarkRatio(in: underlineRect)

        return max(highlightScore * 3.4, underlineScore * 4.6)
    }

    private func coloredMarkRatio(in normalizedRect: CGRect) -> Double {
        sample(normalizedRect: normalizedRect, step: 2) { pixel in
            pixel.brightness > 0.66 && pixel.saturation > 0.16 && pixel.alpha > 0.2
        }
    }

    private func darkMarkRatio(in normalizedRect: CGRect) -> Double {
        sample(normalizedRect: normalizedRect, step: 1) { pixel in
            pixel.alpha > 0.2 && (pixel.luminance < 0.48 || (pixel.saturation > 0.28 && pixel.brightness < 0.7))
        }
    }

    private func sample(
        normalizedRect: CGRect,
        step: Int,
        matcher: (SampledPixel) -> Bool
    ) -> Double {
        let rect = pixelRect(for: normalizedRect)
        guard rect.width >= 2, rect.height >= 2 else { return 0 }

        let minX = Int(rect.minX)
        let maxX = Int(rect.maxX)
        let minY = Int(rect.minY)
        let maxY = Int(rect.maxY)

        var matchCount = 0
        var sampleCount = 0

        for y in stride(from: minY, to: maxY, by: step) {
            for x in stride(from: minX, to: maxX, by: step) {
                let pixel = pixelAt(x: x, y: y)
                sampleCount += 1
                if matcher(pixel) {
                    matchCount += 1
                }
            }
        }

        guard sampleCount > 0 else { return 0 }
        return Double(matchCount) / Double(sampleCount)
    }

    private func pixelRect(for normalizedRect: CGRect) -> CGRect {
        let clamped = normalizedRect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull else { return .zero }

        let pixelX = Int((clamped.minX * CGFloat(width)).rounded(.down))
        let pixelMaxX = Int((clamped.maxX * CGFloat(width)).rounded(.up))
        let pixelY = Int(((1 - clamped.maxY) * CGFloat(height)).rounded(.down))
        let pixelMaxY = Int(((1 - clamped.minY) * CGFloat(height)).rounded(.up))

        let x = max(0, min(width - 1, pixelX))
        let y = max(0, min(height - 1, pixelY))
        let maxX = max(x + 1, min(width, pixelMaxX))
        let maxY = max(y + 1, min(height, pixelMaxY))

        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    private func pixelAt(x: Int, y: Int) -> SampledPixel {
        let offset = (y * bytesPerRow) + (x * 4)
        let red = Double(pixelData[offset]) / 255
        let green = Double(pixelData[offset + 1]) / 255
        let blue = Double(pixelData[offset + 2]) / 255
        let alpha = Double(pixelData[offset + 3]) / 255

        let brightness = max(red, green, blue)
        let minimum = min(red, green, blue)
        let saturation = brightness == 0 ? 0 : (brightness - minimum) / brightness
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)

        return SampledPixel(
            saturation: saturation,
            brightness: brightness,
            luminance: luminance,
            alpha: alpha
        )
    }
}

private struct SampledPixel {
    var saturation: Double
    var brightness: Double
    var luminance: Double
    var alpha: Double
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
