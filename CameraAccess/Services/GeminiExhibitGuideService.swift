/*
 * Gemini Exhibit Guide Service
 * 将 OCR 文字和图片一起发送给 Gemini，生成展品讲解
 */

import Foundation
import UIKit

struct GeminiExhibitGuideService {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-2.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    func generateGuide(image: UIImage, ocrText: String, responseLanguage: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiExhibitGuideError.invalidImage
        }

        let prompt = """
        你是一个博物馆展品讲解助手。

        请同时结合用户拍到的图片内容和 OCR 识别出的文字，给出一段适合 TTS 播报的详细讲解。

        输出要求：
        1. 使用\(responseLanguage)回答
        2. 先判断这是什么展品、牌子、作品或展区
        3. 如果 OCR 文字里有标题、年代、作者、材质、地点等信息，优先吸收进解释里
        4. 如果 OCR 可能有误，结合图片上下文做合理纠正，但不要虚构非常具体的细节
        5. 重点讲清楚它为什么重要、看点是什么、背后的历史或文化意义
        6. 口语化，像现场讲解员，适合直接朗读
        7. 不要输出 markdown、标题、分点、括号提示
        8. 控制在 180 字以内

        OCR 文本：
        \(ocrText)
        """

        let request = GeminiExhibitGuideRequest(
            contents: [
                .init(parts: [
                    .text(prompt),
                    .inlineData(mimeType: "image/jpeg", data: imageData.base64EncodedString())
                ])
            ],
            generationConfig: .init(temperature: 0.6)
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiExhibitGuideError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiExhibitGuideError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Gemini 请求失败"
            throw GeminiExhibitGuideError.apiError(message)
        }

        let decoded = try JSONDecoder().decode(GeminiExhibitGuideResponse.self, from: data)
        let textResponse = decoded.candidates?
            .first?
            .content
            .parts
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if textResponse.isEmpty {
            throw GeminiExhibitGuideError.emptyResponse
        }

        return textResponse
    }
}

private struct GeminiExhibitGuideRequest: Codable {
    let contents: [GeminiExhibitGuideContent]
    let generationConfig: GeminiExhibitGuideGenerationConfig?
}

private struct GeminiExhibitGuideContent: Codable {
    let parts: [GeminiExhibitGuidePart]
}

private struct GeminiExhibitGuidePart: Codable {
    let text: String?
    let inlineData: GeminiExhibitGuideInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData
    }

    static func text(_ value: String) -> Self {
        Self(text: value, inlineData: nil)
    }

    static func inlineData(mimeType: String, data: String) -> Self {
        Self(text: nil, inlineData: .init(mimeType: mimeType, data: data))
    }
}

private struct GeminiExhibitGuideInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType
        case data
    }
}

private struct GeminiExhibitGuideGenerationConfig: Codable {
    let temperature: Double
}

private struct GeminiExhibitGuideResponse: Codable {
    let candidates: [GeminiExhibitGuideCandidate]?
}

private struct GeminiExhibitGuideCandidate: Codable {
    let content: GeminiExhibitGuideResponseContent
}

private struct GeminiExhibitGuideResponseContent: Codable {
    let parts: [GeminiExhibitGuideResponsePart]
}

private struct GeminiExhibitGuideResponsePart: Codable {
    let text: String?
}

enum GeminiExhibitGuideError: LocalizedError {
    case invalidImage
    case missingGeminiKey
    case invalidRequest
    case invalidResponse
    case emptyResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "这张图片暂时处理不了，换一张试试。"
        case .missingGeminiKey:
            return "还没有设置 Gemini API Key，请先到设置里填写 Google API Key。"
        case .invalidRequest:
            return "Gemini 请求创建失败。"
        case .invalidResponse:
            return "Gemini 返回了无效响应。"
        case .emptyResponse:
            return "Gemini 没有返回内容。"
        case .apiError(let message):
            return message
        }
    }
}
