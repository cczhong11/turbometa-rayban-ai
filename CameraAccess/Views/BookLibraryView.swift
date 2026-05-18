import SwiftUI
import UIKit
import Vision
import CoreImage

struct BookLibraryView: View {
    @StateObject private var store = BookLibraryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showNewBookSheet = false
    @State private var selectedBook: Book?

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "F6F1E8"),
                        Color(hex: "E8F0E8"),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if store.books.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(store.books) { book in
                                Button {
                                    selectedBook = book
                                } label: {
                                    BookCard(book: book, recordCount: store.records(for: book.id).count)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .navigationTitle("读书助手")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewBookSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewBookSheet) {
                NewBookSheet { title, author in
                    let book = store.createBook(title: title, author: author)
                    selectedBook = book
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "7D6B5D"))

            VStack(spacing: AppSpacing.sm) {
                Text("先建一本到书架里")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text("之后每次识别书页，都可以把原文和摘要保存到对应书籍。")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Button {
                showNewBookSheet = true
            } label: {
                Text("新建第一本书")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color(hex: "7D6B5D"))
                    .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)

            Spacer()
        }
    }
}

struct BookDetailView: View {
    let book: Book

    @StateObject private var store = BookLibraryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSummaryWorkspace = false
    @State private var selectedRecord: BookSummaryRecord?

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()

                if store.records(for: book.id).isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()

                        Image(systemName: "doc.text.image")
                            .font(.system(size: 52))
                            .foregroundColor(Color(hex: "7D6B5D"))

