import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, dynamic>;
const categoryIds = [
  'police',
  'ambulance',
  'fire',
  'women',
  'domestic',
  'child',
  'mental',
  'cyber',
  'road',
  'disaster',
  'flood',
  'missing',
  'senior',
  'disability',
  'poison',
  'utilities',
  'marine',
  'mountain',
  'tourist',
  'consular',
  'consumer',
  'trafficking',
  'workplace',
  'railway',
  'other',
];
String classify(String text) {
  final t = text.toLowerCase();
  final rules = <String, String>{
    'mental': r'suicid|self.harm|kill myself|end my life',
    'fire': r'fire|burning|smoke|flames|आग',
    'ambulance':
        r'unconscious|not breathing|chest pain|bleeding|ambulance|heart attack|medical|injur',
    'poison': r'poison|overdose',
    'domestic': r'domestic|abuse',
    'police': r'attack|robbe|police|danger|assault|gun|stalk|rape|पुलिस',
    'child': r'child|kidnap',
    'cyber': r'cyber|scam|fraud|hack',
    'road': r'crash|road accident|collision',
    'flood': r'flood|earthquake|tsunami',
    'marine': r'boat|drowning',
    'mountain': r'mountain|hiking|wilderness',
    'utilities': r'gas leak|electric',
    'women': r'woman|women',
    'tourist': r'tourist|passport',
    'railway': r'railway|train',
    'senior': r'elderly|senior',
    'disability': r'disabil|deaf',
    'consumer': r'consumer|refund',
    'missing': r'missing',
  };
  for (final e in rules.entries) {
    if (RegExp(e.value).hasMatch(t)) return e.key;
  }
  return 'other';
}

