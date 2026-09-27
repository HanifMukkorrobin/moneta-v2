import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/screens/chat/widgets/chat_input_bar.dart';

void main() {
  testWidgets('ChatInputBar initial state and interactions',
      (WidgetTester tester) async {
    String? sentMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            onSendMessage: (msg) {
              sentMessage = msg;
            },
          ),
        ),
      ),
    );

    // Initial state: Hint text is present
    expect(find.textContaining('Ketik pesan bebas'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);

    // Enter text
    await tester.enterText(find.byType(TextField), 'Beli sate ayam 30rb');
    await tester.pump();

    // Suffix clear button should now be visible
    expect(find.byIcon(Icons.clear), findsOneWidget);

    // Tap send button
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    // Verify callback
    expect(sentMessage, equals('Beli sate ayam 30rb'));

    // Text field should be cleared after send
    expect(find.text('Beli sate ayam 30rb'), findsNothing);
  });

  testWidgets('ChatInputBar clear button clears text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            onSendMessage: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Pengeluaran uji coba');
    await tester.pump();
    expect(find.text('Pengeluaran uji coba'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(find.text('Pengeluaran uji coba'), findsNothing);
  });
}
