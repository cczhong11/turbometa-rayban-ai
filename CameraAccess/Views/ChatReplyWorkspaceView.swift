import SwiftUI
import UIKit

struct ChatReplyWorkspaceView: View {
    @StateObject private var store = ChatReplyStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPerson: PersonProfile?
    @State private var showNewPersonSheet = false
    @State private var showPeopleManager = false
    @State private var selectedImage: UIImage?
    @State private var showMediaPicker = false
    @State private var isProcessing = false
    @State private var ocrText = ""
    @State private var conversationSummary = ""
    @State private var vibe = ""
    @State private var suggestions: [String] = []
    @State private var styleVariants: [String] = []
    @State private var errorMessage: String?
    @State private var didSave = false

    private let ocrService = OCRService()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    personSection
                    historySection
                    imageSection
                    actionSection
                    resultSection
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.secondaryBackground.ignoresSafeArea())
            .navigationTitle("聊天回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("管理") {
                        showPeopleManager = true
                    }
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerView(mode: .image) { url, _ in
                    selectedImage = UIImage(contentsOfFile: url.path)
                    didSave = false
                }
            }
            .sheet(isPresented: $showNewPersonSheet) {
                NewPersonSheet { name, notes in
                    selectedPerson = store.createPerson(name: name, notes: notes)
                }
            }
            .sheet(isPresented: $showPeopleManager) {
                PeopleManagerView(selectedPerson: $selectedPerson)
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        errorMessage = nil
                    }
                }
            )) {
                Button("好的") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if selectedPerson == nil {
                    selectedPerson = store.people.first
                }
            }
        }
    }

    private var personSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("聊天对象")
                .font(AppTypography.headline)

            HStack(spacing: AppSpacing.sm) {
                Menu {
                    ForEach(store.people) { person in
                        Button(person.name) {
                            selectedPerson = person
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPerson?.name ?? "选择女生")
                                .foregroundColor(selectedPerson == nil ? AppColors.textSecondary : AppColors.textPrimary)
                            if let selectedPerson, !selectedPerson.notes.isEmpty {
                                Text(selectedPerson.notes)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.md)
                }

                Button {
                    showNewPersonSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(Color(hex: "6A4C93"))
                        .cornerRadius(AppCornerRadius.md)
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if let selectedPerson {
            let history = store.records(for: selectedPerson.id)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("这个女生的最近记录")
                    .font(AppTypography.headline)

                if history.isEmpty {
                    Text("还没有保存过聊天建议。")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(AppCornerRadius.md)
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(history.prefix(5)) { record in
                            ChatHistoryCard(record: record)
                        }
                    }
                }
            }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("聊天截图")
                .font(AppTypography.headline)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 320)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.lg)
            }

            Button {
                showMediaPicker = true
            } label: {
                Text(selectedImage == nil ? "从相册选择截图" : "重新选择截图")
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color(hex: "426B69"))
                    .cornerRadius(AppCornerRadius.lg)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task {
                    await analyzeSelectedImage()
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(isProcessing ? "分析中..." : "OCR 并生成回复建议")
                        .font(AppTypography.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(canAnalyze ? Color(hex: "6A4C93") : Color.gray)
                .cornerRadius(AppCornerRadius.lg)
            }
            .disabled(!canAnalyze || isProcessing)

            Button {
                saveCurrentRecord()
            } label: {
                Text(didSave ? "已保存到她的记录" : "保存这次建议")
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
        if !conversationSummary.isEmpty || !ocrText.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if !conversationSummary.isEmpty {
                    ResultCard(title: "对话理解", bodyText: conversationSummary)
                }

                if !vibe.isEmpty {
                    ResultCard(title: "氛围判断", bodyText: vibe)
                }

                if !suggestions.isEmpty {
                    SuggestionListCard(title: "建议回复", items: suggestions, tint: Color(hex: "6A4C93"))
                }

                if !styleVariants.isEmpty {
                    SuggestionListCard(title: "不同风格", items: styleVariants, tint: Color(hex: "426B69"))
                }

                ResultCard(title: "OCR 原文", bodyText: ocrText)
            }
        }
    }

    private var canAnalyze: Bool {
        selectedPerson != nil && selectedImage != nil
    }

    private var canSave: Bool {
        selectedPerson != nil && !conversationSummary.isEmpty && !didSave
    }

    private func analyzeSelectedImage() async {
        guard let selectedImage else {
            errorMessage = "先选一张聊天截图。"
            return
        }
        guard let selectedPerson else {
            errorMessage = "先选一个聊天对象。"
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

            let context = store.contextPayload(for: selectedPerson.id)
            let output = try await GeminiChatReplyService(apiKey: apiKey).suggestReplies(
                ocrText: ocrResult.fullText,
                person: selectedPerson,
                context: context
            )
            conversationSummary = output.conversationSummary
            vibe = output.vibe
            suggestions = output.suggestions
            styleVariants = output.styleVariants
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func saveCurrentRecord() {
        guard let selectedPerson, let selectedImage else { return }
        let record = ReplySuggestionRecord(
            personId: selectedPerson.id,
            thumbnailJPEGData: selectedImage.jpegData(compressionQuality: 0.5),
            ocrText: ocrText,
            conversationSummary: conversationSummary,
            vibe: vibe,
            suggestions: suggestions,
            styleVariants: styleVariants
        )
        store.save(record)
        didSave = true
    }
}

struct PeopleManagerView: View {
    @StateObject private var store = ChatReplyStore.shared
    @Binding var selectedPerson: PersonProfile?
    @Environment(\.dismiss) private var dismiss
    @State private var showNewPersonSheet = false
    @State private var detailPerson: PersonProfile?

    var body: some View {
        NavigationView {
            Group {
                if store.people.isEmpty {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 54))
                            .foregroundColor(Color(hex: "6A4C93"))
                        Text("还没有聊天对象")
                            .font(AppTypography.title2)
                        Text("先建一个女生档案，后面每次截图建议都会记在她下面。")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                        Button("新建聊天对象") {
                            showNewPersonSheet = true
                        }
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color(hex: "6A4C93"))
                        .cornerRadius(AppCornerRadius.lg)
                        .padding(.horizontal, AppSpacing.xl)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(store.people) { person in
                            Button {
                                selectedPerson = person
                                detailPerson = person
                            } label: {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    HStack {
                                        Text(person.name)
                                            .font(AppTypography.headline)
                                            .foregroundColor(AppColors.textPrimary)
                                        if selectedPerson?.id == person.id {
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(hex: "6A4C93"))
                                        }
                                    }
                                    if !person.notes.isEmpty {
                                        Text(person.notes)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(2)
                                    }
                                    Text("\(store.records(for: person.id).count) 条聊天记录")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                        }
                        .onDelete(perform: deletePeople)
                    }
                }
            }
            .navigationTitle("人物管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewPersonSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewPersonSheet) {
                NewPersonSheet { name, notes in
                    selectedPerson = store.createPerson(name: name, notes: notes)
                }
            }
            .sheet(item: $detailPerson) { person in
                PersonDetailView(person: person)
            }
        }
    }

    private func deletePeople(at offsets: IndexSet) {
        let people = offsets.map { store.people[$0] }
        for person in people {
            if selectedPerson?.id == person.id {
                selectedPerson = nil
            }
            store.deletePerson(person.id)
        }
        if selectedPerson == nil {
            selectedPerson = store.people.first
        }
    }
}

