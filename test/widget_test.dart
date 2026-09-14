import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobodywho_android_runner/main.dart';

void main() {
  testWidgets('chat page renders before model load', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));

    expect(find.text('NobodyWho Chat'), findsOneWidget);
    expect(find.text('首次提问时加载模型'), findsOneWidget);
    expect(find.text('NobodyWho 本地聊天'), findsOneWidget);
  });
}
