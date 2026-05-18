import Foundation
import XCTest

@testable import CameraAccess

@MainActor
final class BookLibraryStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: BookLibraryStore!

    override func setUp() {
        super.setUp()
        suiteName = "BookLibraryStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        store = BookLibraryStore(userDefaults: userDefaults, keyPrefix: "test_")
        store.resetForTesting()
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        store = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBookLibraryStorePersistsBooksAndRecords() {
        let book = store.createBook(title: "Deep Work", author: "Cal Newport")
        let record = BookSummaryRecord(
            bookId: book.id,
            thumbnailJPEGData: nil,
            ocrText: "Original OCR",
            summary: "Summary text",
            keyPoints: ["A", "B"]
        )

        store.save(record)

        let reloaded = BookLibraryStore(userDefaults: userDefaults, keyPrefix: "test_")
        XCTAssertEqual(reloaded.books.count, 1)
        XCTAssertEqual(reloaded.books.first?.title, "Deep Work")
        XCTAssertEqual(reloaded.records(for: book.id).count, 1)
        XCTAssertEqual(reloaded.records(for: book.id).first?.summary, "Summary text")
    }

    func testGeminiBookSummaryParserExtractsSummaryAndPoints() {
        let parsed = GeminiTextService.parseSummary(from: """
        摘要:
        这页主要讲了深度工作的价值，以及专注在高价值任务上的重要性。

        要点:
        - 减少分心
        - 长时间专注
        - 高价值产出
        """)

        XCTAssertEqual(parsed.summary, "这页主要讲了深度工作的价值，以及专注在高价值任务上的重要性。")
        XCTAssertEqual(parsed.keyPoints, ["减少分心", "长时间专注", "高价值产出"])
    }
}

@MainActor
final class ChatReplyStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: ChatReplyStore!

    override func setUp() {
        super.setUp()
        suiteName = "ChatReplyStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        store = ChatReplyStore(userDefaults: userDefaults, keyPrefix: "test_")
        store.resetForTesting()
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        store = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testChatReplyStoreBuildsContextPayloadFromRecentHistory() {
        let person = store.createPerson(name: "A", notes: "慢热，别太油")
        store.save(
            ReplySuggestionRecord(
                personId: person.id,
                thumbnailJPEGData: nil,
                ocrText: "hi",
                conversationSummary: "她刚下班，有点累",
                vibe: "偏平淡",
                suggestions: ["你先休息下，晚点我再找你"],
                styleVariants: ["轻松版：辛苦啦"]
            )
        )

        let payload = store.contextPayload(for: person.id)

        XCTAssertTrue(payload.contains("人物备注：慢热，别太油"))
        XCTAssertTrue(payload.contains("对话摘要：她刚下班，有点累"))
        XCTAssertTrue(payload.contains("上次建议：你先休息下，晚点我再找你"))
    }

    func testDeletePersonAlsoDeletesRelatedRecords() {
        let person = store.createPerson(name: "B", notes: "")
        store.save(
            ReplySuggestionRecord(
                personId: person.id,
                thumbnailJPEGData: nil,
                ocrText: "hey",
                conversationSummary: "测试",
                vibe: "正常",
                suggestions: ["ok"],
                styleVariants: []
            )
        )

        store.deletePerson(person.id)

        XCTAssertTrue(store.people.isEmpty)
        XCTAssertTrue(store.records(for: person.id).isEmpty)
    }

    func testGeminiChatReplyParserExtractsSections() {
        let parsed = GeminiChatReplyService.parseResponseText("""
        对话理解:
        她在试探你今晚有没有空。

        氛围判断:
        整体是轻松里带一点期待。

        建议回复:
        - 今晚有空啊，你想怎么安排？
        - 我这边可以，你是不是想约我出去？
        - 有空，你说个时间我配合你。

        不同风格:
        - 轻松版：有空，今晚想带我去哪？
        - 暧昧版：有空啊，是不是想我了才来问？
        - 克制版：今晚可以，你定个时间吧。
        """)

        XCTAssertEqual(parsed.conversationSummary, "她在试探你今晚有没有空。")
        XCTAssertEqual(parsed.vibe, "整体是轻松里带一点期待。")
        XCTAssertEqual(parsed.suggestions.count, 3)
        XCTAssertEqual(parsed.styleVariants.count, 3)
        XCTAssertEqual(parsed.suggestions.first, "今晚有空啊，你想怎么安排？")
    }
}