                        Text("这本书还没有保存内容")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)

                        Text("拍一页书，识别文字后把原文和摘要存进来。")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)

                        Button {
                            showSummaryWorkspace = true
                        } label: {
                            Text("开始识别")
                                .font(AppTypography.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(Color(hex: "7D6B5D"))
                                .cornerRadius(AppCornerRadius.lg)
                        }
                        .padding(.horizontal, AppSpacing.xl)

                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            bookHeader

                            ForEach(store.records(for: book.id)) { record in
                                Button {
                                    selectedRecord = record
                                } label: {
                                    BookSummaryRecordCard(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSummaryWorkspace = true
                    } label: {
                        Image(systemName: "plus.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showSummaryWorkspace) {
                BookSummaryWorkspaceView(preselectedBook: book)
            }
            .sheet(item: $selectedRecord) { record in
                BookSummaryRecordDetailView(record: record)
            }
        }
    }

    private var bookHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(book.title)
                .font(AppTypography.title2)
                .foregroundColor(AppColors.textPrimary)

            if !book.author.isEmpty {
                Text(book.author)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(AppCornerRadius.lg)
    }
}

struct BookSummaryRecordDetailView: View {
    let record: BookSummaryRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let image = record.thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(AppCornerRadius.lg)
                    }

                    ResultCard(title: "摘要", bodyText: record.summary)

                    if !record.keyPoints.isEmpty {
                        SuggestionListCard(title: "要点", items: record.keyPoints, tint: Color(hex: "7D6B5D"))
                    }

                    ResultCard(title: "OCR 原文", bodyText: record.ocrText)
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.secondaryBackground.ignoresSafeArea())
            .navigationTitle(record.formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BookSummaryWorkspaceView: View {
    let preselectedBook: Book?

    @StateObject private var store = BookLibraryStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBook: Book?
    @State private var showBookPicker = false
    @State private var showNewBookSheet = false
    @State private var selectedImage: UIImage?
    @State private var pickerSource: MediaPickerView.Source = .photoLibrary
    @State private var showMediaPicker = false
    @State private var shouldAutoSummarizeAfterPick = false
    @State private var isProcessing = false
    @State private var ocrText = ""
    @State private var summary = ""
    @State private var keyPoints: [String] = []
    @State private var errorMessage: String?
    @State private var didSave = false

    private let ocrService = OCRService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    selectedBookSection
                    imageSection
                    actionSection
                    resultSection
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.secondaryBackground.ignoresSafeArea())
            .navigationTitle("书页总结")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerView(mode: .image, source: pickerSource) { url, _ in
                    selectedImage = UIImage(contentsOfFile: url.path)
                    didSave = false
                    shouldAutoSummarizeAfterPick = pickerSource == .camera
                }
            }
            .sheet(isPresented: $showNewBookSheet) {
                NewBookSheet { title, author in
                    selectedBook = store.createBook(title: title, author: author)
                }
            }
            .onAppear {
                if let preselectedBook {
                    selectedBook = preselectedBook
                } else if selectedBook == nil {
                    selectedBook = store.books.first
                }
            }
            .onChange(of: selectedImage) { _, newImage in
                guard newImage != nil, shouldAutoSummarizeAfterPick else { return }
                shouldAutoSummarizeAfterPick = false
                Task {
                    await summarizeSelectedImage()
                }
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue { errorMessage = nil }
                }
            )) {
                Button("好的") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var selectedBookSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("书籍")
                .font(AppTypography.headline)

            HStack(spacing: AppSpacing.sm) {
                Menu {
                    ForEach(store.books) { book in
                        Button(book.title) {
                            selectedBook = book
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedBook?.title ?? "选择书籍")
                            .foregroundColor(selectedBook == nil ? AppColors.textSecondary : AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.md)
                }

                Button {
                    showNewBookSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(Color(hex: "7D6B5D"))
                        .cornerRadius(AppCornerRadius.md)
                }
            }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("书页图片")
                .font(AppTypography.headline)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.lg)
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    pickerSource = .photoLibrary
                    showMediaPicker = true
                } label: {
                    Text(selectedImage == nil ? "从相册选择" : "相册重选")
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color(hex: "426B69"))
                        .cornerRadius(AppCornerRadius.lg)
                }

                Button {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        errorMessage = "当前设备不支持拍照。"
                        return
                    }
                    pickerSource = .camera
                    showMediaPicker = true
                } label: {
                    Label("拍照选择", systemImage: "camera.fill")
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color(hex: "7D6B5D"))
                        .cornerRadius(AppCornerRadius.lg)
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task {
                    await summarizeSelectedImage()
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(isProcessing ? "处理中..." : "OCR 并总结")
                        .font(AppTypography.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(canSummarize ? Color(hex: "7D6B5D") : Color.gray)
                .cornerRadius(AppCornerRadius.lg)
            }
            .disabled(!canSummarize || isProcessing)

            Button {
                saveCurrentRecord()
            } label: {
                Text(didSave ? "已保存到书籍" : "保存到当前书籍")
                    .font(AppTypography.headline)
                    .foregroundColor(didSave ? Color(hex: "2F6B3D") : AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.lg)
            }
            .disabled(!canSave)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if !ocrText.isEmpty || !summary.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if !summary.isEmpty {
                    ResultCard(title: "摘要", bodyText: summary)
                }

                if !keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("要点")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            ForEach(keyPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    Text("•")
                                    Text(point)
                                }
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(Color.white)
                        .cornerRadius(AppCornerRadius.lg)
                    }
                }

                ResultCard(title: "OCR 原文", bodyText: ocrText)
            }
        }
    }

    private var canSummarize: Bool {
        selectedBook != nil && selectedImage != nil
    }

    private var canSave: Bool {
        selectedBook != nil && !ocrText.isEmpty && !summary.isEmpty && !didSave
    }

    private func summarizeSelectedImage() async {
        guard let selectedImage else {
            errorMessage = "先选一张书页图片。"
            return
        }
        guard selectedBook != nil else {
            errorMessage = "先选一本书。"
            return
        }

        isProcessing = true
        didSave = false
        errorMessage = nil

        do {
            let ocrResult = try await ocrService.recognizeText(from: selectedImage)
            ocrText = ocrResult.fullText

            let apiKey = APIKeyManager.shared.getGoogleAPIKey() ?? ""
            guard !apiKey.isEmpty else {
                throw BookSummaryError.missingGeminiKey
            }

            let output = try await GeminiTextService(apiKey: apiKey).summarizeBookText(ocrResult.fullText)
            summary = output.summary
            keyPoints = output.keyPoints
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func saveCurrentRecord() {
        guard let selectedBook, let selectedImage else { return }
        let record = BookSummaryRecord(
            bookId: selectedBook.id,
            thumbnailJPEGData: selectedImage.jpegData(compressionQuality: 0.5),
            ocrText: ocrText,
            summary: summary,
            keyPoints: keyPoints
        )
        store.save(record)
        didSave = true
    }
}

struct NewBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""

    let onSave: (String, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("书籍信息") {
                    TextField("书名", text: $title)
                    TextField("作者，可留空", text: $author)
                }
            }
            .navigationTitle("新建书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), author.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct BookCard: View {
    let book: Book
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(book.title)
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)

                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textTertiary)
            }

            Text("\(recordCount) 条保存记录")
                .font(AppTypography.footnote)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.lg)
        .shadow(color: AppShadow.small(), radius: 6, x: 0, y: 3)
    }
}

