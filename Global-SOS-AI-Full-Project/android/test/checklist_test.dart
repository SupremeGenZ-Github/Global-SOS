import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/safety_checklist.dart';

void main() {
  testWidgets(
    'personal checklist reports edits and reset without marking other tasks',
    (tester) async {
      Map<String, dynamic> saved = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: SafetyChecklist(
                  checked: saved,
                  onChanged: (v) => setState(() => saved = v),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Confirm my current country'));
      await tester.pump();
      expect(saved['country'], true);
      expect(saved['contacts'], isNull);
      expect(find.textContaining('1 of 6'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset checklist'));
      await tester.tap(find.text('Reset checklist'));
      await tester.pump();
      expect(saved, isEmpty);
    },
  );
}
