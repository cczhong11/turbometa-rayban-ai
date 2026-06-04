/*
 * LeanEat Service
 * Food v2 API 服务
 */

import Foundation
import UIKit

final class LeanEatService {
    private let baseURL = "https://api.tczhong.com/v2/food"
    private let session: URLSession

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.session = session
    }

    func analyzeAndSaveFood(
        _ image: UIImage,
        timestamp: Date = Date(),
        mealType: FoodMealType = .lunch,
        userNote: String? = nil
    ) async throws -> FoodAnalysisResult {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw LeanEatError.invalidImage
        }

        return try await analyzeAndSaveFood(
            imageData: imageData,
            timestamp: timestamp,
            mealType: mealType,
            userNote: userNote
        )
    }

    func analyzeAndSaveFood(
        imageData: Data,
        timestamp: Date = Date(),
        mealType: FoodMealType = .lunch,
        userNote: String? = nil
    ) async throws -> FoodAnalysisResult {
        guard !imageData.isEmpty else {
            throw LeanEatError.invalidImage
        }

        let requestBody = AnalyzeAndSaveRequest(
            photoBase64: "data:image/jpeg;base64,\(imageData.base64EncodedString())",
            imageURL: nil,
            timestamp: Self.iso8601Formatter.string(from: timestamp),
            mealType: mealType.rawValue,
            userNote: userNote
        )

        var request = URLRequest(url: try endpoint("/analyze-and-save"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let response: FoodAnalyzeAndSaveResponse = try await send(request)
        return response.data
    }

    func fetchLogs(
        date: Date? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100
    ) async throws -> [FoodLogEntry] {
        guard var components = URLComponents(url: try endpoint("/logs"), resolvingAgainstBaseURL: false) else {
            throw LeanEatError.invalidResponse
        }

        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let date {
            queryItems.append(URLQueryItem(name: "date", value: Self.dateFormatter.string(from: date)))
        } else {
            if let startDate {
                queryItems.append(URLQueryItem(name: "start_date", value: Self.dateFormatter.string(from: startDate)))
            }
            if let endDate {
                queryItems.append(URLQueryItem(name: "end_date", value: Self.dateFormatter.string(from: endDate)))
            }
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw LeanEatError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let response: FoodLogsResponse = try await send(request)
        return response.data
    }

    func deleteLog(id: String) async throws {
        var request = URLRequest(url: try endpoint("/logs/\(id)"))
        request.httpMethod = "DELETE"
        _ = try await send(request) as EmptyAPIResponse
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw LeanEatError.invalidResponse
        }
        return url
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeanEatError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw LeanEatError.apiError(
                statusCode: httpResponse.statusCode,
                message: apiError?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LeanEatError.decodingFailed(error)
        }
    }

    private struct AnalyzeAndSaveRequest: Codable {
        let photoBase64: String?
        let imageURL: String?
        let timestamp: String?
        let mealType: String
        let userNote: String?

        enum CodingKeys: String, CodingKey {
            case photoBase64 = "photo_base64"
            case imageURL = "image_url"
            case timestamp
            case mealType = "meal_type"
            case userNote = "user_note"
        }
    }

    private struct APIErrorResponse: Decodable {
        let status: String?
        let message: String
    }

    private struct EmptyAPIResponse: Decodable {
        let status: String?
        let message: String?
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum LeanEatError: LocalizedError {
    case invalidImage
    case invalidResponse
    case decodingFailed(Error)
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片"
        case .invalidResponse:
            return "服务响应无效"
        case .decodingFailed:
            return "无法解析服务返回的数据"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        }
    }
}