struct BookSummaryRecordCard: View {
    let record: BookSummaryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                if let thumbnail = record.thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 92)
                        .clipped()
                        .cornerRadius(AppCornerRadius.md)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(record.formattedDate)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text(record.summary)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(4)
                }
            }

            if !record.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(record.keyPoints.prefix(3), id: \.self) { point in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("•")
                            Text(point)
                                .lineLimit(2)
                        }
                        .font(AppTypography.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            if !record.ocrText.isEmpty {
                Text(record.ocrText)
                    .font(AppTypography.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(4)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.lg)
    }
}

struct ResultCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text(bodyText)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(Color.white)
                .cornerRadius(AppCornerRadius.lg)
        }
    }
}

struct Book: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, author: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.author = author
        self.createdAt = createdAt
    }
}

struct BookSummaryRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let bookId: UUID
    let timestamp: Date
    let thumbnailJPEGData: Data?
    let ocrText: String
    let summary: String
    let keyPoints: [String]

    init(
        id: UUID = UUID(),
        bookId: UUID,
        timestamp: Date = Date(),
        thumbnailJPEGData: Data?,
        ocrText: String,
        summary: String,
        keyPoints: [String]
    ) {
        self.id = id
        self.bookId = bookId
        self.timestamp = timestamp
        self.thumbnailJPEGData = thumbnailJPEGData
        self.ocrText = ocrText
        self.summary = summary
        self.keyPoints = keyPoints
    }

    var thumbnailImage: UIImage? {
        guard let thumbnailJPEGData else { return nil }
        return UIImage(data: thumbnailJPEGData)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

@MainActor
final class BookLibraryStore: ObservableObject {
    static let shared = BookLibraryStore()

    @Published private(set) var books: [Book] = []
    @Published private(set) var summaryRecords: [BookSummaryRecord] = []

    private let userDefaults: UserDefaults
    private let booksKey: String
    private let recordsKey: String

    init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = ""
    ) {
        self.userDefaults = userDefaults
        self.booksKey = "\(keyPrefix)book_library_items"
        self.recordsKey = "\(keyPrefix)book_library_records"
        load()
    }

    func createBook(title: String, author: String) -> Book {
        let book = Book(title: title, author: author)
        books.insert(book, at: 0)
        persistBooks()
        return book
    }

    func save(_ record: BookSummaryRecord) {
        summaryRecords.insert(record, at: 0)
        persistRecords()
    }

    func records(for bookId: UUID) -> [BookSummaryRecord] {
        summaryRecords.filter { $0.bookId == bookId }
    }

    func delete(_ recordId: UUID) {
        summaryRecords.removeAll { $0.id == recordId }
        persistRecords()
    }

    func resetForTesting() {
        books = []
        summaryRecords = []
        userDefaults.removeObject(forKey: booksKey)
        userDefaults.removeObject(forKey: recordsKey)
    }

    private func load() {
        let decoder = JSONDecoder()
        if let bookData = userDefaults.data(forKey: booksKey),
           let decodedBooks = try? decoder.decode([Book].self, from: bookData) {
            books = decodedBooks
        }

        if let recordData = userDefaults.data(forKey: recordsKey),
           let decodedRecords = try? decoder.decode([BookSummaryRecord].self, from: recordData) {
            summaryRecords = decodedRecords
        }
    }

    private func persistBooks() {
        if let encoded = try? JSONEncoder().encode(books) {
            userDefaults.set(encoded, forKey: booksKey)
        }
    }

    private func persistRecords() {
        if let encoded = try? JSONEncoder().encode(summaryRecords) {
            userDefaults.set(encoded, forKey: recordsKey)
        }
    }
}

