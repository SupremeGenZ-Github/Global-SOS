import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/localization.dart';
import 'package:global_sos_ai/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'shared language catalogue supports Telugu, Tamil and RTL routing',
    () async {
      await AppLanguages.load();
      expect(AppLanguages.languages.length, 32);
      expect(AppLanguages.translate('te', 'Home'), 'ప్రధాన పేజీ');
      expect(AppLanguages.translate('ta', 'Settings'), 'அமைப்புகள்');
      expect(AppLanguages.get('ar')['direction'], 'rtl');
      expect(classify('పోలీసు'), 'police');
      expect(classify('தீ விபத்து'), 'fire');
      expect(isUrgent('حريق'), isTrue);
    },
  );
}
