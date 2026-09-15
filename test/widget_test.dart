import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;
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

      parts = splitThinkBlocksForDisplay(r'<|channel|>scratch<\channel|>最终答案');
      expect(parts.thinking, 'scratch');
      expect(parts.answer, '最终答案');

      parts = splitThinkBlocksForDisplay(r'<|channel|>scratch<\chan');
      expect(parts.thinking, 'scratch');
      expect(parts.answer, '');

      parts = splitThinkBlocksForDisplay('回答前缀 <|chan');
      expect(parts.thinking, '');
      expect(parts.answer, '回答前缀 ');
    },
  );

  test('builds prompt parts for text, image, and audio attachments', () {
    final parts = buildPromptParts('  看一下  ', const [
      PickedAttachment(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        kind: AttachmentKind.image,
      ),
      PickedAttachment(
        path: '/tmp/sound.mp3',
        name: 'sound.mp3',
        kind: AttachmentKind.audio,
      ),
    ]);

    expect(parts[0], isA<nobodywho.TextPart>());
    expect(parts[1], isA<nobodywho.ImagePart>());
    expect(parts[2], isA<nobodywho.AudioPart>());
    expect(
      buildUserMessageText('', const [
        PickedAttachment(
          path: '/tmp/photo.jpg',
          name: 'photo.jpg',
          kind: AttachmentKind.image,
        ),
      ]),
      'photo.jpg',
    );
  });

  testWidgets('chat page renders before model load', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));

    expect(find.text('NobodyWho Chat'), findsOneWidget);
    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('账单'), findsOneWidget);
    expect(find.text('首次提问时加载模型'), findsOneWidget);
    expect(find.text('多模态模型'), findsOneWidget);
    expect(find.text('NobodyWho 本地聊天'), findsOneWidget);
  });
}
