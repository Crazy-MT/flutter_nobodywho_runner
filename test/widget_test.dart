import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobodywho_android_runner/main.dart';

void main() {
  test(
    'splitThinkBlocksForDisplay separates complete and streaming think blocks',
    () {
      var parts = splitThinkBlocksForDisplay('<think>scratch</think>最终答案');
      expect(parts.thinking, 'scratch');
      expect(parts.answer, '最终答案');

      parts = splitThinkBlocksForDisplay('<think>scratch');
      expect(parts.thinking, 'scratch');
      expect(parts.answer, '');

      parts = splitThinkBlocksForDisplay('回答前缀 <thi');
      expect(parts.thinking, '');
      expect(parts.answer, '回答前缀 ');

      parts = splitThinkBlocksForDisplay('A <think>hidden</think> B');
      expect(parts.thinking, 'hidden');
      expect(parts.answer, 'A  B');

      parts = splitThinkBlocksForDisplay('<think>hidden</thi');
      expect(parts.thinking, 'hidden');
      expect(parts.answer, '');
    },
  );

  testWidgets('chat page renders before model load', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));

    expect(find.text('NobodyWho Chat'), findsOneWidget);
    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('账单'), findsOneWidget);
    expect(find.text('首次提问时加载模型'), findsOneWidget);
    expect(find.text('NobodyWho 本地聊天'), findsOneWidget);
  });
}
