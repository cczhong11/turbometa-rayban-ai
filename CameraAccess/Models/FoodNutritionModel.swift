/*
 * Food Nutrition Model
 * Food v2 API 数据模型
 */

import Foundation

struct FoodAnalyzeAndSaveResponse: Codable {
    let status: String
    let data: FoodAnalysisResult
}

struct FoodLogsResponse: Codable {
    let status: String
    let data: [FoodLogEntry]
}

struct FoodAnalysisResult: Codable {
    let photoURL: String?
    let timestamp: String
    let mealType: String
    let userNote: String?
    let analysis: FoodAnalysisMetadata
    let savedItems: [FoodLogEntry]

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
        case timestamp
        case mealType = "meal_type"
        case userNote = "user_note"
        case analysis
        case savedItems = "saved_items"
    }
}

struct FoodAnalysisMetadata: Codable {
    let model: String?
    let reasoning: String?
    let items: [FoodAnalysisItem]
}

struct FoodAnalysisItem: Codable, Identifiable, Hashable {
    var id: String {
        "\(name)-\(servingSize ?? 0)-\(calories ?? 0)"
    }

    let name: String
    let calories: Double?
    let protein: Double?
    let fat: Double?
    let carbohydrates: Double?
    let servingSize: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case calories
        case protein
        case fat
        case carbohydrates
        case servingSize = "serving_size"
    }
}

struct FoodLogEntry: Codable, Identifiable, Hashable {
    let id: String
    let date: String?
    let timestamp: String?
    let photoURL: String?
    let foodName: String?
    let cal: Double?
    let protein: Double?
    let fat: Double?
    let carbohydrates: Double?
    let mealType: String?
    let weight: Int?
    let existingFoodID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case timestamp
        case photoURL = "photo_url"
        case foodName = "food_name"
        case cal
        case protein
        case fat
        case carbohydrates
        case mealType = "meal_type"
        case weight
        case existingFoodID = "existing_food_id"
    }
}

extension FoodAnalysisResult {
    var totalCalories: Int {
        Int(savedItems.reduce(0) { $0 + ($1.cal ?? 0) }.rounded())
    }

    var totalProtein: Double {
        savedItems.reduce(0) { $0 + ($1.protein ?? 0) }
    }

    var totalFat: Double {
        savedItems.reduce(0) { $0 + ($1.fat ?? 0) }
    }

    var totalCarbohydrates: Double {
        savedItems.reduce(0) { $0 + ($1.carbohydrates ?? 0) }
    }

    var displayMealType: String {
        FoodMealType(rawValue: mealType)?.displayName ?? mealType
    }

    var timestampDate: Date? {
        timestamp.iso8601Date
    }
}

extension FoodLogEntry {
    var displayName: String {
        foodName ?? "未命名食物"
    }

    var displayMealType: String {
        FoodMealType(rawValue: mealType ?? "")?.displayName ?? (mealType ?? "未分类")
    }

    var displayCalories: String {
        "\(Int((cal ?? 0).rounded())) 千卡"
    }

    var displayWeight: String? {
        guard let weight else { return nil }
        return "\(weight) g"
    }

    var timestampDate: Date? {
        timestamp?.iso8601Date
    }
}

enum FoodMealType: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        case .snack: return "加餐"
        }
    }
}

extension String {
    var iso8601Date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: self) {
            return date
        }

        return Self.localTimestampFormatter.date(from: self)
    }

    private static let localTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
