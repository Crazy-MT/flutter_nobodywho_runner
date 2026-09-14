import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter/services.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;
import 'package:path_provider/path_provider.dart';

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
  bool _isLoading = false;
  String _status = '首次提问时加载模型';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<nobodywho.Chat> _loadChat() async {
    final existing = _chat;
    if (existing != null) return existing;

    setState(() {
      _isLoading = true;
      _status = '正在加载模型...';
    });

    final dir = await getApplicationDocumentsDirectory();
    final model = File('${dir.path}/model.gguf');

    if (!await model.exists()) {
      final data = await rootBundle.load('assets/model.gguf');
      await model.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }

    final chat = await nobodywho.Chat.fromPath(
      modelPath: model.path,
      systemPrompt: '你是一个简洁、可靠的中文助手。',
    );

    if (mounted) {
      setState(() {
        _chat = chat;
        _status = '就绪';
      });
    }

    return chat;
  }

  Future<void> _send(ChatMessage message) async {
    if (_isLoading) return;

    _controller.addMessage(
      message.copyWith(
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

      _controller.updateMessage(
        ChatMessage(
          text: buffer.toString(),
          user: _ai,
          createdAt: response.createdAt,
          isMarkdown: done,
          customProperties: {'id': responseId, if (!done) 'isStreaming': true},
        ),
      );
    }

    try {
      final chat = await _loadChat();
      await for (final token in chat.ask(message.text)) {
        buffer.write(token);
        flushResponse();
      }
      flushResponse(done: true);
      _controller.stopStreamingMessage(responseId);
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
          if (_chat != null) _status = '就绪';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NobodyWho Chat'),
        actions: [
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
      body: AiChatWidget(
        currentUser: _user,
        aiUser: _ai,
        controller: _controller,
        onSendMessage: _send,
        loadingConfig: LoadingConfig(isLoading: _isLoading),
        enableMarkdownStreaming: false,
        streamingWordByWord: false,
        inputOptions: const InputOptions(
          decoration: InputDecoration(hintText: '问点什么...'),
          sendOnEnter: true,
        ),
        welcomeMessageConfig: const WelcomeMessageConfig(
          title: 'NobodyWho 本地聊天',
          questionsSectionTitle: '可以试试：',
        ),
        exampleQuestions: const [
          ExampleQuestion(question: '你是谁？用中文回答我。'),
          ExampleQuestion(question: '用三句话解释本地大模型。'),
        ],
      ),
    );
  }
}
