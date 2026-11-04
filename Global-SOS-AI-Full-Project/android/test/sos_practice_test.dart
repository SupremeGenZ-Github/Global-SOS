import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/sos_practice.dart';

void main() {
  testWidgets('practice finishes locally and dismissal cancels the timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SosPractice())),
    );
    expect(find.textContaining('5 seconds'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('Practice complete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