struct PersonDetailView: View {
    let person: PersonProfile

    @StateObject private var store = ChatReplyStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecord: ReplySuggestionRecord?

    var body: some View {
        NavigationView {
            List {
                Section {
                    if !person.notes.isEmpty {
                        Text(person.notes)
                            .font(AppTypography.body)
                    } else {
                        Text("暂无备注")
                            .foregroundColor(AppColors.textSecondary)
                    }
                } header: {
                    Text("人物备注")
                }

                Section {
                    ForEach(store.records(for: person.id)) { record in
                        Button {
                            selectedRecord = record
                        } label: {
                            ChatHistoryCard(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("聊天历史")
                }
            }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                ReplySuggestionDetailView(record: record)
            }
        }
    }
}

struct ReplySuggestionDetailView: View {
    let record: ReplySuggestionRecord

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

                    ResultCard(title: "对话理解", bodyText: record.conversationSummary)

                    if !record.vibe.isEmpty {
                        ResultCard(title: "氛围判断", bodyText: record.vibe)
                    }

                    if !record.suggestions.isEmpty {
                        SuggestionListCard(title: "建议回复", items: record.suggestions, tint: Color(hex: "6A4C93"))
                    }

                    if !record.styleVariants.isEmpty {
                        SuggestionListCard(title: "不同风格", items: record.styleVariants, tint: Color(hex: "426B69"))
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

struct NewPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var notes = ""

    let onSave: (String, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("人物信息") {
                    TextField("名字或代号", text: $name)
                    TextField("备注，比如聊天风格、关系阶段", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("新建聊天对象")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct SuggestionListCard: View {
    let title: String
    let items: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Text("\(index + 1).")
                            .foregroundColor(tint)
                        Text(item)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .font(AppTypography.body)
                }
            }
            .padding(AppSpacing.md)
            .background(Color.white)
            .cornerRadius(AppCornerRadius.lg)
        }
    }
}

struct ChatHistoryCard: View {
    let record: ReplySuggestionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(record.formattedDate)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)

            Text(record.conversationSummary)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(3)

            if let first = record.suggestions.first {
                Text("建议：\(first)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.md)
    }
}

struct PersonProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let notes: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, notes: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
    }
}

struct ReplySuggestionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let personId: UUID
    let timestamp: Date
    let thumbnailJPEGData: Data?
    let ocrText: String
    let conversationSummary: String
    let vibe: String
    let suggestions: [String]
    let styleVariants: [String]

