import 'dart:convert';
import 'package:flutter/services.dart';

class IntentModel {
  static Map<String, dynamic>? _model;

  static Future<void> load() async {
    if (_model != null) return;
    _model =
        jsonDecode(await rootBundle.loadString('assets/intent-model.json'))
            as Map<String, dynamic>;
  }

  static String? predict(String text) {
    final model = _model;
    if (model == null) return null;
    final tokens = RegExp(
      '[a-z]{3,}',
    ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toSet();
    String? category;
    var bestScore = 0.0;
    var nextScore = 0.0;
    var bestMatches = 0;
    for (final entry in (model['weights'] as Map).entries) {
      final weights = entry.value as Map;
      var score = 0.0;
      var matches = 0;
      for (final token in tokens) {
        final weight = weights[token] as num?;
        if (weight != null) {
          matches++;
          score += weight;
        }
      }
      if (score > bestScore) {
        nextScore = bestScore;
        bestScore = score;
        bestMatches = matches;
        category = entry.key as String;
      } else if (score > nextScore) {
        nextScore = score;
      }
    }
    if (category == 'other' ||
        bestMatches < 2 ||
        bestScore < (model['minimumScore'] as num) ||
        bestScore - nextScore < (model['minimumMargin'] as num)) {
      return null;
    }
    return category;
  }
}
