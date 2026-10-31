import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/services.dart';

void main() {
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
