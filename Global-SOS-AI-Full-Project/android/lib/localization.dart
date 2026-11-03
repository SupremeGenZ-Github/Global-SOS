import 'dart:convert';
import 'package:flutter/services.dart';

class AppLanguages {
  static bool loaded = false;
  static List<Map<String, dynamic>> languages = [
    {
      'code': 'en',
      'name': 'English',
      'direction': 'ltr',
      'labels': <String, dynamic>{},
    },
  ];
  static Map<String, dynamic> intents = {};
  static Future<void> load() async {
    if (loaded) return;
    final data =
        jsonDecode(await rootBundle.loadString('assets/languages.json'))
            as Map<String, dynamic>;
    languages = (data['languages'] as List).cast<Map<String, dynamic>>();
    intents = data['intents'] as Map<String, dynamic>;
    loaded = true;
  }

  static Map<String, dynamic> get(String code) => languages.firstWhere(
    (l) => l['code'] == code,
    orElse: () => languages.first,
  );
  static String translate(String code, String text) =>
      (get(code)['labels'] as Map)[text]?.toString() ?? text;
  static String? intent(String text) {
    for (final item in intents.entries) {
      if (RegExp(
        item.value as String,
        caseSensitive: false,
        unicode: true,
      ).hasMatch(text)) {
        return item.key;
      }
    }
    return null;
  }
}
