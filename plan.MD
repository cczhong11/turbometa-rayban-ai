# App 改造计划

## 目标

在当前 app 基础上保留现有 `Live AI` 功能，同时新增两个基于本地图片输入的 iOS 功能：

1. 书页照片提取文字并总结
2. 聊天截图提供回复建议，并按不同女生维护上下文记忆

新加的两个功能不依赖 Ray-Ban，不依赖 DAT 相机流，图片来源改为 iPhone 本地拍照或相册选择。
现有其他功能先以隐藏入口为主，不急着删除代码。

## 核心方案

### 1. OCR 方案

文字提取统一使用 iOS 原生 OCR：

- `Vision.framework`
- `VNRecognizeTextRequest`

职责分层：

- iOS OCR 负责从图片中提取文字
- Gemini text-to-text 模型负责理解文本、总结内容、生成回复建议

这样比直接让多模态模型“看图并猜文字”更稳定，也能降低成本。

### 2. 功能一：书页照片 -> OCR -> 总结 -> 按书保存

处理流程：

1. 用户先选择一本书，或者新建一本书
2. 用户选择或拍摄书页照片
3. 本地 OCR 提取正文
4. 对 OCR 文本做基础清洗
5. 将清洗后的文本发送给 LLM
6. 返回结果包含：
   - 提取原文
   - 简短总结
   - 关键要点
   - 可选的章节感知或阅读笔记
7. 用户可将本次结果保存到对应书籍下

保存内容包含：

- 书籍
- 原图或缩略图
- OCR 原文
- 清洗后的文本
- 摘要
- 要点
- 时间

第一版建议输出：

- `OCR 原文`
- `100-200 字总结`
- `3-5 条要点`

第一版建议交互：

- 进入书页总结页后先选择书籍
- 没有书籍时先新建一本书
- 总结完成后默认提供“保存到当前书籍”

### 3. 功能二：聊天截图 -> OCR -> 回复建议

处理流程：

1. 用户选择聊天截图
2. 本地 OCR 提取聊天内容
3. 对聊天文本按阅读顺序整理
4. 用户选择“这是哪位女生”
5. 将 OCR 文本 + 该对象的历史 context 一起发送给 LLM
6. 返回结果包含：
   - 当前对话理解
   - 对方可能的情绪/意图
   - 3 条可直接发送的回复建议
   - 不同风格版本，例如轻松、暧昧、克制

第一版不要自动识别人名或联系人，先采用手动绑定对象，保证稳定性。

## 产品结构调整

### 1. 保留 Live AI，精简首页

当前项目已经有可工作的 `Live AI` 能力，这部分保留。
新版本不建议新开 app，也不建议第一阶段大删旧代码，而是直接在现有项目上做入口精简。

建议首页入口调整为：

- `Live AI`
- `读书助手`
- `聊天回复`
- `历史记录`
- `人物管理`
- `设置`

第一阶段先隐藏这些暂时不用的功能入口：

- `Quick Vision`
- `Live Translate`
- `RTMP Streaming`
- `OpenClaw`
- `LeanEat`
- 其他强依赖眼镜拍照或视频流的入口

### 2. 图片输入方式

统一支持：

- 相册选择
- 系统相机拍照

这两个新功能不依赖 DAT SDK 取图。

## 数据模型设计

建议新增以下模型：

### 1. OCR 结果

`OCRResult`

- `fullText`
- `blocks`
- `confidence`
- `recognizedAt`

### 2. 书籍

`Book`

- `id`
- `title`
- `author`
- `coverImage`
- `createdAt`
- `updatedAt`

### 3. 书页总结记录

`BookSummaryRecord`

- `id`
- `bookId`
- `timestamp`
- `sourceImage`
- `ocrText`
- `cleanedText`
- `summary`
- `keyPoints`
- `model`

### 4. 人物资料

`PersonProfile`

- `id`
- `name`
- `notes`
- `tonePreference`
- `relationshipStage`
- `createdAt`
- `updatedAt`

### 5. 人物上下文记忆

`ChatContextMemory`

- `personId`
- `summaryMemory`
- `recentTopics`
- `preferences`
- `taboos`
- `lastUpdatedAt`

### 6. 聊天回复建议记录

`ReplySuggestionRecord`

- `id`
- `timestamp`
- `personId`
- `sourceImage`
- `ocrText`
- `conversationSummary`
- `suggestions`
- `styleVariants`
- `model`

## 服务层设计

### 1. OCRService

新增 `OCRService.swift`，封装：

- `VNRecognizeTextRequest`
- 图片预处理
- 文本按阅读顺序合并
- OCR 错误处理

建议接口：

- `recognizeText(from image: UIImage) async throws -> OCRResult`

### 2. TextLLMService

OCR 完成后，模型层只处理文本，不再直接处理图片。
因此这里建议使用纯 `text-to-text` 的服务层，而不是图像任务服务。
这里直接使用 Gemini，避免第一版把 provider 抽象做得过重。

建议新增一个命名准确的 Gemini 文本服务，例如：

- `GeminiTextService`

建议拆成更清晰的接口：

- `summarizeBookText(_ text: String) async throws -> BookSummaryOutput`
- `suggestReply(ocrText: String, personContext: PersonContextPayload) async throws -> ReplySuggestionOutput`

第一版建议固定一个 Gemini 文本模型，先把功能跑通。
后续如果确实有切换模型需求，再抽象 provider。

如果保留 `VisionAPIService`，建议不要继续复用它的命名，而是新增或重命名为更准确的 Gemini 文本服务。

### 3. PersonMemoryService

新增人物记忆管理服务，负责：

- 创建/编辑人物
- 读取指定人物 context
- 保存新的聊天摘要
- 维护历史建议记录

第一版存储可以直接使用：

