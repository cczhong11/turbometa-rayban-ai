/*
 * Image OCR Service
 * 使用 Vision 识别图片中的文字
 */

import UIKit
import Vision

struct ImageOCRResult {
    let fullText: String
}

struct ImageOCRService {
    func recognizeText(from image: UIImage) async throws -> ImageOCRResult {
        guard let cgImage = normalizedCGImage(from: image) else {
            throw ImageOCRServiceError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ImageOCRServiceError.ocrFailed)
                    return
                }

                let orderedText = observations
                    .sorted {
                        let left = $0.boundingBox
                        let right = $1.boundingBox
                        if abs(left.midY - right.midY) > 0.03 {
                            return left.midY > right.midY
                        }
                        return left.minX < right.minX
                    }
                    .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                continuation.resume(returning: ImageOCRResult(fullText: orderedText))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return normalized.cgImage
    }
}

enum ImageOCRServiceError: LocalizedError {
    case invalidImage
    case ocrFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "这张图片暂时处理不了，换一张试试。"
        case .ocrFailed:
            return "OCR 识别失败。"
        }
    }
}
