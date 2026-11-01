import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'services.dart';

class DeviceTools {
  static const platform = MethodChannel('org.globalsos/device');
  static Future<void> dial(String number) =>
      platform.invokeMethod<void>('dial', {'number': number});
  static Future<String?> listen(String language) =>
      platform.invokeMethod<String>('listen', {'language': language});
  static Future<void> speak(String text, String language) => platform
      .invokeMethod<void>('speak', {'text': text, 'language': language});
  static Future<Json?> address(double lat, double lng) => platform
      .invokeMapMethod<String, dynamic>('address', {'lat': lat, 'lng': lng});
}

/// Coarse public-domain polygons suggest a country; the user always confirms.
class CountryLookup {
  static List<dynamic>? _features;
  static Future<Json> suggest(double lat, double lng, double accuracy) async {
    _features ??=
        (jsonDecode(await rootBundle.loadString('assets/countries.geojson'))
                as Json)['features']
            as List;
    final matches = <String>[];
    var nearest = double.infinity;
    for (final f in _features!) {
      final g = f['geometry'];
      final polygons = g['type'] == 'Polygon'
          ? [g['coordinates']]
          : g['coordinates'] as List;
      for (final p in polygons) {
        final outer = p[0] as List;
        var inside = _inside(lat, lng, outer);
        for (var i = 1; i < p.length; i++) {
          if (_inside(lat, lng, p[i] as List)) inside = false;
        }
        if (!inside) continue;
        final code = f['properties']['ISO_A2_EH'] ?? f['properties']['ISO_A2'];
        if (code is String && code.length == 2 && !matches.contains(code)) {
          matches.add(code);
        }
        for (var i = 0; i < outer.length - 1; i++) {
          nearest = math.min(
            nearest,
            _distance(lat, lng, outer[i], outer[i + 1]),
          );
        }
      }
    }
    return {
      'countries': matches,
      'uncertain':
          matches.length != 1 ||
          accuracy > 5000 ||
          nearest < math.max(20000, accuracy * 2),
      'border_distance_m': nearest.isFinite ? nearest : null,
    };
  }

  static bool _inside(double lat, double lng, List ring) {
    var yes = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final x = (ring[i][0] as num).toDouble(),
          y = (ring[i][1] as num).toDouble();
      final xj = (ring[j][0] as num).toDouble(),
          yj = (ring[j][1] as num).toDouble();
      if ((x - xj).abs() > 180) return false;
      if ((y > lat) != (yj > lat) &&
          lng < (xj - x) * (lat - y) / (yj - y) + x) {
        yes = !yes;
      }
    }
    return yes;
  }

  static double _distance(double lat, double lng, List a, List b) {
    final scale = math.cos(lat * math.pi / 180);
    final ax = ((a[0] as num) - lng) * scale, ay = (a[1] as num) - lat;
    final bx = ((b[0] as num) - lng) * scale, by = (b[1] as num) - lat;
    final dx = bx - ax, dy = by - ay;
    final t = (dx * dx + dy * dy) == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
    return math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2)) *
        111320;
  }
}