- `UserDefaults`
- 或本地 JSON 编码持久化

后续如果记录越来越多，再迁移到 `SwiftData` 或 `Core Data`。

### 4. BookLibraryService

新增书籍与书页记录管理服务，负责：

- 创建/编辑书籍
- 获取书籍列表
- 保存某本书下的总结记录
- 查看某本书的历史原文和摘要

建议接口：

- `createBook(title:author:)`
- `loadBooks()`
- `saveBookSummaryRecord(_ record: BookSummaryRecord)`
- `loadBookSummaryRecords(bookId: UUID)`

## UI 页面规划

### 1. 首页

首页保留 `Live AI`，并新增两个主功能卡片：

- `Live AI`
- `书页总结`
- `聊天回复建议`

附加入口：

- `历史记录`
- `人物管理`
- `设置`

### 2. 书页总结页

页面内容：

- 选择书籍或新建书籍
- 选择图片
- OCR 中状态
- OCR 原文展示
- 总结结果展示
- 要点列表
- 保存到当前书籍
- 复制按钮
- 重新识别 / 重新总结按钮

### 3. 书籍管理页

页面内容：

- 书籍列表
- 新建书籍
- 编辑书名/作者
- 进入某本书查看记录

书籍详情页内容：

- 该书下的所有总结记录
- 每条记录显示时间、原文片段、摘要
- 支持查看详情
- 支持删除单条记录

### 4. 聊天回复页

页面内容：

- 选择聊天截图
- 选择或创建人物
- OCR 文本预览
- 对话理解结果
- 建议回复列表
- 不同风格版本
- 一键复制

### 5. 人物管理页

页面内容：

- 人物列表
- 新建人物
- 编辑备注
- 设置风格偏好
- 查看该人物历史记录

### 6. 历史记录页

分成两类：

- 按书查看的书页总结历史
- 聊天建议历史

## 与现有代码的关系

当前项目中可复用部分：

- `CameraAccess/Services/VisionAPIService.swift`
  - 可复用网络请求部分，但命名和职责需要调整，因为新功能在 OCR 之后只走 text-to-text
- `CameraAccess/Services/GeminiLiveService.swift`
  - 可参考现有 Gemini 接入方式，复用鉴权、请求结构或配置思路
- `CameraAccess/Services/ConversationStorage.swift`
  - 可参考其本地持久化方式，但现有结构不适合“按人物记忆”
- `CameraAccess/Views/RecordsView.swift`
  - 可改造成新历史页
- `CameraAccess/Views/TurboMetaHomeView.swift`
  - 可直接精简为新首页，而不是重建整个 app
- `CameraAccess/Views/LiveAIView.swift`
  - 作为保留的核心能力继续使用

当前项目中建议第一阶段隐藏或弱化的部分：

- `QuickVision`
- `Live Translate`
- `RTMP Streaming`
- `OpenClaw`
- `LeanEat`
- 其他与你当前目标无关的入口

第一阶段不必彻底删除这些代码，优先级是：

1. 保住 `Live AI`
2. 先隐藏无关入口
3. 在现有工程里加新功能

## 建议实施顺序

### Phase 1: 首页精简与入口调整

1. 保留 `Live AI` 入口
2. 隐藏暂时不用的旧功能入口
3. 首页增加 `书页总结` 和 `聊天回复建议`
4. 接入相册和系统相机选图

### Phase 2: 书页总结功能

1. 新增 `OCRService`
2. 新增书籍模型与书籍管理
3. 完成书页 OCR
4. 完成文本总结
5. 支持将原文 + 摘要保存到指定书籍
6. 增加按书查看的历史记录

### Phase 3: 聊天回复功能

1. 新增人物资料与记忆模型
2. 完成聊天截图 OCR
3. 完成回复建议生成
4. 将建议与人物 context 绑定保存

### Phase 4: 体验补全

1. 支持重新分析
2. 支持复制结果
3. 支持编辑人物备注和偏好
4. 优化历史记录浏览

## 第一版范围控制

为了避免范围失控，第一版建议只做：

- 只做 iOS
- 保留现有 `Live AI`
- 只隐藏不需要的旧功能，不急着删模块
- 只做单张图片输入
- 功能一支持先选书再保存内容
- 只做手动选择人物
- 只做本地记忆存储
- 不做自动识别联系人
- 不重做整个 app
- 不做实时聊天流

## 主要风险与注意点

### 1. OCR 准确率

聊天截图和书页排版差异很大，需要针对以下情况测试：

- 深色模式聊天截图
- 小字体截图
- 长截图
- 倾斜拍摄的书页
- 中文与中英混排

### 2. 聊天顺序恢复

OCR 提取后不一定天然保持消息顺序，聊天场景必须做额外整理，否则回复建议会失真。

### 3. 人物记忆不要无限堆上下文

不能每次把所有历史原文都塞给模型。应维护一份摘要化记忆，只传必要上下文。

### 4. 图片存储策略

如果完整保存原图，体积会增长很快。第一版要明确：

- 是保存原图
- 还是只保存缩略图 + OCR 文本 + 结果

建议第一版优先保存：

- OCR 文本
- 结果文本
- 可选缩略图

### 5. 书页记录的组织方式

如果没有“书籍”这一层，后面记录会很散，不利于回看和继续积累。

所以功能一必须按下面的结构组织：

- 一本书
- 多条书页记录
- 每条记录包含原文和摘要

## 下一步执行建议

如果开始实现，建议先做下面这一组最小闭环：

1. 新首页
2. 保留 `Live AI` 并隐藏其余旧入口
3. 图片选择
4. `OCRService`
5. 书籍选择/新建
6. 书页总结页面
7. 保存原文 + 摘要到书籍

这个闭环完成后，再扩展到聊天截图和人物记忆，会更稳。
