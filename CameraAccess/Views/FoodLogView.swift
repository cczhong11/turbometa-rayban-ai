import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FoodLogView: View {
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var selectedMealType: FoodMealType = .lunch
    @State private var selectedRange: FoodLogRange = .days30
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        let isUploading = viewModel.isUploading
        let uploadButtonTitle = viewModel.uploadButtonTitle

        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "FFF6ED"),
                        Color(hex: "F7FBF5"),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if viewModel.isLoading && viewModel.logs.isEmpty {
                    ProgressView("加载饮食记录...")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            rangePickerSection
                            summarySection
                            groupedLogsSection
                        }
                        .padding(AppSpacing.md)
                    }
                    .refreshable {
                        await viewModel.loadLogs(for: selectedRange)
                    }
                }
            }
            .navigationTitle("Food Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("餐次", selection: $selectedMealType) {
                            ForEach(FoodMealType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                    } label: {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "photo.stack.fill")
                        }

                        Text(uploadButtonTitle)
                            .font(AppTypography.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color(hex: "D96541"))
                    .cornerRadius(AppCornerRadius.xl)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)
                }
                .disabled(isUploading)
                .background(.clear)
            }
            .task {
                await viewModel.loadLogs(for: selectedRange)
            }
            .onChange(of: selectedRange) { _, newValue in
                Task {
                    await viewModel.loadLogs(for: newValue)
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await viewModel.addFoodLogs(
                        from: newItems,
                        mealType: selectedMealType,
                        refreshRange: selectedRange
                    )
                    selectedPhotoItems = []
                }
            }
            .alert("提示", isPresented: $viewModel.showAlert) {
                Button("好的") {}
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }

    private var rangePickerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("查看最近一段时间")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(FoodLogRange.allCases) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        Text(range.title)
                            .font(AppTypography.headline)
                            .foregroundColor(selectedRange == range ? .white : AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 10)
                            .background(selectedRange == range ? Color(hex: "2D6A4F") : Color.white.opacity(0.75))
                            .cornerRadius(AppCornerRadius.xl)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("最近 \(selectedRange.dayCount) 天")
                .font(AppTypography.title)
                .foregroundColor(AppColors.textPrimary)

            if viewModel.logs.isEmpty {
                Text("这段时间还没有饮食记录。下方按钮支持一次选择多张照片。")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                HStack(spacing: AppSpacing.sm) {
                    summaryPill(title: "记录", value: "\(viewModel.logs.count) 条", color: .orange)
                    summaryPill(title: "热量", value: "\(viewModel.totalCalories) kcal", color: .red)
                    summaryPill(title: "蛋白质", value: String(format: "%.1f g", viewModel.totalProtein), color: .green)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(AppCornerRadius.xl)
    }

    private var groupedLogsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("饮食明细")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            if viewModel.groupedLogs.isEmpty {
                emptyLogsCard
            } else {
                ForEach(viewModel.groupedLogs) { section in
                    foodLogSection(section)
                }
            }
        }
    }

    private var emptyLogsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("还没有记录")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("从相册选一批食物图，food v2 会逐张分析并写入数据库。")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(AppCornerRadius.xl)
    }

    private func foodLogSection(_ section: FoodLogSection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(section.title)
                .font(AppTypography.title2)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.xs)

            VStack(spacing: AppSpacing.sm) {
                ForEach(section.entries) { entry in
                    FoodLogRow(entry: entry)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.delete(entry: entry, range: selectedRange)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func summaryPill(title: String, value: String, color: Color) -> some View {
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
}

private struct FoodLogRow: View {
    let entry: FoodLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            AsyncImage(url: URL(string: entry.photoURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.md)
                            .fill(AppColors.tertiaryBackground)
                        Image(systemName: "photo")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(entry.displayName)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)

                Text("\(entry.displayMealType) · \(entry.displayCalories)")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Text("P \(format(entry.protein))g · F \(format(entry.fat))g · C \(format(entry.carbohydrates))g")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let weight = entry.displayWeight {
                    Text(weight)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            if let date = entry.timestampDate {
                Text(Self.timeFormatter.string(from: date))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(AppCornerRadius.xl)
    }

    private func format(_ value: Double?) -> String {
        String(format: "%.1f", value ?? 0)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct FoodLogSection: Identifiable {
    let title: String
    let entries: [FoodLogEntry]

    var id: String { title }
}

enum FoodLogRange: Int, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30
    case days90 = 90

    var id: Int { rawValue }
    var dayCount: Int { rawValue }

    var title: String {
        switch self {
        case .days7: return "近 7 天"
        case .days30: return "近 30 天"
        case .days90: return "近 90 天"
        }
    }
}

private struct PickedFoodPhoto {
    let imageData: Data
    let timestamp: Date
}

@MainActor
final class FoodLogViewModel: ObservableObject {
    @Published var logs: [FoodLogEntry] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var uploadProgressText = ""

    private let service = LeanEatService()
    private let calendar = Calendar(identifier: .gregorian)

    var totalCalories: Int {
        Int(logs.reduce(0) { $0 + ($1.cal ?? 0) }.rounded())
    }

    var totalProtein: Double {
        logs.reduce(0) { $0 + ($1.protein ?? 0) }
    }

    var uploadButtonTitle: String {
        if isUploading, !uploadProgressText.isEmpty {
            return uploadProgressText
        }
        return "从相册批量添加食物"
    }

    var groupedLogs: [FoodLogSection] {
        let grouped = Dictionary(grouping: logs) { entry in
            entry.date ?? "--"
        }

        return grouped
            .keys
            .sorted(by: >)
            .map { key in
                FoodLogSection(
                    title: Self.displayDateTitle(for: key),
                    entries: grouped[key]?.sorted {
                        ($0.timestampDate ?? .distantPast) > ($1.timestampDate ?? .distantPast)
                    } ?? []
                )
            }
    }

    func loadLogs(for range: FoodLogRange) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (startDate, endDate) = dateRange(for: range)
            logs = try await service.fetchLogs(
                startDate: startDate,
                endDate: endDate,
                limit: 300
            )
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func addFoodLogs(
        from items: [PhotosPickerItem],
        mealType: FoodMealType,
        refreshRange: FoodLogRange
    ) async {
        isUploading = true
        uploadProgressText = ""
        defer {
            isUploading = false
            uploadProgressText = ""
        }

        do {
            let photos = try await loadPickedPhotos(from: items)
            guard !photos.isEmpty else {
                alertMessage = "没有读取到可上传的图片"
                showAlert = true
                return
            }

            var savedCount = 0
            for (index, photo) in photos.enumerated() {
                uploadProgressText = "上传中 \(index + 1)/\(photos.count)"
                let result = try await service.analyzeAndSaveFood(
                    imageData: photo.imageData,
                    timestamp: photo.timestamp,
                    mealType: mealType
                )
                savedCount += result.savedItems.count
            }

            await loadLogs(for: refreshRange)
            alertMessage = "已处理 \(photos.count) 张图片，新增 \(savedCount) 条饮食记录。"
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func delete(entry: FoodLogEntry, range: FoodLogRange) async {
        do {
            try await service.deleteLog(id: entry.id)
            logs.removeAll { $0.id == entry.id }
            if logs.isEmpty {
                await loadLogs(for: range)
            }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func loadPickedPhotos(from items: [PhotosPickerItem]) async throws -> [PickedFoodPhoto] {
        var photos: [PickedFoodPhoto] = []

        for item in items {
            if let data = try await item.loadTransferable(type: Data.self),
               !data.isEmpty {
                photos.append(
                    PickedFoodPhoto(
                        imageData: data,
                        timestamp: creationDate(for: item) ?? Date()
                    )
                )
            }
        }

        return photos
    }

    private func creationDate(for item: PhotosPickerItem) -> Date? {
        guard let identifier = item.itemIdentifier else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return assets.firstObject?.creationDate
    }

    private func dateRange(for range: FoodLogRange) -> (Date, Date) {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: today) ?? today
        return (startDate, today)
    }

    private static func displayDateTitle(for key: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "zh_CN")
        displayFormatter.dateFormat = "M月d日 EEEE"

        guard let date = formatter.date(from: key) else { return key }
        return displayFormatter.string(from: date)
    }
}
