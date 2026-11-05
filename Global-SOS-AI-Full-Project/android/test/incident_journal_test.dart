import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/incident_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('incident notes persist and can be deleted without sharing or recording', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final commands = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('org.globalsos/device'), (call) async {
        commands.add(call.method);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('org.globalsos/device'), null));
    await tester.pumpWidget(const MaterialApp(home: IncidentJournal()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New incident'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0),'Test incident');
    await tester.enterText(find.byType(TextField).at(1),'A private note');
    await tester.ensureVisible(find.text('Save incident'));
    await tester.tap(find.text('Save incident'));
    await tester.pumpAndSettle();
    expect(find.text('Test incident'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: IncidentJournal()));
    await tester.pumpAndSettle();
    expect(find.text('Test incident'), findsOneWidget);
    await tester.tap(find.text('Test incident'));
    await tester.pumpAndSettle();
    expect(find.text('A private note'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(TextButton,'Delete'));
    await tester.tap(find.widgetWithText(TextButton,'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog),matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('Test incident'), findsNothing);
    expect(commands.where((command) => ['incidentCapture','incidentShare','incidentExport'].contains(command)), isEmpty);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
