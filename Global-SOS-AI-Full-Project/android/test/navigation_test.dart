import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:global_sos_ai/main.dart';
import 'package:global_sos_ai/services.dart';

final fixture = <String, dynamic>{
  'version': 'test',
  'countries': [
    {'code': 'IN', 'name': 'India', 'un_member': true},
    {'code': 'US', 'name': 'United States', 'un_member': true},
  ],
  'records': [
    {
      'id': 'in-test',
      'country': 'IN',
      'name': 'Fixture emergency service',
      'categories': ['fire'],
      'channels': [
        {'kind': 'phone', 'value': '112', 'immediate': true},
      ],
      'source_url': 'https://www.india.gov.in/directory/helpline',
      'region': null,
      'city': null,
      'jurisdiction': 'Test fixture',
      'notes': null,
      'hours': null,
      'languages': null,
      'accessibility': null,
      'checked_at': '2026-10-31T00:00:00Z',
      'verification_status': 'source_checked',
    },
    {
      'id': 'us-test',
      'country': 'US',
      'name': 'Other-country fixture',
      'categories': ['fire'],
      'channels': [
        {'kind': 'phone', 'value': '911', 'immediate': true},
      ],
      'source_url': 'https://www.911.gov/calling-911/',
      'region': null,
      'city': null,
      'jurisdiction': 'Test fixture',
      'notes': null,
      'hours': null,
      'languages': null,
      'accessibility': null,
      'checked_at': '2026-10-31T00:00:00Z',
      'verification_status': 'source_checked',
    },
  ],
};
Future<void> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'country': 'IN'});
  await tester.pumpWidget(
    GlobalSOS(
      directoryLoader: () async => fixture,
      safetyLoader: () async => <String, dynamic>{
        'contacts': <dynamic>[],
        'history': <dynamic>[],
      },
      categoryLoader: () async => <Json>[
        {'id': 'fire', 'name': 'Fire & rescue'},
      ],
    ),
  );
  for (
    var i = 0;
    i < 40 && find.textContaining('Offline directory ready').evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.textContaining('Offline directory ready'), findsOneWidget);
}

void main() {
  testWidgets('directory navigation retains country isolation', (tester) async {
    await start(tester);
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    expect(find.text('All helplines'), findsOneWidget);
    expect(find.text('Fixture emergency service'), findsOneWidget);
    expect(find.text('Other-country fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offline assistant works with no model and no network', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TextField),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byType(TextField),
      'There is smoke in the building',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Send ↗'));
    await tester.tap(find.widgetWithText(FilledButton, 'Send ↗'));
    await tester.pumpAndSettle();
    expect(find.text('Offline rules (not an LLM)'), findsOneWidget);
    expect(find.text('Fixture emergency service'), findsOneWidget);
    expect(find.text('Other-country fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
