import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter/services.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;
import 'package:nobodywho_android_runner/accounting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _assetChannel = MethodChannel('nobodywho_android_runner/assets');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await nobodywho.NobodyWho.init();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const ChatPage(),
    );
  }
}

class ThinkParts {
  const ThinkParts({required this.answer, required this.thinking});

  final String answer;
  final String thinking;
}

ThinkParts splitThinkBlocksForDisplay(String text) {
  const openTag = '<think>';
  const closeTag = '</think>';
  final lower = text.toLowerCase();
  final answer = StringBuffer();
  final thinking = StringBuffer();
  var hidden = false;
  var index = 0;

  while (index < text.length) {
    if (!hidden && lower.startsWith(openTag, index)) {
      hidden = true;
      index += openTag.length;
      continue;
    }
    if (hidden && lower.startsWith(closeTag, index)) {
      hidden = false;
      index += closeTag.length;
      continue;
    }
    if (!hidden && _isPartialTagAtEnd(lower, index, openTag)) break;
    if (hidden && _isPartialTagAtEnd(lower, index, closeTag)) break;
    if (hidden) {
      thinking.write(text[index]);
    } else {
      answer.write(text[index]);
    }
    index++;
  }

  return ThinkParts(
    answer: answer.toString().replaceFirst(RegExp(r'^\s+'), ''),
    thinking: thinking.toString().trim(),
  );
}

bool _isPartialTagAtEnd(String lower, int index, String tag) {
  final remaining = lower.length - index;
  if (remaining >= tag.length) return false;
  return tag.startsWith(lower.substring(index));
}

enum AttachmentKind { image, audio }

enum ModelChoice { text, multimodal }

extension ModelChoiceInfo on ModelChoice {
  String get label => switch (this) {
    ModelChoice.text => '文本模型',
    ModelChoice.multimodal => '多模态模型',
  };

  String get modelAssetPath => switch (this) {
    ModelChoice.text => 'assets/model.gguf',
    ModelChoice.multimodal => 'assets/multimodal/gemma-4-E2B-it-Q4_K_M.gguf',
  };

  String? get projectionAssetPath => switch (this) {
    ModelChoice.text => null,
    ModelChoice.multimodal => 'assets/multimodal/mmproj-BF16.gguf',
  };

  bool get supportsAttachments => this == ModelChoice.multimodal;
}

class PickedAttachment {
  const PickedAttachment({
    required this.path,
    required this.name,
    required this.kind,
  });

  final String path;
  final String name;
  final AttachmentKind kind;
}

List<nobodywho.PromptPart> buildPromptParts(
  String text,
  List<PickedAttachment> attachments,
) {
  final trimmed = text.trim();
  return [
    if (trimmed.isNotEmpty) nobodywho.TextPart(trimmed),
    for (final attachment in attachments)
      switch (attachment.kind) {
        AttachmentKind.image => nobodywho.ImagePart(attachment.path),
        AttachmentKind.audio => nobodywho.AudioPart(attachment.path),
      },
  ];
}

String buildUserMessageText(String text, List<PickedAttachment> attachments) {
  final trimmed = text.trim();
  final names = attachments.map((a) => a.name).join('\n');
  if (trimmed.isEmpty) return names;
  if (names.isEmpty) return trimmed;
  return '$trimmed\n$names';
}

Widget? buildThinkingFooter(
  BuildContext context,
  ChatMessage message,
  bool isUser,
) {
  final thinking = (message.customProperties?['thinking'] as String? ?? '')
      .trim();
  if (isUser || thinking.isEmpty) return null;

  return ThinkingFooter(
    thinking: thinking,
    isStreaming: message.customProperties?['isStreaming'] == true,
    collapsedLabel: '思考过程',
    streamingLabel: '思考中',
  );
}

class ThinkingFooter extends StatefulWidget {
  const ThinkingFooter({
    super.key,
    required this.thinking,
    required this.isStreaming,
    required this.collapsedLabel,
    required this.streamingLabel,
  });

  final String thinking;
  final bool isStreaming;
  final String collapsedLabel;
  final String streamingLabel;