    init(
        id: UUID = UUID(),
        personId: UUID,
        timestamp: Date = Date(),
        thumbnailJPEGData: Data?,
        ocrText: String,
        conversationSummary: String,
        vibe: String,
        suggestions: [String],
        styleVariants: [String]
    ) {
        self.id = id
        self.personId = personId
        self.timestamp = timestamp
        self.thumbnailJPEGData = thumbnailJPEGData
        self.ocrText = ocrText
        self.conversationSummary = conversationSummary
        self.vibe = vibe
        self.suggestions = suggestions
        self.styleVariants = styleVariants
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }

    var thumbnailImage: UIImage? {
        guard let thumbnailJPEGData else { return nil }
        return UIImage(data: thumbnailJPEGData)
    }
}

@MainActor
final class ChatReplyStore: ObservableObject {
    static let shared = ChatReplyStore()

    @Published private(set) var people: [PersonProfile] = []
    @Published private(set) var records: [ReplySuggestionRecord] = []

    private let userDefaults: UserDefaults
    private let peopleKey: String
    private let recordsKey: String

    init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = ""
    ) {
        self.userDefaults = userDefaults
        self.peopleKey = "\(keyPrefix)chat_reply_people"
        self.recordsKey = "\(keyPrefix)chat_reply_records"
        load()
    }

    func createPerson(name: String, notes: String) -> PersonProfile {
        let person = PersonProfile(name: name, notes: notes)
        people.insert(person, at: 0)
        persistPeople()
        return person
    }

    func save(_ record: ReplySuggestionRecord) {
        records.insert(record, at: 0)
        persistRecords()
    }

    func records(for personId: UUID) -> [ReplySuggestionRecord] {
        records.filter { $0.personId == personId }
    }

    func deletePerson(_ personId: UUID) {
        people.removeAll { $0.id == personId }
        records.removeAll { $0.personId == personId }
        persistPeople()
        persistRecords()
    }

    func resetForTesting() {
        people = []
        records = []
        userDefaults.removeObject(forKey: peopleKey)
        userDefaults.removeObject(forKey: recordsKey)
    }

    func contextPayload(for personId: UUID) -> String {
        let person = people.first(where: { $0.id == personId })
        let recent = records(for: personId).prefix(5)

        var segments: [String] = []
        if let person {
            segments.append("人物备注：\(person.notes.isEmpty ? "无" : person.notes)")
        }
        if recent.isEmpty {
            segments.append("历史记录：无")
        } else {
            let history = recent.map {
                """
                时间：\($0.formattedDate)
                对话摘要：\($0.conversationSummary)
                上次建议：\($0.suggestions.first ?? "无")
                """
            }.joined(separator: "\n\n")
            segments.append("历史记录：\n\(history)")
        }
        return segments.joined(separator: "\n\n")
    }

    private func load() {
        let decoder = JSONDecoder()
        if let peopleData = userDefaults.data(forKey: peopleKey),
           let decodedPeople = try? decoder.decode([PersonProfile].self, from: peopleData) {
            people = decodedPeople
        }

        if let recordData = userDefaults.data(forKey: recordsKey),
           let decodedRecords = try? decoder.decode([ReplySuggestionRecord].self, from: recordData) {
            records = decodedRecords
        }
    }

    private func persistPeople() {
        if let encoded = try? JSONEncoder().encode(people) {
            userDefaults.set(encoded, forKey: peopleKey)
        }
    }

    private func persistRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            userDefaults.set(encoded, forKey: recordsKey)
        }
    }
}

