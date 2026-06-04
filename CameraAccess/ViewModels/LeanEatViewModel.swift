/*
 * LeanEat ViewModel
 * 食物营养分析视图模型
 */

import Foundation
import SwiftUI

@MainActor
class LeanEatViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResult: FoodAnalysisResult?
    @Published var errorMessage: String?

    private let service: LeanEatService
    private let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self.service = LeanEatService(apiKey: apiKey)
    }

    func analyzeFood() async {
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil

        do {
            print("🍎 [LeanEat] 调用 food v2 analyze-and-save...")
            let result = try await service.analyzeAndSaveFood(photo)
            analysisResult = result
            print("✅ [LeanEat] 已保存 \(result.savedItems.count) 条 food log")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [LeanEat] 分析失败: \(error)")
        }

        isAnalyzing = false
    }

    func retry() async {
        await analyzeFood()
    }

    func clear() {
        analysisResult = nil
        errorMessage = nil
    }
}