bool isUrgent(String t) => RegExp(
  r'unconscious|not breathing|can.t breathe|cannot breathe|choking|stabbed|severe bleeding|\bfire\b|attack|immediate|gun|suicid|kill myself|overdose|earthquake|flood|gas leak',
  caseSensitive: false,
).hasMatch(t);
List<Json> selectRecords(
  List<Json> records,
  String country, {
  String category = '',
  String query = '',
  String channel = '',
  String region = '',
  bool nationalOnly = false,
}) => records
    .where(
      (r) =>
          r['country'] == country &&
          (!nationalOnly || r['region'] == null) &&
          (category.isEmpty || (r['categories'] as List).contains(category)) &&
          (channel.isEmpty ||
              (r['channels'] as List).any((c) => c['kind'] == channel)) &&
          (region.isEmpty ||
              (r['region'] ?? r['city'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(region.toLowerCase())) &&
          (query.isEmpty ||
              jsonEncode([
                r['name'],
                r['categories'],
                r['channels'],
              ]).toLowerCase().contains(query.toLowerCase())),
    )
    .toList();
Uri? channelUri(Json channel, {String message = ''}) {
  final v = channel['value'].toString();
  switch (channel['kind']) {
    case 'phone':
      return RegExp(r'^\+?[0-9 ()-]{2,25}$').hasMatch(v)
          ? Uri(scheme: 'tel', path: v.replaceAll(RegExp(r'[^+0-9]'), ''))
          : null;
    case 'sms':
      return Uri(
        scheme: 'sms',
        path: v.replaceAll(RegExp(r'[^+0-9]'), ''),
        query: message.isEmpty ? null : 'body=${Uri.encodeComponent(message)}',
      );
    case 'whatsapp':
      return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(v)
          ? Uri.https(
              'wa.me',
              '/${v.substring(1)}',
              message.isEmpty ? null : {'text': message},
            )
          : null;
    case 'email':
      return Uri(
        scheme: 'mailto',
        path: v,
        query:
            'subject=Assistance%20request&body=${Uri.encodeComponent(message)}',
      );
    case 'web':
      final uri = Uri.tryParse(v);
      return uri?.scheme == 'https' ? uri : null;
  }
  return null;
}

class DirectoryStore {
  Database? _db;
  Future<Database> get database async => _db ??= await openDatabase(
    p.join(await getDatabasesPath(), 'directory.db'),
    version: 1,
    onCreate: (db, v) async {
      await db.execute(
        'CREATE TABLE snapshot(id INTEGER PRIMARY KEY CHECK(id=1),version TEXT NOT NULL,payload TEXT NOT NULL)',
      );
    },
  );
  Future<Json> load() async {
    final db = await database;
    final rows = await db.query('snapshot', where: 'id=1');
    if (rows.isNotEmpty) {
      return jsonDecode(rows.first['payload'] as String) as Json;
    }
    final seed =
        jsonDecode(await rootBundle.loadString('assets/directory.json'))
            as Json;
    await replace(seed);
    return seed;
  }

  Future<void> replace(Json data) async {
    if (data['version'] == null ||
        data['countries'] is! List ||
        data['records'] is! List) {
      throw const FormatException('Invalid snapshot');
    }
    final db = await database;
    await db.transaction((tx) async {
      await tx.insert('snapshot', {
        'id': 1,
        'version': data['version'].toString(),
        'payload': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

class SafetyVault {
  final FlutterSecureStorage secure;
  SafetyVault({FlutterSecureStorage? storage})
    : secure =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  Future<Json> load() async {
    final s = await secure.read(key: 'safety');
    if (s == null) return {'contacts': <dynamic>[], 'history': <dynamic>[]};
    return jsonDecode(s) as Json;
  }

  Future<void> save(Json data) =>
      secure.write(key: 'safety', value: jsonEncode(data));
  Future<void> clear() => secure.delete(key: 'safety');
}

class Api {
  String base;
  Api(this.base);
  Uri endpoint(String path) {
    final uri = Uri.parse(base);
    if (uri.scheme != 'https') {
      throw const FormatException('Use an HTTPS server URL');
    }
    return Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/api$path');
  }

  Future<Json> call(
    String path, {
    String method = 'GET',
    Json? body,
    String? capability,
  }) async {
    final request = http.Request(method, endpoint(path));
    request.headers['Content-Type'] = 'application/json';
    if (capability != null) {
      request.headers['Authorization'] = 'Bearer $capability';
    }
    if (body != null) request.body = jsonEncode(body);
    final client = http.Client();
    try {
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Server unavailable (${response.statusCode})');
      }
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Json;
    } finally {
      client.close();
    }
  }
}

class OfflineModel {
  final LlamaController controller = LlamaController();
  bool loaded = false;
  bool downloading = false;
  http.Client? _downloadClient;
  Future<Json> metadata() async =>
      jsonDecode(await rootBundle.loadString('assets/model.json')) as Json;
  Future<String> path() async => p.join(
    (await getApplicationSupportDirectory()).path,
    'smollm2-360m-instruct-q8_0.gguf',
  );
  Future<bool> exists() async => File(await path()).exists();
  Future<void> download(void Function(double) progress) async {
    if (downloading) throw StateError('Download already running');
    downloading = true;
    final meta = await metadata();
    final target = await path();
    final part = File('$target.part');
    final client = http.Client();
    _downloadClient = client;
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(meta['url'] as String)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw const HttpException('Model download failed');
      }
      sink = part.openWrite();
      var size = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        size += chunk.length;
        if (size > (meta['size_bytes'] as int)) {
          throw const FormatException('Model too large');
        }
        sink.add(chunk);
        progress(size / (meta['size_bytes'] as int));
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (size != meta['size_bytes']) {
        throw const FormatException('Model size mismatch');
      }
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString() != meta['sha256']) {
        throw const FormatException('Model integrity check failed');
      }
      await part.rename(target);
      progress(1);
    } finally {
      if (sink != null) await sink.close();
      client.close();
      _downloadClient = null;
      downloading = false;
      if (await part.exists()) await part.delete();
    }
  }

  void cancelDownload() => _downloadClient?.close();
  Future<void> load() async {
    final file = File(await path());
    if (!await file.exists()) {
      try {
        final bundled = await rootBundle.load('assets/offline-model.gguf');
        await file.writeAsBytes(bundled.buffer.asUint8List(), flush: true);
      } catch (_) {
        throw StateError('Download the optional model first');
      }
    }
    final meta = await metadata();
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != meta['sha256']) {
      throw const FormatException('Stored model integrity failed');
    }
    await controller.loadModel(
      modelPath: file.path,
      threads: 2,
      contextSize: 1024,
      gpuLayers: 0,
    );
    loaded = true;
  }

  Future<String?> intent(String text) async {
    if (!loaded) return null;
    try {
      final output = await controller
          .generateChat(
            messages: [
              ChatMessage(
                role: 'system',
                content:
                    'Classify the request. Reply with one category only: ${categoryIds.join(', ')}. Never output contact details, numbers, websites or advice.',
              ),
              ChatMessage(role: 'user', content: text),
            ],
            template: 'chatml',
            temperature: 0,
            maxTokens: 12,
          )
          .join()
          .timeout(const Duration(seconds: 25));
      final c = output.trim().toLowerCase().replaceAll(RegExp('[^a-z]'), '');
      return categoryIds.contains(c) ? c : null;
    } catch (_) {
      await controller.stop();
      return null;
    }
  }

  Future<void> delete() async {
    if (loaded) {
      await controller.dispose();
      loaded = false;
    }
    final f = File(await path());
    if (await f.exists()) await f.delete();
  }

  Future<void> dispose() async {
    cancelDownload();
    if (loaded) await controller.dispose();
    loaded = false;
  }
}