struct GeminiChatReplyOutput {
    let conversationSummary: String
    let vibe: String
    let suggestions: [String]
    let styleVariants: [String]
}

struct GeminiChatReplyService {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-2.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    func suggestReplies(ocrText: String, person: PersonProfile, context: String) async throws -> GeminiChatReplyOutput {
        let prompt = """
        你是一个很会聊天、很懂分寸的中文恋爱聊天助手。

        现在有一张聊天截图，OCR 文本如下。请结合这个女生的历史 context，给出回复建议。

        女生名字或代号：\(person.name)
        该女生 context：
        \(context)

        OCR 文本：
        \(ocrText)

        请严格按以下格式输出：
        对话理解:
        <简要总结现在聊到哪里，50字内>

        氛围判断:
        <一句话判断她现在的状态、语气或情绪>

        建议回复:
        - <可直接发出的回复1>
        - <可直接发出的回复2>
        - <可直接发出的回复3>

        不同风格:
        - 轻松版：<一句>
        - 暧昧版：<一句>
        - 克制版：<一句>

        要求：
        1. 全部用中文
        2. 回复要像真人，不要像客服
        3. 不要输出解释性废话
        4. 尽量考虑这位女生的历史 context
        """

        let request = GeminiGenerateContentRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ],
            generationConfig: .init(temperature: 0.8)
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

        return Self.parseResponseText(textResponse)
    }

    static func parseResponseText(_ text: String) -> GeminiChatReplyOutput {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var section = ""
        var summaryLines: [String] = []
        var vibeLines: [String] = []
        var suggestions: [String] = []
        var variants: [String] = []

        for line in lines {
            if line.hasPrefix("对话理解") {
                section = "summary"
                continue
            }
            if line.hasPrefix("氛围判断") {
                section = "vibe"
                continue
            }
            if line.hasPrefix("建议回复") {
                section = "suggestions"
                continue
            }
            if line.hasPrefix("不同风格") {
                section = "variants"
                continue
            }

            switch section {
            case "summary":
                summaryLines.append(line)
            case "vibe":
                vibeLines.append(line)
            case "suggestions":
                suggestions.append(cleanBullet(line))
            case "variants":
                variants.append(cleanBullet(line))
            default:
                break
            }
        }

        return GeminiChatReplyOutput(
            conversationSummary: summaryLines.joined(separator: "\n"),
            vibe: vibeLines.joined(separator: "\n"),
            suggestions: suggestions.filter { !$0.isEmpty },
            styleVariants: variants.filter { !$0.isEmpty }
        )
    }

    private static func cleanBullet(_ line: String) -> String {
        line
            .replacingOccurrences(of: "- ", with: "")
            .replacingOccurrences(of: "• ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