  @override
  State<ThinkingFooter> createState() => _ThinkingFooterState();
}

class _ThinkingFooterState extends State<ThinkingFooter> {
  late bool _expanded = widget.isStreaming;

  @override
  void didUpdateWidget(covariant ThinkingFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming) {
      _expanded = true;
    } else if (oldWidget.isStreaming) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.isStreaming
                  ? widget.streamingLabel
                  : widget.collapsedLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.thinking,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = ChatMessagesController();
  final _user = const ChatUser(id: 'user', name: '你');
  final _ai = const ChatUser(id: 'nobodywho', name: 'NobodyWho');

  nobodywho.Chat? _chat;
  Future<ExpenseLedger>? _ledger;
  final List<PickedAttachment> _attachments = [];
  ModelChoice _modelChoice = ModelChoice.multimodal;
  bool _isLoading = false;
  int _tabIndex = 0;
  String _status = '首次提问时加载模型';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<nobodywho.Chat> _loadChat() async {
    final existing = _chat;
    if (existing != null) {
      _logLoad('reuse loaded chat');
      return existing;
    }

    final modelChoice = _modelChoice;
    final total = Stopwatch()..start();
    _logLoad('start loading chat: ${modelChoice.label}');

    setState(() {
      _isLoading = true;
      _status = '正在加载${modelChoice.label}...';
    });

    _logLoad('get documents directory start');
    final dir = await getApplicationDocumentsDirectory();
    _logLoad('documents directory: ${dir.path}');
    final model = await _copyAssetToDocuments(dir, modelChoice.modelAssetPath);
    final projectionAssetPath = modelChoice.projectionAssetPath;
    final projection = projectionAssetPath == null
        ? null
        : await _copyAssetToDocuments(dir, projectionAssetPath);

    _logLoad('Model.load start: ${modelChoice.label}');
    _setStatus('正在初始化${modelChoice.label}...');
    final loadedModel = await nobodywho.Model.load(
      modelPath: model.path,
      projectionModelPath: projection?.path,
    );
    _logLoad('Model.load done in ${total.elapsedMilliseconds}ms');

    _logLoad('Chat create start');
    final chat = nobodywho.Chat(
      model: loadedModel,
      templateVariables: {'enable_thinking': true},
      systemPrompt:
          '你是一个简洁、可靠的中文助手。'
          '${modelChoice.supportsAttachments ? '你可以直接理解用户上传的图片和音频。' : ''}'
          '当前时间是 ${DateTime.now().toIso8601String()}。'
          '当用户明确要求记账时，必须调用 record_transaction 工具保存收入或支出。'
          '提取 occurredAt、type、title、amount、currency、category、account、note、rawText；'
          '例如“三块钱早餐记账”应保存 type=expense, title=早餐, amount=3, currency=CNY, category=餐饮。',
      tools: [createRecordTransactionTool(_loadLedger())],
    );
    _logLoad('Chat create done in ${total.elapsedMilliseconds}ms');

    if (mounted) {
      setState(() {
        _chat = chat;
        _status = '${modelChoice.label}就绪 ${total.elapsed.inSeconds}s';
      });
    }

    _logLoad('load chat finished in ${total.elapsedMilliseconds}ms');
    return chat;
  }

  Future<ExpenseLedger> _loadLedger() async {
    final existing = _ledger;
    if (existing != null) return existing;

    final future = getApplicationDocumentsDirectory().then(
      (dir) => ExpenseLedger.open(p.join(dir.path, 'expenses.db')),
    );
    _ledger = future;
    return future;
  }

