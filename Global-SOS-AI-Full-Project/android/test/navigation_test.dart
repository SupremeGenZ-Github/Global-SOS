import 'dart:io';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Future<Json> Function(String, String)? requester,
  Future<Json> Function()? privateLoader,
  Json? savedDirectory,
  Size viewport = const Size(900,1400),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'country': 'IN'});
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    GlobalSOS(
      emergencyDialer: dialer,
      assistantRequester: requester,
      directoryLoader: () async => savedDirectory ?? fixture,
      safetyLoader: privateLoader ?? () async => <String, dynamic>{
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
    i < 40 && find.byKey(const ValueKey('directory-status')).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('directory-status')), findsOneWidget);
}


Future<void> savePreview(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('app-preview')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Preview image unavailable');
      final file = File('build/previews/v6-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    } finally { image.dispose(); }
  });
}

void main() {
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null) return;
    final fonts = Directory('$root/bin/cache/artifacts/material_fonts');
    final roboto = FontLoader('Roboto');
    roboto.addFont(Future.value(ByteData.sublistView(
      await File('${fonts.path}/Roboto-Regular.ttf').readAsBytes())));
    await roboto.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(
      await File('${fonts.path}/MaterialIcons-Regular.otf').readAsBytes())));
    await icons.load();
  });
  testWidgets('assistant composer stays above the keyboard and Settings returns to chat', (tester) async {
    await start(tester, viewport: const Size(390,844));
    await tester.tap(find.byKey(const ValueKey('nav-assistant'))); await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets); await tester.pumpAndSettle();
    final composer = find.byKey(const ValueKey('assistant-composer'));
    expect(tester.getBottomRight(composer).dy, lessThanOrEqualTo(544));
    expect(find.byKey(const ValueKey('assistant-send')).hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Settings & country')); await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton)); await tester.pumpAndSettle();
    expect(composer, findsOneWidget); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing country discards an older pending assistant response', (tester) async {
    final result = Completer<Json>(); var requested = false;
    await start(tester, requester: (country, text) { requested = true; expect(country, 'IN'); return result.future; });
    await tester.tap(find.byKey(const ValueKey('nav-assistant'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Routing preferences')); await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Allow online AI routing');
    await tester.ensureVisible(toggle); await tester.tap(toggle); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zqxv qqqqq blorf');
    await tester.tap(find.byKey(const ValueKey('assistant-send'))); await tester.pump();
    expect(requested, isTrue);
    await tester.tap(find.widgetWithText(TextButton, 'IN')); await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('United States')); await tester.pumpAndSettle();
    result.complete({'message':'Old-country response','records': [fixture['records'][0]],'mode':'fixture'});
    await tester.pumpAndSettle();
    expect(find.text('Old-country response'), findsNothing);
    expect(find.text('Fixture emergency service'), findsNothing);
    expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });

  testWidgets('contact editor explains validation and saves without disposing active fields', (tester) async {
    await start(tester, viewport: const Size(390,844));
    await tester.tap(find.byKey(const ValueKey('nav-safety'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Add trusted contact')); await tester.pumpAndSettle();
    await tester.tap(find.text('Save contact')); await tester.pumpAndSettle();
    expect(find.text('Enter a contact name.'), findsOneWidget);
    expect(find.text('Enter a valid phone number.'), findsOneWidget);
    final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'Trusted person');
    await tester.enterText(fields.at(1), '+19995550123');
    await tester.tap(find.text('Save contact')); await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Trusted person'), findsOneWidget);
    expect(tester.takeException(), isNull); await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline emergency card opens inside the app navigator', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('nav-safety')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline emergency card'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Global SOS emergency card'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unavailable private vault offers retry instead of replacing contacts', (tester) async {
    var attempts = 0;
    await start(tester, privateLoader: () async {
      if (++attempts == 1) throw StateError('Storage unavailable');
      return {'contacts': <dynamic>[{'id':'one','name':'Saved contact','phone':'+19995550123'}], 'history': <dynamic>[]};
    });
    await tester.tap(find.byKey(const ValueKey('nav-safety')));
    await tester.pumpAndSettle();
    expect(find.text('Retry private data'), findsOneWidget);
    expect(find.text('Add trusted contact'), findsNothing);
    await tester.tap(find.text('Retry private data'));
    await tester.pumpAndSettle();
    expect(find.text('Saved contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('country picker is searchable and clears stale directory filters', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('nav-directory')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'does-not-match');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'IN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search country'), 'united');
    await tester.pumpAndSettle();
    await tester.tap(find.text('United States'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-directory')));
    await tester.pumpAndSettle();
    expect(find.text('Other-country fixture'), findsOneWidget);
    expect(find.text('Fixture emergency service'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('older records without check dates render and Settings has a back action', (tester) async {
    final oldDirectory = Map<String, dynamic>.from(fixture);
    oldDirectory['records'] = (fixture['records'] as List).map((item) => {...Map<String, dynamic>.from(item as Map), 'checked_at':null}).toList();
    await start(tester, savedDirectory: oldDirectory);
    await tester.tap(find.byKey(const ValueKey('nav-directory')));
    await tester.pumpAndSettle();
    expect(find.text('Fixture emergency service'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Settings & country'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Fixture emergency service'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phone layout supports large text and produces release previews', (tester) async {
    await start(tester, viewport: const Size(390,844));
    await savePreview(tester, 'home-dark');
    await tester.tap(find.byKey(const ValueKey('nav-directory')));
    await tester.pumpAndSettle(); await savePreview(tester, 'directory');
    await tester.tap(find.byKey(const ValueKey('nav-assistant')));
    await tester.pumpAndSettle(); await savePreview(tester, 'assistant');
    await tester.tap(find.byKey(const ValueKey('nav-sos')));
    await tester.pumpAndSettle(); await savePreview(tester, 'sos');
    await tester.tap(find.byKey(const ValueKey('nav-safety')));
    await tester.pumpAndSettle();
    await savePreview(tester, 'my-safety');
    await tester.tap(find.byTooltip('Settings & country'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Light theme'), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Light theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    await savePreview(tester, 'home-light');
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320,780);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide);
    expect(tester.takeException(), isNull);
    await savePreview(tester, 'home-large-text');
    await tester.pumpWidget(const SizedBox());
  });

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
  testWidgets('SOS cancellation stays visible on a narrow screen and other tabs', (tester) async {
    final dialed = <String>[];
    await start(tester, viewport: const Size(320,780), dialer: (number) async { dialed.add(number); });
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final startSOS = find.widgetWithText(ElevatedButton, 'SOS');
    await tester.scrollUntilVisible(startSOS.hitTestable(), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(startSOS);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-directory')));
    await tester.pump();
    final cancel = find.text('Cancel countdown');
    expect(cancel.hitTestable(), findsOneWidget);
    await tester.tap(cancel);
    await tester.pump(const Duration(seconds: 6));
    expect(dialed, isEmpty);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.byKey(const ValueKey('nav-directory')));
    await tester.pumpAndSettle();
    expect(find.text('All Helplines'), findsWidgets);
    expect(find.text('Fixture emergency service'), findsOneWidget);
    expect(find.text('Other-country fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('trip planner previews a draft without sending alerts', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('nav-safety')));
    await tester.pumpAndSettle();
    final openPlanner = find.text('Trip plan');
    await tester.scrollUntilVisible(openPlanner, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(openPlanner);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    final field = find.descendant(of: dialog, matching: find.byType(TextField)).first;
    await tester.enterText(field, 'Trip fixture');
    await tester.pumpAndSettle();
    final preview = find.descendant(of: dialog, matching: find.text('Preview plan'));
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.textContaining('Destination: Trip fixture'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('offline assistant works with no model and no network', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('nav-assistant')));
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
    await tester.ensureVisible(find.byKey(const ValueKey('assistant-send')));
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await tester.pumpAndSettle();
    expect(find.text('Offline rules (not an LLM)'), findsOneWidget);
    expect(find.text('Fixture emergency service'), findsOneWidget);
    expect(find.text('Other-country fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