struct OCRResult {
    let fullText: String
}

struct OCRService {
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.normalizedCGImage else {
            throw BookSummaryError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: BookSummaryError.ocrFailed)
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

                if orderedText.isEmpty {
                    continuation.resume(throwing: BookSummaryError.emptyOCR)
                } else {
                    continuation.resume(returning: OCRResult(fullText: orderedText))
                }
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
}

struct GeminiBookSummaryOutput {
    let summary: String
    let keyPoints: [String]
}

struct GeminiTextService {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-2.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    func summarizeBookText(_ text: String) async throws -> GeminiBookSummaryOutput {
        let prompt = """
        你是一个读书助手。请基于下面 OCR 提取出来的书页文字，输出简洁摘要。

        输出格式严格如下：
        摘要:
        <100到200字中文摘要>

        要点:
        - <要点1>
        - <要点2>
        - <要点3>

        要求：
        1. 不要解释你自己在做什么
        2. 如果 OCR 有明显错误，按上下文尽量纠正
        3. 摘要只输出中文
        4. 要点控制在 3 到 5 条

        OCR 文本：
        \(text)
        """

        let request = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ],
            generationConfig: .init(temperature: 0.4)
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw BookSummaryError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BookSummaryError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Gemini 请求失败"
            throw BookSummaryError.apiError(message)
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        let textResponse = decoded.candidates?
            .first?
            .content
            .parts
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if textResponse.isEmpty {
            throw BookSummaryError.emptyResponse
        }

        return Self.parseSummary(from: textResponse)
    }

    static func parseSummary(from responseText: String) -> GeminiBookSummaryOutput {
        let lines = responseText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var summaryLines: [String] = []
        var points: [String] = []
        var inPoints = false

        for line in lines {
            if line.hasPrefix("摘要") {
                inPoints = false
                continue
            }
            if line.hasPrefix("要点") {
                inPoints = true
                continue
            }

            if inPoints {
                let cleaned = line
                    .replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "• ", with: "")
                if !cleaned.isEmpty {
                    points.append(cleaned)
                }
            } else {
                summaryLines.append(line)
            }
        }

        return GeminiBookSummaryOutput(
            summary: summaryLines.joined(separator: "\n"),
            keyPoints: points
        )
    }
}

private struct GeminiGenerateContentRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiGenerationConfig: Codable {
    let temperature: Double
}

private struct GeminiGenerateContentResponse: Codable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
}

enum BookSummaryError: LocalizedError {
    case invalidImage
    case ocrFailed
    case emptyOCR
    case missingGeminiKey
    case invalidRequest
    case invalidResponse
    case emptyResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "这张图片暂时处理不了，换一张试试。"
        case .ocrFailed:
            return "OCR 识别失败。"
        case .emptyOCR:
            return "没识别到文字，换一张更清晰的书页试试。"
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

private extension UIImage {
    var normalizedCGImage: CGImage? {
        if let cgImage {
            return cgImage
        }

        guard let ciImage = CIImage(image: self) else {
            return nil
        }

        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
