# 聊天与模型

## 职责

聊天模块位于 `lib/main.dart`，负责 Runner 的应用入口、聊天界面、本地模型加载、附件输入和消息展示。

## 入口与生命周期

- `main()` 先调用 `NobodyWho.init()`，再启动 `MainApp`。
- `ChatPage` 持有 `ChatMessagesController`、当前模型选择、附件列表、`Chat` 实例和 `ExpenseLedger` Future。
- `_loadChat()` 首次提问时加载模型并创建 `nobodywho.Chat`，后续复用已加载的 `_chat`。
- `_switchModel()` 切换文本/多模态模型时清空 `_chat`，下一次发送消息重新加载模型；切到文本模型时清空附件。

## 模型资源

`ModelChoice` 定义当前 Runner 的两个模型：

- `text`：`assets/model.gguf`。
- `multimodal`：`assets/multimodal/gemma-4-E2B-it-Q4_K_M.gguf`，并设置 `assets/multimodal/mmproj-BF16.gguf` 作为 projection model。

加载前会通过 `_copyAssetToDocuments()` 把资源复制到应用 documents 目录。Android 使用 `MethodChannel('nobodywho_android_runner/assets')` 执行原生复制；非 Android 使用 `rootBundle.load`。

## 消息与附件

- `buildPromptParts()` 把输入文本转成 `TextPart`，把图片转成 `ImagePart`，把音频转成 `AudioPart`。
- `_pickAttachment()` 使用 `file_picker` 选择图片或音频文件。
- `_send()` 在无附件时调用 `chat.ask()`，有附件时调用 `chat.askWithPrompt()`。
- 文本模型不支持附件；如果存在附件且当前模型不支持，会提示用户切换到多模态模型。

## 思考过程

`splitThinkBlocksForDisplay()` 把文本模型的 `<think>...</think>` 和多模态模型的 `<|channel>...<channel|>` 内容拆到 `thinking`，正文放到 `answer`。`buildThinkingFooter()` 在 AI 消息底部展示可折叠的思考过程，流式输出时默认展开，结束后折叠。

## 与记账模块的关系

`_loadChat()` 创建 `nobodywho.Chat` 时注入 `createRecordTransactionTool(_loadLedger())`。系统提示要求模型在用户明确要求记账时调用 `record_transaction`，并提取收支字段。

## 测试覆盖

`test/widget_test.dart` 覆盖：

- `<think>` 拆分与流式半截标签处理。
- 文本、图片、音频 Prompt Part 构建。
- `ChatPage` 在模型加载前的基础 UI。