  Future<File> _copyAssetToDocuments(Directory dir, String assetPath) async {
    final stopwatch = Stopwatch()..start();
    final file = File(p.join(dir.path, p.basename(assetPath)));
    _logLoad('asset check: $assetPath -> ${file.path}');
    if (await file.exists()) {
      final size = await file.length();
      _logLoad(
        'asset already copied: ${file.path}, size=$size bytes, '
        'elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      return file;
    }

    _setStatus('正在复制 ${p.basename(assetPath)}...');
    if (Platform.isAndroid) {
      _logLoad('native asset copy start: $assetPath');
      final bytes = await _assetChannel.invokeMethod<int>('copyAssetToFile', {
        'assetPath': assetPath,
        'destinationPath': file.path,
      });
      _logLoad(
        'native asset copy done: $assetPath, '
        'bytes=$bytes, elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      return file;
    }

    _logLoad('rootBundle.load start: $assetPath');
    final data = await rootBundle.load(assetPath);
    _logLoad(
      'rootBundle.load done: $assetPath, '
      'size=${data.lengthInBytes} bytes, elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    _logLoad('write file start: ${file.path}');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    _logLoad(
      'write file done: ${file.path}, '
      'elapsed=${stopwatch.elapsedMilliseconds}ms',
    );
    return file;
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  void _logLoad(String message) {
    debugPrint('[NobodyWhoLoad ${DateTime.now().toIso8601String()}] $message');
  }

  Future<void> _pickAttachment(AttachmentKind kind) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: kind == AttachmentKind.image
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
    );
    if (file?.path == null) return;
    setState(() {
      _attachments.add(
        PickedAttachment(path: file!.path!, name: file.name, kind: kind),
      );
    });
  }

  void _removeAttachment(PickedAttachment attachment) {
    setState(() => _attachments.remove(attachment));
  }

  void _switchModel(ModelChoice choice) {
    if (_isLoading || choice == _modelChoice) return;
    setState(() {
      _modelChoice = choice;
      _chat = null;
      if (!choice.supportsAttachments) _attachments.clear();
      _status = '已切换到${choice.label}';
    });
    _logLoad('model switched: ${choice.label}');
  }

  Future<void> _send(ChatMessage message) async {
    if (_isLoading) return;
    final attachments = List<PickedAttachment>.of(_attachments);
    if (attachments.isNotEmpty && !_modelChoice.supportsAttachments) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前模型不支持图片/音频，请切换到多模态模型')));
      return;
    }
    final text = buildUserMessageText(message.text, attachments);
    final promptParts = buildPromptParts(message.text, attachments);
    if (promptParts.isEmpty) return;

    setState(() => _attachments.clear());

    _controller.addMessage(
      message.copyWith(
        text: text,
        media: _chatMedia(attachments),
        customProperties: {'isUserMessage': true, 'source': 'user'},
      ),
    );

    final responseId = DateTime.now().microsecondsSinceEpoch.toString();
    final response = ChatMessage(
      text: '',
      user: _ai,
      createdAt: DateTime.now(),
      isMarkdown: true,
      customProperties: {'id': responseId, 'isStreaming': true},
    );

    setState(() => _isLoading = true);
    _controller.addMessage(response);
    _controller.setStreamingMessage(responseId);

    final buffer = StringBuffer();
    var lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

    void flushResponse({bool done = false}) {
      final now = DateTime.now();
      if (!done && now.difference(lastFlush).inMilliseconds < 50) return;
      lastFlush = now;
      final parts = splitThinkBlocksForDisplay(buffer.toString());

      _controller.updateMessage(
        ChatMessage(
          text: parts.answer,
          user: _ai,
          createdAt: response.createdAt,
          isMarkdown: done,
          customProperties: {
            'id': responseId,
            'thinking': parts.thinking,
            if (!done) 'isStreaming': true,
          },
        ),
      );
    }

    try {
      final chat = await _loadChat();
      final stopwatch = Stopwatch()..start();
      var outputTokens = 0;
      Duration? firstTokenLatency;
      final stream = attachments.isEmpty
          ? chat.ask(message.text.trim())
          : chat.askWithPrompt(nobodywho.Prompt(promptParts));
      debugPrint(
        '[NobodyWhoAsk ${DateTime.now().toIso8601String()}] '
        'start stream, attachments=${attachments.length}, '
        'text_length=${message.text.trim().length}',
      );
      await for (final token in stream) {
        firstTokenLatency ??= stopwatch.elapsed;
        outputTokens++;
        buffer.write(token);
        flushResponse();
      }
      stopwatch.stop();
      flushResponse(done: true);
      _controller.stopStreamingMessage(responseId);
      final elapsedMs = stopwatch.elapsedMilliseconds.clamp(1, 1 << 31);
      final tokensPerSecond = outputTokens / elapsedMs * 1000;
      debugPrint(
        'NobodyWho metrics: output_tokens=$outputTokens '
        'elapsed_ms=${stopwatch.elapsedMilliseconds} '
        'first_token_ms=${firstTokenLatency?.inMilliseconds ?? 0} '
        'tokens_per_second=${tokensPerSecond.toStringAsFixed(2)}',
      );
      if (mounted) {
        setState(() {
          _status = '${tokensPerSecond.toStringAsFixed(1)} tok/s';
        });
      }
    } catch (err) {
      _controller.updateMessage(
        ChatMessage(
          text: '出错了：$err',
          user: _ai,
          createdAt: response.createdAt,
          customProperties: {'id': responseId},
          hasError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_chat == null) _status = '就绪';
        });
      }
    }
  }

  List<ChatMedia>? _chatMedia(List<PickedAttachment> attachments) {
    if (attachments.isEmpty) return null;
    return attachments
        .map(
          (attachment) => ChatMedia(
            url: attachment.path,
            fileName: attachment.name,
            type: switch (attachment.kind) {
              AttachmentKind.image => ChatMediaType.image,
              AttachmentKind.audio => ChatMediaType.audio,
            },
            customBuilder: attachment.kind == AttachmentKind.image
                ? (context, media) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(media.url),
                      width: 180,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NobodyWho Chat'),
          bottom: TabBar(
            onTap: (index) => setState(() => _tabIndex = index),
            tabs: const [
              Tab(text: '聊天'),
              Tab(text: '账单'),
            ],
          ),
          actions: [
            PopupMenuButton<ModelChoice>(
              tooltip: '切换模型',
              enabled: !_isLoading,
              initialValue: _modelChoice,
              onSelected: _switchModel,
              itemBuilder: (context) => [
                for (final choice in ModelChoice.values)
                  PopupMenuItem(
                    value: choice,
                    child: Row(
                      children: [
                        Icon(
                          choice == _modelChoice ? Icons.check : null,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(choice.label),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.memory_outlined),
                    const SizedBox(width: 4),
                    Text(_modelChoice.label),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  _status,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
        body: _tabIndex == 0 ? _buildChat() : LedgerPage(ledger: _loadLedger()),
      ),
    );
  }

  Widget _buildChat() {
    return AiChatWidget(
      currentUser: _user,
      aiUser: _ai,
      controller: _controller,
      onSendMessage: _send,
      loadingConfig: LoadingConfig(isLoading: _isLoading),
      messageOptions: MessageOptions(footerBuilder: buildThinkingFooter),
      enableMarkdownStreaming: false,
      streamingWordByWord: false,
      inputOptions: InputOptions(
        decoration: const InputDecoration(hintText: '问点什么...'),
        sendOnEnter: true,
        inputLeadingBuilder: _buildAttachmentButtons,
        attachmentPreviewBuilder: _buildAttachmentPreview,
      ),
      welcomeMessageConfig: const WelcomeMessageConfig(
        title: 'NobodyWho 本地聊天',
        questionsSectionTitle: '可以试试：',
      ),
      exampleQuestions: const [
        ExampleQuestion(question: '你是谁？用中文回答我。'),
        ExampleQuestion(question: '用三句话解释本地大模型。'),
      ],
    );
  }

  Widget _buildAttachmentButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '选择图片',
          onPressed: _isLoading || !_modelChoice.supportsAttachments
              ? null
              : () => _pickAttachment(AttachmentKind.image),
          icon: const Icon(Icons.image_outlined),
        ),
        IconButton(
          tooltip: '选择音频',
          onPressed: _isLoading || !_modelChoice.supportsAttachments
              ? null
              : () => _pickAttachment(AttachmentKind.audio),
          icon: const Icon(Icons.audio_file_outlined),
        ),
      ],
    );
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    if (_attachments.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final attachment in _attachments)
              InputChip(
                avatar: Icon(
                  attachment.kind == AttachmentKind.image
                      ? Icons.image_outlined
                      : Icons.audio_file_outlined,
                  size: 18,
                ),
                label: Text(attachment.name, overflow: TextOverflow.ellipsis),
                onDeleted: () => _removeAttachment(attachment),
              ),
          ],
        ),
      ),
    );
  }
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key, required this.ledger});

  final Future<ExpenseLedger> ledger;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late Future<List<TransactionEntry>> _entries = _loadEntries();

  Future<List<TransactionEntry>> _loadEntries() async {
    return (await widget.ledger).listTransactions();
  }

  void _reload() {
    setState(() => _entries = _loadEntries());
  }

  Future<void> _edit(TransactionEntry entry) async {
    final updated = await showDialog<TransactionEntry>(
      context: context,
      builder: (context) => TransactionDialog(entry: entry),
    );
    if (updated == null) return;
    await (await widget.ledger).update(updated);
    _reload();
  }

  Future<void> _delete(TransactionEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账单'),
        content: Text('确定删除“${entry.title}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await (await widget.ledger).delete(entry);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TransactionEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <TransactionEntry>[];
        final summary = MonthlySummary.fromEntries(
          entries,
          month: DateTime.now(),
        );

        return Column(
          children: [
            _SummaryBar(summary: summary),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Text('账单明细', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (entries.isEmpty)
              const Expanded(child: Center(child: Text('暂无账单')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final sign = entry.type == 'income' ? '+' : '-';
                    return ListTile(
                      title: Text('${entry.category} · ${entry.title}'),
                      subtitle: Text(_entrySubtitle(entry)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$sign${_formatAmount(entry.amount)}'),
                          IconButton(
                            tooltip: '编辑',
                            onPressed: () => _edit(entry),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () => _delete(entry),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _SummaryItem(label: '本月收入', value: summary.income),
          _SummaryItem(label: '本月支出', value: summary.expense),
          _SummaryItem(label: '本月结余', value: summary.balance),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            _formatAmount(value),
            style: theme.textTheme.titleMedium,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class TransactionDialog extends StatefulWidget {
  const TransactionDialog({super.key, required this.entry});

  final TransactionEntry entry;

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  late final _occurredAt = TextEditingController(
    text: widget.entry.occurredAtIso,
  );
  late final _type = TextEditingController(text: widget.entry.type);
  late final _title = TextEditingController(text: widget.entry.title);
  late final _amount = TextEditingController(
    text: _formatAmount(widget.entry.amount),
  );
  late final _currency = TextEditingController(text: widget.entry.currency);
  late final _category = TextEditingController(text: widget.entry.category);
  late final _account = TextEditingController(text: widget.entry.account ?? '');
  late final _note = TextEditingController(text: widget.entry.note ?? '');

  @override
  void dispose() {
    _occurredAt.dispose();
    _type.dispose();
    _title.dispose();
    _amount.dispose();
    _currency.dispose();
    _category.dispose();
    _account.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('金额格式不对')));
      return;
    }
    try {
      Navigator.pop(
        context,
        TransactionEntry.fromToolArgs(
          id: widget.entry.id,
          createdAt: widget.entry.createdAt,
          occurredAt: _occurredAt.text,
          type: _type.text,
          title: _title.text,
          amount: amount,
          currency: _currency.text,
          category: _category.text,
          account: _account.text,
          note: _note.text,
          rawText: widget.entry.rawText,
        ),
      );
    } on Object catch (err) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑账单'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '金额'),
            ),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: '分类'),
            ),
            TextField(
              controller: _type,
              decoration: const InputDecoration(labelText: '类型 expense/income'),
            ),
            TextField(
              controller: _account,
              decoration: const InputDecoration(labelText: '账户'),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            TextField(
              controller: _occurredAt,
              decoration: const InputDecoration(labelText: '发生时间'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

String _entrySubtitle(TransactionEntry entry) {
  final chunks = [
    _formatDateTime(entry.occurredAt),
    if (entry.account != null) entry.account!,
    if (entry.note != null) entry.note!,
  ];
  return chunks.join(' · ');
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _formatAmount(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
