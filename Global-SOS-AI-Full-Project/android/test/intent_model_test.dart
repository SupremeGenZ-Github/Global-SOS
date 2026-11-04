import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/intent_model.dart';
import 'package:global_sos_ai/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled model routes unfamiliar phrasing and abstains on ambiguity',
    () async {
      await IntentModel.load();
      expect(
        IntentModel.predict('Stranded offshore after our engine stopped'),
        'marine',
      );
      expect(
        IntentModel.predict('Seller refuses warranty for a broken appliance'),
        'consumer',
      );
      expect(IntentModel.predict('Help me please'), isNull);
      expect(classify('A toddler swallowed laundry detergent'), 'poison');
      expect(isUrgent('She collapsed beside the table'), isTrue);
    },
  );
}
