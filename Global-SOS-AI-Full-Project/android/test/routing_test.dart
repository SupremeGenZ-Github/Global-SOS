import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/services.dart';
import 'package:global_sos_ai/device_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline country suggestions identify inland fixes and flag the ocean',
    () async {
      final india = await CountryLookup.suggest(28.61, 77.21, 20);
      expect(india['countries'], contains('IN'));
      final usa = await CountryLookup.suggest(38.90, -77.04, 20);
      expect(usa['countries'], contains('US'));
      final ocean = await CountryLookup.suggest(0, 0, 20);
      expect(ocean['countries'], isEmpty);
      expect(ocean['uncertain'], true);
      final poor = await CountryLookup.suggest(28.61, 77.21, 10000);
      expect(poor['uncertain'], true);
    },
  );
  test(
    'basic conversation works offline and does not intercept urgent requests',
    () {
      expect(everydayReply('hello'), contains('Hello'));
      expect(everydayReply('what is 2 + 3?'), contains('5'));
      expect(everydayReply('calculate 1 / 0'), contains('undefined'));
      expect(everydayReply('hello there is a fire'), isNull);
    },
  );
  test(
    'regional filtering keeps national routes and isolates other regions',
    () {
      final rows = <Json>[
        {
          'country': 'IN',
          'region': null,
          'channels': [],
          'categories': ['women'],
        },
        {
          'country': 'IN',
          'region': 'Telangana',
          'channels': [],
          'categories': ['women'],
        },
        {
          'country': 'IN',
          'region': 'Maharashtra',
          'channels': [],
          'categories': ['women'],
        },
      ];
      expect(selectRecords(rows, 'IN', region: 'Telangana').length, 2);
    },
  );
  test('urgent intent and jurisdiction isolation', () {
    expect(classify('There is smoke in the building'), 'fire');
    expect(classify('My friend is not breathing'), 'ambulance');
    final records = <Json>[
      {
        'country': 'IN',
        'categories': ['fire'],
        'region': null,
        'channels': [],
      },
      {
        'country': 'US',
        'categories': ['fire'],
        'region': null,
        'channels': [],
      },
      {
        'country': 'IN',
        'categories': ['fire'],
        'region': 'Delhi',
        'channels': [],
      },
    ];
    expect(
      selectRecords(records, 'IN', category: 'fire', nationalOnly: true).length,
      1,
    );
    expect(selectRecords(records, 'XX').isEmpty, true);
  });
  test('contact deep links reject unsafe web schemes', () {
    expect(channelUri({'kind': 'web', 'value': 'javascript:alert(1)'}), null);
    expect(channelUri({'kind': 'phone', 'value': '112'})?.scheme, 'tel');
    expect(
      channelUri({'kind': 'whatsapp', 'value': '+525548911166'})?.host,
      'wa.me',
    );
  });
}
