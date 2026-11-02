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
Future<void> start(
  WidgetTester tester, {
  Future<void> Function(String)? dialer,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'country': 'IN'});
  await tester.pumpWidget(
    GlobalSOS(
      emergencyDialer: dialer,
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
  testWidgets('SOS preparation opens below the app navigator and can be cancelled', (tester) async {
    await start(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare your SOS'), findsOneWidget);
    expect(find.text('Include location'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare your SOS'), findsNothing);
    expect(find.text('Opening dialer in 5'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SOS opens India 112 only after five seconds, without network', (
    tester,
  ) async {
    final dialed = <String>[];
    await start(
      tester,
      dialer: (n) async {
        dialed.add(n);
      },
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'SOS'));
    await tester.pump();
    expect(find.text('Opening dialer in 5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(dialed, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(dialed, ['112']);
    await tester.pump(const Duration(seconds: 8));
    expect(dialed, ['112']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Cancel countdown prevents emergency dialer launch', (
    tester,
  ) async {
    final dialed = <String>[];
    await start(
      tester,
      dialer: (n) async {
        dialed.add(n);
      },
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'SOS'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.ensureVisible(find.text('Cancel countdown'));
    await tester.tap(find.text('Cancel countdown'));
    await tester.pump(const Duration(seconds: 5));
    expect(dialed, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Leaving app cancels a pending SOS countdown', (tester) async {
    final dialed = <String>[];
    await start(
      tester,
      dialer: (n) async {
        dialed.add(n);
      },
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'SOS'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(dialed, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
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
