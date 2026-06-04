/*
 * LeanEat View
 * 调用 food v2 API 分析并写入 food log
 */

import SwiftUI

struct LeanEatView: View {
    @StateObject private var viewModel: LeanEatViewModel
    @Environment(\.dismiss) private var dismiss

    let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self._viewModel = StateObject(wrappedValue: LeanEatViewModel(photo: photo, apiKey: apiKey))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 260)
                            .cornerRadius(AppCornerRadius.lg)
                            .shadow(color: AppShadow.medium(), radius: 8, x: 0, y: 4)

                        if viewModel.isAnalyzing {
                            analyzingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if let result = viewModel.analysisResult {
                            resultView(result)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("营养分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if viewModel.analysisResult == nil && viewModel.errorMessage == nil {
                await viewModel.analyzeFood()
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(AppColors.leanEat)

            Text("正在分析并写入 food log")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("图片会上传到你的后端，由 food v2 API 识别后直接写库。")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.xl)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("分析失败")
                .font(AppTypography.title2)
                .foregroundColor(AppColors.textPrimary)

            Text(error)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.retry()
                }
            } label: {
                Text("重试")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.leanEat)
                    .cornerRadius(AppCornerRadius.lg)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.xl)
    }

    private func resultView(_ result: FoodAnalysisResult) -> some View {
        VStack(spacing: AppSpacing.md) {
            summaryCard(result)

            if let reasoning = result.analysis.reasoning, !reasoning.isEmpty {
                detailCard(title: "分析备注", systemImage: "text.quote") {
                    Text(reasoning)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            detailCard(title: "已保存条目", systemImage: "tray.full.fill") {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(result.savedItems, id: \.id) { item in
                        savedItemRow(item)
                    }
                }
            }
        }
    }

    private func summaryCard(_ result: FoodAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("已写入 food log")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(result.displayMealType) · \(formattedDate(result.timestampDate))")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text("\(result.savedItems.count) 项")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.leanEat)
            }

            HStack(spacing: AppSpacing.sm) {
                macroPill(title: "热量", value: "\(result.totalCalories) 千卡", color: .orange)
                macroPill(title: "蛋白质", value: String(format: "%.1f g", result.totalProtein), color: .green)
            }

            HStack(spacing: AppSpacing.sm) {
                macroPill(title: "脂肪", value: String(format: "%.1f g", result.totalFat), color: .yellow)
                macroPill(title: "碳水", value: String(format: "%.1f g", result.totalCarbohydrates), color: .blue)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "FFF2E8"), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppCornerRadius.xl)
    }

    private func detailCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(title, systemImage: systemImage)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.xl)
    }

    private func savedItemRow(_ item: FoodLogEntry) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            AsyncImage(url: URL(string: item.photoURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.md)
                            .fill(AppColors.tertiaryBackground)
                        Image(systemName: "fork.knife")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.displayName)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)

                Text("\(item.displayMealType) · \(item.displayCalories)")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Text(macroLine(for: item))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
    }

    private func macroPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(AppCornerRadius.lg)
    }

    private func macroLine(for item: FoodLogEntry) -> String {
        let protein = String(format: "%.1f", item.protein ?? 0)
        let fat = String(format: "%.1f", item.fat ?? 0)
        let carbs = String(format: "%.1f", item.carbohydrates ?? 0)
        let weight = item.displayWeight.map { " · \($0)" } ?? ""
        return "P \(protein)g · F \(fat)g · C \(carbs)g\(weight)"
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "刚刚" }
        return Self.displayFormatter.string(from: date)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}
