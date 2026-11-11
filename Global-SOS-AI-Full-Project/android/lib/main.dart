import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services.dart';
import 'localization.dart';
import 'device_tools.dart';
import 'safety_checklist.dart';
import 'intent_model.dart';
import 'sos_practice.dart';
import 'safety_hub.dart';
import 'incident_journal.dart';
import 'app_design.dart';
import 'contact_editor.dart';

const officialServer = 'https://global-sos.onrender.com';
const configuredServer = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: officialServer,
);

String resolveServer(String? saved) {
  final value = saved?.trim() ?? '';
  if (value.isEmpty) {
    return configuredServer.trim().isEmpty ? officialServer : configuredServer;
  }
  final host = value
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/+$'), '');
  return host == 'global-sos.onrender.com' ? officialServer : value;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlobalSOS());
}

class GlobalSOS extends StatefulWidget {
  const GlobalSOS({
    super.key,
    this.directoryLoader,
    this.safetyLoader,
    this.categoryLoader,
    this.emergencyDialer,
    this.assistantRequester,
  });
  final Future<void> Function(String)? emergencyDialer;
  final Future<Json> Function(String country, String message)? assistantRequester;
  final Future<Json> Function()? directoryLoader;
  final Future<Json> Function()? safetyLoader;
  final Future<List<Json>> Function()? categoryLoader;
  @override
  State<GlobalSOS> createState() => _GlobalSOSState();
}

class _GlobalSOSState extends State<GlobalSOS> with WidgetsBindingObserver {
  final navigatorKey = GlobalKey<NavigatorState>();
  final store = DirectoryStore();
  final vault = SafetyVault();
  final model = OfflineModel();
  final chatInput = TextEditingController();
  final assistantScroll = ScrollController();
  int chatGeneration = 0, settingsOrigin = 0;
  final queryInput = TextEditingController();
  final regionInput = TextEditingController();
  final serverInput = TextEditingController(text: resolveServer(null));
  SharedPreferences? prefs;
  Json? directory;
  Json safety = {'contacts': <dynamic>[], 'history': <dynamic>[]};
  List<Json> categories = [];
  String country = '',
      category = '',
      query = '',
      channel = '',
      status = 'Loading offline directory…',
      chatMode = 'Offline rules (not an LLM)';
  String regionFilter = '', voiceLanguage = 'en-IN';
  bool favoritesOnly = false, silentMode = false;
  int page = 0;
  bool light = false,
      contrast = false,
      allowOnline = false,
      busy = false,
      active = false,
      locationConsent = false,
      sharing = false;
  List<String> favorites = [];
  List<Json> conversation = [];
  Json? session;
  Position? position;
  Timer? countdownTimer;
  int? countdown;
  StreamSubscription<Position>? locationStream;
  double? modelProgress;
  List<Json> alertResults = [];
  bool notifying = false;
  bool addressConsent = false;
  String languageCode = 'en';
  String t(String text) => AppLanguages.translate(languageCode, text);
  bool syncing = false, preparingSOS = false, deviceSmsGranted = false;
  bool safetyAvailable = true;
  String syncSummary = 'Saved directory';
  String syncDetail = 'The bundled directory is available on this device.';
  int sosGeneration = 0, locationGeneration = 0;
  DateTime? lastSync;
  Future<void>? pendingLocation;
  Api get api => Api(resolveServer(serverInput.text));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(initialize());
  }

  Future<void> initialize() async {
    try {
      final d = await (widget.directoryLoader?.call() ?? store.load());
      Json s;
      var privateDataLoaded = true;
      try {
        s = await (widget.safetyLoader?.call() ?? vault.load());
      } catch (_) {
        privateDataLoaded = false;
        s = {'contacts': <dynamic>[], 'history': <dynamic>[]};
      }
      s['contacts'] = s['contacts'] is List ? s['contacts'] : <dynamic>[];
      s['history'] = s['history'] is List ? s['history'] : <dynamic>[];
      final p = await SharedPreferences.getInstance();
      await AppLanguages.load();
      await IntentModel.load();
      final c =
          await (widget.categoryLoader?.call() ??
              rootBundle
                  .loadString('assets/categories.json')
                  .then((text) => (jsonDecode(text) as List).cast<Json>()));
      if (!mounted) return;
      setState(() {
        directory = d;
        safety = s;
        safetyAvailable = privateDataLoaded;
        prefs = p;
        categories = c;
        final savedCountry = p.getString('country') ?? '';
        country = (d['countries'] as List).any((item) => item['code'] == savedCountry) ? savedCountry : '';
        final savedLanguage = p.getString('language') ?? 'en';
        languageCode = AppLanguages.languages.any((item) => item['code'] == savedLanguage) ? savedLanguage : 'en';
        favorites = p.getStringList('favorites') ?? [];
        light = p.getBool('light') ?? false;
        contrast = p.getBool('contrast') ?? false;
        voiceLanguage = p.getString('voiceLanguage') ?? 'en-IN';
        silentMode = p.getBool('silentMode') ?? false;
        addressConsent = p.getBool('addressConsent') ?? false;
        final savedServer = p.getString('server');
        serverInput.text = resolveServer(savedServer);
        if (savedServer != null && savedServer != serverInput.text) {
          unawaited(p.setString('server', serverInput.text));
        }
        status = 'Offline directory ready · version ${d['version']}';
        syncDetail = status;
      });
      if (widget.directoryLoader == null) unawaited(sync());
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Local data could not be opened. Restart the app; use the phone’s emergency screen if urgent.',
        );
      }
    }
  }

  void note(String value) {
    if (!mounted) return;
    setState(() => status = value);
    ScaffoldMessenger.maybeOf(
      navigatorKey.currentContext ?? context,
    )?.showSnackBar(SnackBar(content: Text(value)));
  }

  List<Json> get records => (directory?['records'] as List? ?? []).cast<Json>();
  Future<void> sync() async {
    if (syncing || !mounted) return;
    serverInput.text = resolveServer(serverInput.text);
    setState(() => syncing = true);
    try {
      final data = await api.call('/directory');
      if (data['version'] == null || data['countries'] is! List ||
          data['records'] is! List || (data['countries'] as List).isEmpty) {
        throw const FormatException('Invalid directory');
      }
      if (data['authoritative'] == false) {
        final detail = data['database_status'] == 'not_configured'
            ? 'Public directory ready. Cloud features are not configured.'
            : 'Server online. PostgreSQL unavailable; saved directory preserved. Check DATABASE_URL in Render.';
        lastSync = DateTime.now();
        if (mounted) { setState(() {
          syncSummary = data['database_status'] == 'not_configured' ? 'Public directory' : 'Saved directory · cloud limited';
          syncDetail = detail;
        }); }
        note(detail);
        return;
      }
      data['origin'] = 'server';
      data['bundle_release'] = directory?['bundle_release'] ?? 2;
      await store.replace(data);
      lastSync = DateTime.now();
      final detail = 'Directory synchronized · version ${data['version']}';
      if (mounted) { setState(() {
        directory = data; syncSummary = 'Directory updated'; syncDetail = detail;
      }); }
      note(detail);
    } catch (error) {
      final detail = 'Directory request failed. Saved contacts remain available. $error';
      if (mounted) setState(() { syncSummary = 'Saved directory · update failed'; syncDetail = detail; });
      note(detail);
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> open(Uri? uri) async {
    if (uri == null) {
      note('This contact channel is invalid or unsupported.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        note('No compatible application is installed.');
        return;
      }
      note(
        'External app opened. Call connection and message delivery are not confirmed.',
      );
    } catch (_) {
      note('Could not open this channel.');
    }
  }

  Future<void> contactService(Json channel) async {
    if (channel['kind'] == 'phone' || channel['kind'] == 'web') {
      await open(channelUri(channel));
      return;
    }
    final userMessages = conversation.where((m) => m['user'] == true).toList();
    final message = TextEditingController(
      text: userMessages.isEmpty
          ? 'I need assistance. Please let me know how to get help.'
          : userMessages.last['text'].toString(),
    );
    final ok = await showDialog<bool>(
      context: navigatorKey.currentContext ?? context,
      builder: (ctx) => AlertDialog(
        title: Text('Prepare ${channel['kind']} message'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recipient: ${channel['value']}\n${channel['notes'] ?? ''}\nReview your message. The external app requires you to send it.',
              ),
              TextField(
                controller: message,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Your message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open composer'),
          ),
        ],
      ),
    );
    if (ok == true) await open(channelUri(channel, message: message.text));
    message.dispose();
  }

  bool confirmCountry() {
    if (country.isNotEmpty) return true;
    note('Confirm your current country first.');
    openSettings();
    return false;
  }

  String? get emergencyNumber {
    final candidates = records
        .where(
          (r) =>
              r['country'] == country &&
              r['region'] == null &&
              (r['categories'] as List).contains('police'),
        )
        .toList();
    if (country == 'IN') return '112';
    for (final r in candidates) {
      for (final c in r['channels'] as List) {
        if (c['kind'] == 'phone' && c['immediate'] == true) {
          return c['value'].toString().replaceAll(RegExp(r'[^+0-9]'), '');
        }
      }
    }
    return null;
  }

  Future<void> startCountdown() async {
    if (preparingSOS || active || countdown != null || !confirmCountry()) {
      return;
    }
    if (widget.emergencyDialer != null) {
      armCountdown();
      return;
    }
    setState(() => preparingSOS = true);
    try {
      final choice = await showDialog<String>(
        context: navigatorKey.currentContext ?? context,
        builder: (ctx) => AlertDialog(
          title: const Text('Prepare your SOS'),
          content: Text(
            'After five seconds, the police number opens in your dialer. Press Call there.\n\nChoose whether to include a fresh location in trusted-contact alerts. Denied permission never blocks emergency dialing.\n\n${(safety['contacts'] as List).length} trusted contacts saved. Only consenting contacts with enabled methods receive automatic alerts.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'without'),
              child: const Text('Without location'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'location'),
              child: const Text('Include location'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      ++locationGeneration;
      pendingLocation = null;
      locationConsent = choice == 'location';
      position = null;
      if (locationConsent) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          locationConsent = false;
          note('Location permission denied. SOS calling will still work.');
        }
      }
      deviceSmsGranted =
          safety['automaticAlerts'] == true && safety['deviceSms'] == true
          ? await DeviceTools.requestSmsPermission()
          : false;
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      if (locationConsent) pendingLocation = locate();
      armCountdown();
    } catch (_) {
      locationConsent = false;
      deviceSmsGranted = false;
      pendingLocation = null;
      note(
        'Optional permissions unavailable. Continuing to the emergency dialer.',
      );
      if (mounted) armCountdown();
    } finally {
      if (mounted) setState(() => preparingSOS = false);
    }
  }

  void armCountdown() {
    if (!confirmCountry() || countdown != null || active) return;
    if (emergencyNumber == null) {
      note(
        'No verified emergency calling shortcut for this country. Use your phone emergency screen.',
      );
      return;
    }
    if (!silentMode) unawaited(HapticFeedback.heavyImpact());
    setState(() {
      page = 1;
      countdown = 5;
    });
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if ((countdown ?? 1) <= 1) {
        t.cancel();
        setState(() => countdown = null);
        unawaited(beginSOS());
      } else {
        setState(() => countdown = countdown! - 1);
      }
    });
  }

  Future<void> saveSafety() async {
    if (!safetyAvailable) {
      note('Private safety data is unavailable. Retry loading it in My Safety before making changes.');
      return;
    }
    try {
      await vault.save(safety);
    } catch (_) {
      note('Could not save private safety data.');
    }
  }

  Future<void> beginSOS() async {
    final generation = ++sosGeneration;
    setState(() {
      active = true;
      alertResults = [];
    });
    if (widget.emergencyDialer == null) {
      unawaited(completeSOSAlerts(generation));
    }
    (safety['history'] as List).insert(0, {
      'at': DateTime.now().toIso8601String(),
      'status': 'SOS started. Call connection and alert delivery unconfirmed.',
    });
    // Launch the emergency dialer before storage, GPS or network work.
    final number = emergencyNumber;
    if (number != null) {
      try {
        await (widget.emergencyDialer?.call(number) ??
            DeviceTools.dial(number));
        note(
          'Dialer opened with $number. Press Call on the phone screen. Connection not confirmed.',
        );
      } catch (_) {
        note(
          'Could not open the dialer. Use your phone emergency calling screen.',
        );
      }
    }
    await saveSafety();
  }

  Future<void> completeSOSAlerts(int generation) async {
    await pendingLocation;
    pendingLocation = null;
    if (!mounted || !active || generation != sosGeneration) return;
    final handledSms = <String>{};
    if (safety['automaticAlerts'] == true && deviceSmsGranted) {
      for (final c in safety['contacts'] as List) {
        if (!active || generation != sosGeneration) return;
        if (c['alertConsent'] != true ||
            !(c['methods'] as List? ?? []).contains('sms')) {
          continue;
        }
        final recipient = c['phone'].toString().replaceAll(
          RegExp(r'[^+0-9]'),
          '',
        );
        if (handledSms.contains(recipient)) continue;
        handledSms.add(recipient);
        try {
          await DeviceTools.sendSms(recipient, alertMessage);
          if (mounted) {
            setState(
              () => alertResults.add({
                'kind': 'device SMS',
                'recipient': recipient,
                'status': 'submitted to Android; delivery unconfirmed',
              }),
            );
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => alertResults.add({
                'kind': 'device SMS',
                'recipient': recipient,
                'status':
                    'submission failed or unknown; not retried automatically',
              }),
            );
          }
        }
      }
    }
    if (!active || generation != sosGeneration || serverInput.text.isEmpty) {
      return;
    }
    try {
      final created = await api.call(
        '/sos',
        method: 'POST',
        body: {'country': country},
      );
      if (!mounted || !active || generation != sosGeneration) {
        await api.call(
          '/sos/${created['id']}',
          method: 'PATCH',
          capability: created['capability'],
          body: {'status': 'cancelled'},
        );
        return;
      }
      setState(() => session = created);
      if (locationConsent && position != null) {
        final p = position!;
        try {
          await api.call(
            '/sos/${created['id']}/location',
            method: 'POST',
            capability: created['capability'],
            body: {
              'lat': p.latitude,
              'lng': p.longitude,
              'accuracy': p.accuracy,
            },
          );
        } catch (_) {
          note(
            'Location upload failed. Alerts can still include the captured map position.',
          );
        }
      }
      if (active &&
          generation == sosGeneration &&
          safety['automaticAlerts'] == true) {
        await notifyContacts(skipSms: handledSms);
      }
    } catch (_) {
      note(
        'Server session unavailable. Device SMS results appear above; other alerts were not submitted.',
      );
    }
  }

  Future<void> locate() async {
    final generation = locationGeneration;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        note(
          'Enable device location or continue with manual country selection.',
        );
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        note('Location permission unavailable. Select your country manually.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted &&
          generation == locationGeneration &&
          (preparingSOS || countdown != null || active || !locationConsent)) {
        setState(() => position = pos);
      }
      note(
        'Location captured locally. Confirm your country manually; GPS does not establish emergency jurisdiction.',
      );
    } catch (_) {
      note(
        'Unable to determine location. Manual country selection remains available.',
      );
    }
  }

  String get alertMessage =>
      '${silentMode ? 'Please check in with me when you can.' : 'I activated Global SOS AI and need help. Please contact me.'}'
      '${locationConsent && position != null ? ' ${DateTime.now().difference(position!.timestamp).inMinutes >= 2 ? 'Last known location' : 'Location'} from ${position!.timestamp.toUtc().toIso8601String()}: https://maps.google.com/?q=${position!.latitude},${position!.longitude}' : ''}'
      '${sharing ? ' Private session: $privateLink' : ''}';

  Future<void> notifyContacts({Set<String> skipSms = const {}}) async {
    if (session == null || notifying) return;
    final contacts = <Json>[];
    for (final c in safety['contacts'] as List) {
      if (c['alertConsent'] != true) continue;
      for (final method in (c['methods'] as List? ?? ['sms'])) {
        final recipient = method == 'email' ? c['email'] : c['phone'];
        if (recipient != null && recipient.toString().isNotEmpty) {
          if (method == 'sms' &&
              skipSms.contains(
                recipient.toString().replaceAll(RegExp(r'[^+0-9]'), ''),
              )) {
            continue;
          }
          contacts.add({'kind': method, 'recipient': recipient});
        }
      }
    }
    if (contacts.isEmpty) {
      note(
        'Add a trusted contact and enable its permitted alert methods first.',
      );
      return;
    }
    setState(() => notifying = true);
    try {
      final response = await api.call(
        '/sos/${session!['id']}/notify',
        method: 'POST',
        capability: session!['capability'],
        alertToken: safety['alertToken']?.toString(),
        body: {
          'consent': true,
          'contacts': contacts.take(10).toList(),
          'message': alertMessage,
        },
      );
      if (mounted) {
        setState(
          () => alertResults = [
            ...alertResults,
            ...(response['results'] as List).cast<Json>(),
          ],
        );
      }
    } catch (_) {
      note(
        'Provider alerts unavailable. Use the trusted-contact SMS, WhatsApp or email buttons. No delivery confirmed.',
      );
    } finally {
      if (mounted) setState(() => notifying = false);
    }
  }

  Future<void> refreshAlerts() async {
    if (session == null) return;
    try {
      final r = await api.call(
        '/sos/${session!['id']}/notifications',
        capability: session!['capability'],
      );
      if (mounted) {
        final updates = (r['results'] as List).cast<Json>();
        bool matches(Json a, Json b) =>
            a['recipient_hash'] != null &&
            a['recipient_hash'] == b['recipient_hash'] &&
            a['kind'] == b['kind'];
        setState(
          () => alertResults = [
            for (final old in alertResults)
              {
                ...old,
                ...updates.firstWhere(
                  (update) => matches(old, update),
                  orElse: () => {},
                ),
              },
            ...updates.where(
              (update) => !alertResults.any((old) => matches(old, update)),
            ),
          ],
        );
      }
    } catch (_) {
      note('Could not refresh provider status. Last reported state retained.');
    }
  }

  Future<void> detectCountry() async {
    await locate();
    if (position == null || !mounted) return;
    final p = position!;
    try {
      final guess = await CountryLookup.suggest(
        p.latitude,
        p.longitude,
        p.accuracy,
      );
      final codes = (guess['countries'] as List).cast<String>();
      Json? address;
      try {
        if (addressConsent) {
          address = await DeviceTools.address(
            p.latitude,
            p.longitude,
          ).timeout(const Duration(seconds: 5));
        }
      } catch (_) {}
      if (!mounted) return;
      final suggested = codes.length == 1
          ? codes.first
          : address?['country']?.toString();
      if (suggested == null ||
          !((directory?['countries'] as List?) ?? []).any(
            (c) => c['code'] == suggested,
          )) {
        note(
          'Location uncertain or outside coarse map coverage. Confirm your country manually.',
        );
        return;
      }
      final mismatch =
          address?['country'] != null && address!['country'] != suggested;
      final ok = await showDialog<bool>(
        context: navigatorKey.currentContext ?? context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm your location'),
          content: Text(
            'Suggested country: $suggested\nRegion: ${address?["region"] ?? "not available"}\nCity: ${address?["city"] ?? "not available"}\n${guess["uncertain"] == true || mismatch ? "Border/coastal or location uncertainty: check carefully." : "Coarse offline map suggestion."}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Select manually'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm country'),
            ),
          ],
        ),
      );
      if (ok == true && mounted && !active && countdown == null && !preparingSOS) {
        setState(() {
          ++chatGeneration; busy = false; category = ''; channel = ''; query = ''; favoritesOnly = false; queryInput.clear();
          country = suggested;
          regionFilter = address?['region']?.toString() ?? '';
          regionInput.text = regionFilter;
          conversation = [];
        });
        await prefs?.setString('country', country);
        note('Country confirmed. You can change it in Settings.');
      }
    } catch (_) {
      note(
        'Country detection unavailable. Select your current country manually.',
      );
    }
  }

  Future<void> stopSharing() async {
    await locationStream?.cancel();
    locationStream = null;
    if (mounted) setState(() => sharing = false);
  }

  Future<void> startSharing() async {
    if (session == null || !locationConsent || sharing) return;
    await locate();
    if (position == null) return;
    setState(() => sharing = true);
    locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 30,
          ),
        ).listen(
          (p) async {
            if (!sharing || session == null) return;
            try {
              await api.call(
                '/sos/${session!['id']}/location',
                method: 'POST',
                capability: session!['capability'],
                body: {
                  'lat': p.latitude,
                  'lng': p.longitude,
                  'accuracy': p.accuracy,
                },
              );
              if (mounted) setState(() => position = p);
            } catch (_) {
              note('Location upload failed. Contacts have not been notified.');
            }
          },
          onError: (Object e) {
            unawaited(stopSharing());
            note(
              'Location sharing stopped because the device location is unavailable.',
            );
          },
        );
    try {
      final p = position!;
      await api.call(
        '/sos/${session!['id']}/location',
        method: 'POST',
        capability: session!['capability'],
        body: {'lat': p.latitude, 'lng': p.longitude, 'accuracy': p.accuracy},
      );
    } catch (_) {
      note('First location upload failed.');
    }
  }

  String get privateLink => session == null
      ? ''
      : '${resolveServer(serverInput.text).replaceAll(RegExp(r'/+$'), '')}/#share=${session!['id']}.${session!['capability']}';
  Future<void> finish(String result) async {
    ++sosGeneration;
    ++locationGeneration;
    setState(() => active = false);
    await stopSharing();
    if (session != null) {
      try {
        await api.call(
          '/sos/${session!['id']}',
          method: 'PATCH',
          capability: session!['capability'],
          body: {'status': result},
        );
      } catch (_) {
        note(
          'Server update failed. The server session expires after one hour.',
        );
      }
    }
    setState(() {
      active = false;
      session = null;
      position = null;
      locationConsent = false;
    });
    (safety['history'] as List).insert(0, {
      'at': DateTime.now().toIso8601String(),
      'status': result,
    });
    await saveSafety();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.directoryLoader == null &&
          !active &&
          (lastSync == null ||
              DateTime.now().difference(lastSync!).inMinutes >= 5)) {
        unawaited(sync());
      }
    } else {
      unawaited(stopSharing());
      if (countdown != null) ++locationGeneration;
      countdownTimer?.cancel();
      if (mounted) setState(() => countdown = null);
    }
  }

  Future<void> sendChat() async {
    final text = chatInput.text.trim();
    if (text.isEmpty || busy) return;
    final everyday = everydayReply(text);
    if (everyday != null) {
      chatInput.clear();
      setState(() {
        conversation.add({'text': text, 'user': true});
        conversation.add({
          'text': everyday,
          'mode': 'Offline app guide / calculator',
          'records': <Json>[],
        });
      });
      return;
    }
    if (!confirmCountry()) return;
    final requestGeneration = ++chatGeneration;
    final requestCountry = country;
    chatInput.clear();
    setState(() {
      busy = true;
      conversation.add({'text': text, 'user': true});
    });
    scrollAssistant();
    String intent = classify(text);
    final learnedIntent = intent == 'other' ? IntentModel.predict(text) : null;
    intent = learnedIntent ?? intent;
    String mode = learnedIntent == null
        ? 'Offline rules (not an LLM)'
        : 'Offline trained intent model';
    List<Json> selected = [];
    String? answer;
    try {
      if (allowOnline && !isUrgent(text) && learnedIntent == null) {
        if (serverInput.text.isEmpty) throw StateError('Set server URL');
        final data = await (widget.assistantRequester?.call(requestCountry, text) ?? api.call(
          '/chat',
          method: 'POST',
          body: {'country': requestCountry, 'message': text, 'allow_online': true},
        ));
        if (data['authoritative'] == false) {
          selected = selectRecords(
            records,
            country,
            category: intent == 'other' ? '' : intent,
            nationalOnly: true,
          );
          answer = 'Using your saved directory while PostgreSQL reconnects.';
          mode = 'Offline fallback rules';
        } else {
          selected = (data['records'] as List).cast<Json>();
          answer = data['message'];
          mode = data['mode'];
        }
        if (data['ai_error'] != null) answer = '$answer ${data['ai_error']}';
      } else {
        if (intent == 'other' && model.loaded && !isUrgent(text)) {
          final guessed = await model.intent(text);
          if (guessed != null) {
            intent = guessed;
            mode = 'Offline LLM intent routing';
          }
        }
        selected = selectRecords(
          records,
          country,
          category: intent == 'other' ? '' : intent,
          nationalOnly: true,
        );
        if (isUrgent(text) &&
            !selected.any(
              (r) => (r['channels'] as List).any((c) => c['immediate'] == true),
            )) {
          final immediate = records
              .where(
                (r) =>
                    r['country'] == country &&
                    r['region'] == null &&
                    (r['categories'] as List).any(
                      (c) => ['police', 'ambulance', 'fire'].contains(c),
                    ),
              )
              .toList();
          selected = [
            ...immediate,
            ...selected.where((r) => !immediate.any((i) => i['id'] == r['id'])),
          ];
        }
      }
    } catch (e) {
      mode = 'Offline fallback rules';
      selected = selectRecords(
        records,
        country,
        category: intent == 'other' ? '' : intent,
        nationalOnly: true,
      );
      answer = 'Using saved contacts. Online request failed: $e';
    }
    if (isUrgent(text) && mode.startsWith('Offline')) {
      if (intent == 'other') selected = [];
      if (!selected.any(
        (r) => (r['channels'] as List).any((c) => c['immediate'] == true),
      )) {
        final immediate = records
            .where(
              (r) =>
                  r['country'] == country &&
                  r['region'] == null &&
                  (r['categories'] as List).any(
                    (c) => ['police', 'ambulance', 'fire'].contains(c),
                  ) &&
                  (r['channels'] as List).any((c) => c['immediate'] == true),
            )
            .toList();
        selected = [
          ...immediate,
          ...selected.where((r) => !immediate.any((i) => i['id'] == r['id'])),
        ];
      }
    }
    if (!mounted || requestGeneration != chatGeneration || requestCountry != country) return;
    selected = selected.where((record) => record['country'] == requestCountry).toList();
    setState(() {
      chatMode = mode;
      conversation.add({
        'text': selected.isEmpty
            ? answer ??
                  'Official helpline information not yet verified for this country and category. Confirm your country. If danger is immediate, use your phone’s emergency calling screen or seek nearby help.'
            : answer ??
                  (isUrgent(text)
                      ? 'If you are in immediate danger, choose a suitable emergency contact below now.'
                      : 'These source-checked services match your request. Read the jurisdiction and channel notes.'),
        'records': selected,
        'mode': mode,
      });
      busy = false;
    });
    scrollAssistant();
  }

  Future<void> importContact() async {
    try {
      final contact = await DeviceTools.pickContact();
      if (contact == null || !mounted) return;
      (safety['contacts'] as List).add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': contact['name'] ?? 'Trusted contact',
        'phone': contact['phone'],
        'email': '',
        'alertConsent': false,
        'methods': <String>[],
      });
      await saveSafety();
      if (mounted) setState(() {});
    } catch (_) {
      note('Contact picker unavailable. Add the contact manually.');
    }
  }

  Future<void> addContact() async {
    if (!safetyAvailable) return;
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;
    final contact = await showDialog<Json>(context: dialogContext, builder: (_) => const ContactEditor());
    if (contact == null || !mounted) return;
    setState(() => (safety['contacts'] as List).add(contact));
    await saveSafety();
  }

  String categoryLabel(dynamic id) {
    for (final item in categories) {
      if (item['id'] == id) return item['name'].toString();
    }
    return id.toString();
  }

  Widget helpline(Json r) {
    final channels = (r['channels'] as List).cast<Json>();
    return Builder(builder: (context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text((r['categories'] as List).map(categoryLabel).join(' · ').toUpperCase(),
          style: TextStyle(fontSize: 10, letterSpacing: .8, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary))),
          IconButton(tooltip: 'Toggle favorite', onPressed: () {
            setState(() => favorites.contains(r['id']) ? favorites.remove(r['id']) : favorites.add(r['id']));
            unawaited(prefs?.setStringList('favorites', favorites));
          }, icon: Icon(favorites.contains(r['id']) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: Theme.of(context).colorScheme.primary)),
        ]),
        Text(r['name'].toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25)),
        const SizedBox(height: 10),
        Text('${r['city'] ?? r['region'] ?? r['country']} · ${r['jurisdiction']}', style: const TextStyle(fontSize: 12, height: 1.5)),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 10, children: channels.map((channel) => FilledButton.tonalIcon(
          onPressed: () => unawaited(contactService(channel)),
          icon: Icon(channel['kind'] == 'phone' ? Icons.call_outlined : channel['kind'] == 'web' ? Icons.open_in_new_rounded : Icons.chat_bubble_outline_rounded, size: 18),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(channel['kind'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: .7)),
            Text(channel['value'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ])),
        )).toList()),
        const SizedBox(height: 12),
        Text(channels.any((channel) => channel['immediate'] == true)
          ? 'Emergency channel listed. Check its restrictions.' : 'Support or reporting. For immediate danger, use SOS.',
          style: const TextStyle(fontSize: 11, height: 1.5)),
        SafetyDisclosure(key: PageStorageKey('source-details-${r['id']}'), tilePadding: EdgeInsets.zero, title: const Text('Source & service details', style: TextStyle(fontSize: 12)), children: [
          for (final channel in channels.where((item) => item['notes'] != null))
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${channel['kind']}: ${channel['notes']}', style: const TextStyle(fontSize: 12, height: 1.5))),
          Align(alignment: AlignmentDirectional.centerStart, child: Text(
            '${r['notes'] ?? 'No additional notes.'}\nHours: ${r['hours'] ?? 'not confirmed'}\nLanguages: ${r['languages'] ?? 'not confirmed'}\n${r['accessibility'] ?? 'Accessibility not confirmed.'}\nChecked: ${checkedDate(r['checked_at'])} · ${r['verification_status']}\nGovernment webpage checked; live availability untested.',
            style: const TextStyle(fontSize: 12, height: 1.7))),
          TextButton(onPressed: () => unawaited(open(channelUri({'kind': 'web', 'value': r['source_url']}))),
            child: const Text('Open official government source ↗')),
        ]),
      ]))));
  }

  String get countryName {
    final countries = (directory?['countries'] as List? ?? []).cast<Json>();
    for (final item in countries) {
      if (item['code'] == country) return item['name'].toString();
    }
    return t('Current country');
  }

  void updateCountry(String value) {
    if (active || countdown != null || preparingSOS) return;
    setState(() {
      ++chatGeneration; busy = false;
      country = value; conversation = []; category = ''; channel = '';
      query = ''; regionFilter = ''; favoritesOnly = false;
      queryInput.clear(); regionInput.clear();
    });
    unawaited(prefs?.setString('country', value));
  }

  void browseCategory(String value) {
    setState(() {
      category = value; query = ''; regionFilter = ''; channel = ''; favoritesOnly = false;
      queryInput.clear(); regionInput.clear(); page = 3;
    });
  }

  void openJournal() => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => const IncidentJournal()),
  );

  void openPractice() {
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;
    showDialog<void>(context: dialogContext, builder: (_) => const SosPractice());
  }

  Future<void> retrySafety() async {
    try {
      final saved = await (widget.safetyLoader?.call() ?? vault.load());
      saved['contacts'] = saved['contacts'] is List ? saved['contacts'] : <dynamic>[];
      saved['history'] = saved['history'] is List ? saved['history'] : <dynamic>[];
      if (mounted) setState(() { safety = saved; safetyAvailable = true; });
    } catch (_) {
      note('Private safety data is still unavailable. Try again after unlocking your device.');
    }
  }

  Future<void> chooseCountry() async {
    if (active || countdown != null || preparingSOS) {
      note('Finish or cancel the SOS session before changing country.');
      return;
    }
    final sheetContext = navigatorKey.currentContext;
    if (sheetContext == null) return;
    var filter = '';
    final selected = await showModalBottomSheet<String>(
      context: sheetContext, isScrollControlled: true, useSafeArea: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        final countries = ((directory?['countries'] as List?) ?? []).cast<Json>()
            .where((item) => item['name'].toString().toLowerCase().contains(filter) ||
                item['code'].toString().toLowerCase().contains(filter)).toList();
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
          child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 16),
              Text(t('Current country'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(autofocus: false,
                decoration: const InputDecoration(labelText: 'Search country', prefixIcon: Icon(Icons.search)),
                onChanged: (value) => setSheetState(() => filter = value.trim().toLowerCase())),
              const SizedBox(height: 10),
              Expanded(child: countries.isEmpty
                ? const Center(child: Text('No matching country. Try another name.'))
                : ListView.builder(itemCount: countries.length, itemBuilder: (context, index) {
                    final item = countries[index];
                    return ListTile(title: Text(item['name'].toString()), subtitle: Text(item['code'].toString()),
                      trailing: item['code'] == country ? const Icon(Icons.check_circle_outline) : null,
                      onTap: () => Navigator.pop(context, item['code'].toString()));
                  })),
            ])),
        );
      }),
    );
    if (selected != null && mounted) updateCountry(selected);
  }

  void showConnectionDetails() {
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;
    showDialog<void>(context: dialogContext, builder: (context) => AlertDialog(
      title: const Text('Directory status'), content: SelectableText(syncDetail),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(onPressed: () { Navigator.pop(context); unawaited(sync()); }, child: const Text('Synchronize directory')),
      ],
    ));
  }

  String checkedDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Not recorded' : parsed.toIso8601String().split('T').first;
  }


  Widget heading(String label, String title, String description) => Builder(
    builder: (context) => Padding(padding: const EdgeInsets.only(bottom: 22, top: 4), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t(label), style: TextStyle(color: Theme.of(context).colorScheme.primary,
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(t(title.replaceAll('\n', ' ')), style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text(t(description), style: Theme.of(context).textTheme.bodyMedium),
      ],
    )),
  );

  Widget sosButton() => Semantics(label: 'SOS. Start a cancellable five-second countdown.', button: true,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: ElevatedButton(
      onPressed: startCountdown,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffd92f4a), foregroundColor: Colors.white,
        elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xffff9cac)))),
      child: Row(children: [
        const Icon(Icons.emergency_rounded, size: 34), const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t('SOS'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 4), Text(t('Start SOS'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ])),
        const Icon(Icons.north_east_rounded, size: 24),
      ]),
    )),
  );

  List<Widget> home() => [
    heading('Home', 'Help is closer than you think.', 'Find the right service. Make the next step clear.'),
    Card(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: light ? [const Color(0xffffedf1), Colors.white] : [const Color(0xff28151f), const Color(0xff101620)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
          Text(t('Emergency'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SafetyStatusTag(label: country.isEmpty ? 'Confirm country' : country),
        ]),
        sosButton(),
        Text(emergencyNumber == null ? 'Confirm your country to see its emergency shortcut.' : 'Emergency shortcut $emergencyNumber · $countryName',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        const Text('Five seconds to cancel. Press Call in the dialer.', style: TextStyle(fontSize: 12, height: 1.5)),
      ]))),
    SafetyFeatureGrid(children: [
      SafetyFeature(icon: Icons.travel_explore_outlined, title: t('All Helplines'), caption: 'Find the right service', onTap: () => setState(() => page = 3)),
      SafetyFeature(icon: Icons.auto_awesome_outlined, title: t('AI Assistant'), caption: 'Tell us what you need', onTap: () => setState(() => page = 2)),
    ]),
    const SizedBox(height: 24),
    SafetyPanel(title: 'Your safety setup', eyebrow: 'A LITTLE PREPARATION HELPS', children: [
      SafetyActionRow(icon: country.isEmpty ? Icons.public_outlined : Icons.check_circle_outline,
        title: country.isEmpty ? 'Confirm your current country' : countryName,
        caption: 'Emergency numbers depend on where you are', onTap: chooseCountry),
      const Divider(height: 1),
      SafetyActionRow(icon: Icons.people_outline,
        title: safetyAvailable ? '${(safety['contacts'] as List).length} trusted contacts' : 'Retry private safety data',
        caption: 'Choose who can help and how to contact them', onTap: () => setState(() => page = 4)),
      const Divider(height: 1),
      SafetyActionRow(icon: Icons.timer_outlined, title: 'Practice SOS', caption: 'Try a countdown without calling or sending alerts', onTap: openPractice),
    ]),
    const SafetySectionHeading(title: 'What kind of help?'),
    for (final item in categories.take(4)) Padding(padding: const EdgeInsets.only(bottom: 10), child: SafetyActionRow(
      icon: Icons.arrow_outward_rounded, title: item['name'].toString(), caption: 'Browse reviewed contacts',
      onTap: () => browseCategory(item['id'].toString()), filled: true)),
    const SizedBox(height: 12),
    Text('${records.map((record) => record['country']).toSet().length} countries with source-checked records · Live availability unconfirmed',
      style: const TextStyle(fontSize: 11, height: 1.6)),
  ];

  void cancelCountdown() {
    countdownTimer?.cancel();
    ++locationGeneration;
    pendingLocation = null;
    setState(() { countdown = null; position = null; });
  }

  List<Widget> sos() => [
    heading(
      'Emergency controls',
      'Emergency controls',
      'A clear path to urgent help. Confirm the country, choose your location preference, then start.',
    ),
    if (preparingSOS) const LinearProgressIndicator(),
    Card(child: SafetyDisclosure(key: const PageStorageKey('sos-plan'), leading: const Icon(Icons.shield_outlined), title: const Text('Your SOS plan'),
      subtitle: Text('${(safety['contacts'] as List).length} trusted contacts · ${safety['automaticAlerts'] == true ? 'Automatic alerts on' : 'Automatic alerts off'}'),
      children: [const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('1 · Review location choices\n2 · Five seconds to cancel\n3 · Press Call in the dialer')),
        TextButton(onPressed: () => setState(() => page = 4), child: const Text('Manage contacts and alert methods'))])),
    if (emergencyNumber != null)
      Text(
        'Emergency shortcut: $emergencyNumber',
        style: const TextStyle(fontSize: 24),
      ),
    if (countdown != null)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Text(
                'Opening dialer in $countdown',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 15),
              LinearProgressIndicator(value: countdown! / 5, color: const Color(0xffd92f4a), minHeight: 6),
              const SizedBox(height: 16),
              const Text('Use the pinned Cancel button below to stop.'),
            ],
          ),
        ),
      )
    else if (!active)
      sosButton()
    else ...[
      const Text('SOS session active', style: TextStyle(fontSize: 24)),
      Text(
        session == null
            ? 'Local safety session only.'
            : 'Private server session available for one hour.',
      ),
      FilledButton(
        onPressed: session == null || notifying ? null : () => notifyContacts(),
        child: Text(
          notifying
              ? 'Submitting alerts...'
              : 'Notify permitted trusted contacts',
        ),
      ),
      if (alertResults.isNotEmpty)
        OutlinedButton(
          onPressed: refreshAlerts,
          child: const Text('Refresh provider delivery status'),
        ),
      ...alertResults.map(
        (r) => Text(
          '${r["kind"]}: ${r["recipient"] ?? "trusted recipient"} — ${r["status"]}. Accepted/queued does not mean delivered.',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: locate,
        child: const Text('Capture my location'),
      ),
      if (position != null)
        Text(
          'Position ${position!.latitude.toStringAsFixed(5)}, ${position!.longitude.toStringAsFixed(5)} · ±${position!.accuracy.round()} m. Confirm the country manually.',
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Consent to uploading my location'),
        subtitle: const Text(
          'Private link holders can see the session until it expires.',
        ),
        value: locationConsent,
        onChanged: (v) => setState(() => locationConsent = v),
      ),
      FilledButton(
        onPressed: session != null && locationConsent && !sharing
            ? startSharing
            : null,
        child: Text(
          sharing
              ? 'Sharing while app is foregrounded'
              : 'Start live location sharing',
        ),
      ),
      if (sharing)
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: privateLink));
            note('Private link copied. It has not been sent.');
          },
          child: const Text('Copy private link'),
        ),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.tonal(
            onPressed: () => finish('safe'),
            child: const Text('Mark safe'),
          ),
          OutlinedButton(
            onPressed: () => finish('cancelled'),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    ],
    const SizedBox(height: 25),
    const Text('Immediate emergency services', style: TextStyle(fontSize: 21)),
    ...records
        .where(
          (r) =>
              r['country'] == country &&
              r['region'] == null &&
              (r['categories'] as List).any(
                (c) => ['police', 'ambulance', 'fire'].contains(c),
              ),
        )
        .map(helpline),
    const SizedBox(height: 20),
    const Text('Trusted contacts', style: TextStyle(fontSize: 21)),
    ...(safety['contacts'] as List).cast<Json>().map((c) => trustedContact(c)),
  ];
  List<Widget> chat() => [
    heading(
      'AI Assistant',
      'AI Assistant',
      'Describe what is happening. Find the right contact.',
    ),
    if (conversation.isEmpty) Builder(builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24), child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(22)),
          child: Icon(Icons.auto_awesome_rounded, size: 34, color: Theme.of(context).colorScheme.onPrimaryContainer)),
        const SizedBox(height: 18), const Text('What kind of help do you need?', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
        const SizedBox(height: 10), const Text('Choose an example, or type below. Share only what is needed.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.6)),
      ]))),
    if (conversation.isEmpty)
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, example) in [
            ('Medical', 'Someone collapsed and will not wake up.'),
            ('Fire', 'There is smoke in my building.'),
            ('Personal safety', 'Someone is threatening me.'),
            ('Online fraud', 'A fake payment link stole my card details.'),
          ])
            ActionChip(
              label: Text(label),
              onPressed: () => chatInput.text = example,
            ),
        ],
      ),
    SafetyDisclosure(
      key: const PageStorageKey('assistant-categories'),
      title: Text(t('Help me choose')),
      children: [
        for (final (label, value) in [
          ('Medical emergency', 'ambulance'),
          ('Fire and rescue', 'fire'),
          ('Personal safety', 'police'),
          ('Online fraud', 'cyber'),
          ('Domestic violence', 'domestic'),
          ('Child protection', 'child'),
        ])
          ListTile(
            title: Text(label),
            onTap: () => browseCategory(value),
          ),
      ],
    ),
    if (conversation.isNotEmpty && !busy)
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: () => setState(conversation.clear),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear conversation'),
        ),
      ),
    Card(child: SafetyDisclosure(key: const PageStorageKey('assistant-routing'), title: const Text('Routing preferences'), leading: const Icon(Icons.tune_rounded),
      children: [Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Allow online AI routing'),
      subtitle: const Text(
        'Sends your current message to the configured server and AI provider.',
      ),
      value: allowOnline,
      onChanged: (v) => setState(() => allowOnline = v),
    ),
    Text(
      allowOnline
          ? 'Online mode with local fallback'
          : '${model.loaded ? 'Local model loaded' : 'Optional local model not loaded'} · No chat text sent online',
    ),
]))])),
    ...conversation.map(
      (m) => Card(
        color: m['user'] == true ? (light ? const Color(0xffe6edfc) : const Color(0xff1b2b45)) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m['user'] == true ? 'YOU' : m['mode'] ?? chatMode,
                style: TextStyle(
                  fontSize: 10,
                  color: m['user'] == true ? (light ? const Color(0xff375079) : Colors.white70) : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                m['text'],
                style: TextStyle(
                  height: 1.6,
                  color: m['user'] == true ? (light ? const Color(0xff15233b) : Colors.white) : null,
                ),
              ),
              if (m['user'] != true && !silentMode)
                TextButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Read aloud'),
                  onPressed: () async {
                    try {
                      await DeviceTools.speak(
                        m['text'].toString(),
                        voiceLanguage,
                      );
                    } catch (_) {
                      note(
                        'Speech unavailable for this language. Install its Android voice data.',
                      );
                    }
                  },
                ),
              ...((m['records'] as List?) ?? [])
                  .cast<Json>()
                  .take(6)
                  .map(helpline),
            ],
          ),
        ),
      ),
    ),
    if (busy) const LinearProgressIndicator(),
  ];

  Widget assistantPage() => Column(children: [
    Expanded(child: ListView(controller: assistantScroll,
      key: PageStorageKey('assistant-$country'), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: chat())),
    Builder(builder: (context) => Container(key: const ValueKey('assistant-composer'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: chatInput, maxLength: 2000, minLines: 1, maxLines: 3,
          textInputAction: TextInputAction.send,
          decoration: const InputDecoration(labelText: 'Tell me what’s happening…', counterText: ''),
          onSubmitted: (_) => sendChat()),
        const SizedBox(height: 8),
        Row(children: [IconButton(tooltip: 'Voice input', icon: const Icon(Icons.mic_none_rounded), onPressed: () async {
          try { final text = await DeviceTools.listen(voiceLanguage); if (text != null && mounted) chatInput.text = text; }
          catch (_) { note('Voice input unavailable. You can type your message instead.'); }
        }), const SizedBox(width: 6),
          Expanded(child: Text(allowOnline ? 'Online with local fallback' : 'On-device routing', style: Theme.of(context).textTheme.labelSmall)),
          FilledButton(key: const ValueKey('assistant-send'), onPressed: busy ? null : sendChat, child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Send'), SizedBox(width: 8), Icon(Icons.arrow_upward_rounded, size: 18)]))]),
      ]))),
  ]);

  void scrollAssistant() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && assistantScroll.hasClients) {
      final context = navigatorKey.currentContext;
      if (context != null && MediaQuery.disableAnimationsOf(context)) {
        assistantScroll.jumpTo(assistantScroll.position.maxScrollExtent);
      } else {
        assistantScroll.animateTo(assistantScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    }
  });

  void openSettings() {
    settingsOrigin = page == 5 ? 0 : page;
    setState(() => page = 5);
  }

  List<Widget> directoryPage() {
    final filtered = selectRecords(
      records,
      country,
      category: category,
      query: query,
      channel: channel,
      region: regionFilter,
    ).where((r) => !favoritesOnly || favorites.contains(r['id'])).toList();
    return [
      heading(
        'All Helplines',
        'All Helplines',
        'Government sources and verification dates on every service card.',
      ),
      if (query.isNotEmpty || category.isNotEmpty || channel.isNotEmpty || regionFilter.isNotEmpty || favoritesOnly)
        Align(alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(onPressed: () => browseCategory(''), icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Clear filters'))),
      TextField(
        controller: queryInput,
        decoration: InputDecoration(
          suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() { query = ''; queryInput.clear(); })),
          labelText: 'Search service or number',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => query = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('category-$category'),
        initialValue: category,
        decoration: const InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(),
        ),
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: '', child: Text('All categories')),
          ...categories.map(
            (c) => DropdownMenuItem(
              value: c['id'] as String,
              child: Text(c['name']),
            ),
          ),
        ],
        onChanged: (v) => setState(() => category = v ?? ''),
      ),
      const SizedBox(height: 12),
      Card(child: SafetyDisclosure(key: const PageStorageKey('directory-filters'), title: const Text('More filters'), leading: const Icon(Icons.filter_alt_outlined),
        children: [Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      DropdownButtonFormField<String>(
        key: ValueKey('channel-$channel'),
        isExpanded: true,
        initialValue: channel,
        decoration: const InputDecoration(
          labelText: 'Channel',
          border: OutlineInputBorder(),
        ),
        items: ['', 'phone', 'sms', 'whatsapp', 'email', 'web']
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v.isEmpty ? 'All channels' : v),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => channel = v ?? ''),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: regionInput,
        decoration: const InputDecoration(
          labelText: 'State / region / city',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => regionFilter = v),
      ),
      SwitchListTile(
        title: const Text('Favorites only'),
        value: favoritesOnly,
        onChanged: (v) => setState(() => favoritesOnly = v),
      ),
]))])),
      if (filtered.isEmpty)
        Text(
          country.isEmpty
              ? 'Confirm your current country first.'
              : records.any((record) => record['country'] == country)
                  ? 'No matching services. Clear a filter or try another search.'
                  : 'Official helpline information not yet verified.',
          style: const TextStyle(fontSize: 22),
        ),
      Text(
        '${filtered.length} services match. Channels appear only when officially published.',
      ),
      ...filtered.map(helpline),
    ];
  }

  Widget trustedContact(Json c, {bool controls = false}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['name'].toString(), style: const TextStyle(fontSize: 20)),
          Text(c['phone'].toString()),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    open(channelUri({'kind': 'phone', 'value': c['phone']})),
                child: const Text('Call'),
              ),
              TextButton(
                onPressed: () => open(
                  channelUri({
                    'kind': 'sms',
                    'value': c['phone'],
                  }, message: alertMessage),
                ),
                child: const Text('SMS'),
              ),
              TextButton(
                onPressed: () => open(
                  channelUri({
                    'kind': 'whatsapp',
                    'value': c['phone'],
                  }, message: alertMessage),
                ),
                child: const Text('WhatsApp'),
              ),
              if ((c['email'] ?? '').toString().isNotEmpty)
                TextButton(
                  onPressed: () => open(
                    channelUri({
                      'kind': 'email',
                      'value': c['email'],
                    }, message: alertMessage),
                  ),
                  child: const Text('Email'),
                ),
            ],
          ),
          if (controls) ...[
            TextButton(
              onPressed: () => exportTrustedContact(c),
              child: const Text('Export contact file'),
            ),
            SwitchListTile(
              title: const Text('This person agreed to receive SOS alerts'),
              value: c['alertConsent'] == true,
              onChanged: (v) {
                setState(() => c['alertConsent'] = v);
                unawaited(saveSafety());
              },
            ),
            Wrap(
              children: ['sms', 'whatsapp', 'email']
                  .map(
                    (method) => FilterChip(
                      label: Text('Allow $method'),
                      selected: (c['methods'] as List? ?? []).contains(method),
                      onSelected: c['alertConsent'] != true
                          ? null
                          : (v) {
                              setState(() {
                                final methods = List<String>.from(
                                  c['methods'] as List? ?? [],
                                );
                                if (v) {
                                  methods.add(method);
                                } else {
                                  methods.remove(method);
                                }
                                c['methods'] = methods;
                              });
                              unawaited(saveSafety());
                            },
                    ),
                  )
                  .toList(),
            ),
            TextButton(
              onPressed: () {
                setState(() => (safety['contacts'] as List).remove(c));
                unawaited(saveSafety());
              },
              child: const Text('Remove contact'),
            ),
          ],
        ],
      ),
    ),
  );

  void showEmergencyCard() {
    final contacts = (safety['contacts'] as List)
        .cast<Json>()
        .map((contact) => '${contact['name']}: ${contact['phone']}')
        .join('\n');
    final card =
        'Global SOS emergency card\nCountry: $country\nPreferred language: $languageCode\n'
        'Trusted contacts:\n$contacts\nMedical notes: ${safety['medical'] ?? ''}';
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (dialog) => AlertDialog(
        title: const Text('Offline emergency card'),
        content: SingleChildScrollView(child: SelectableText(card)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DeviceTools.shareText(card);
              } catch (_) {
                note('Could not open the share sheet.');
              }
            },
            child: const Text('Share card'),
          ),
        ],
      ),
    );
  }


  Future<void> exportTrustedContact(Json contact) async {
    final phone = contact['phone'].toString().replaceAll(RegExp(r'[^+0-9]'), '');
    if (!RegExp(r'^\+?\d{3,20}$').hasMatch(phone)) {
      note('This contact does not have a valid phone number.');
      return;
    }
    final name = _vcardText(contact['name'].toString());
    try {
      final saved = await _saveTextFile('global-sos-contact.vcf', 'text/vcard',
        _fileLines(['BEGIN:VCARD', 'VERSION:3.0', 'FN:$name', 'N:$name;;;;',
          'TEL;TYPE=VOICE:$phone', 'END:VCARD']));
      if (saved) note('Contact file saved.');
    } catch (_) {
      note('Could not save the contact file.');
    }
  }

  void showTripPlanner() {
    final existing = safety['tripPlan'];
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) return;
    showDialog<void>(context: dialogContext, builder: (_) => _TripPlanDialog(
      initial: existing is Map ? Map<String, dynamic>.from(existing) : {},
      persist: (plan) async {
        final previous = safety['tripPlan'];
        if (plan == null) {
          safety.remove('tripPlan');
        } else {
          safety['tripPlan'] = plan;
        }
        try {
          await vault.save(safety);
        } catch (_) {
          if (previous == null) {
            safety.remove('tripPlan');
          } else {
            safety['tripPlan'] = previous;
          }
          rethrow;
        }
      },
    ));
  }

  List<Widget> safetyPage() => !safetyAvailable ? [
    heading('My Safety', 'My Safety', 'Your saved private data could not be opened.'),
    const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Contacts and safety settings have been retained. Unlock your device and retry loading them.'))),
    FilledButton(onPressed: retrySafety, child: const Text('Retry private data')),
  ] : [
    heading(
      'My Safety',
      'My Safety',
      'Contacts are stored in encrypted device storage. No account required.',
    ),
    const SafetySectionHeading(title: 'Trusted contacts'),
    FilledButton.icon(
      onPressed: addContact,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Add trusted contact'),
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      onPressed: importContact,
      icon: const Icon(Icons.contacts_outlined),
      label: const Text('Choose from phone contacts'),
    ),
    const SizedBox(height: 12),
    ...(safety['contacts'] as List).cast<Json>().map(
      (c) => trustedContact(c, controls: true),
    ),
    const SizedBox(height: 18),
    SafetyPanel(title: 'Personal tools', children: [
      SafetyActionRow(icon: Icons.perm_media_outlined, title: 'Incident journal', caption: 'Photos, videos and notes', onTap: openJournal),
      const Divider(height: 1),
      SafetyActionRow(icon: Icons.route_outlined, title: 'Trip plan', caption: 'Route, reminders and sharing', onTap: showTripPlanner),
      const Divider(height: 1),
      SafetyActionRow(icon: Icons.badge_outlined, title: 'Offline emergency card', caption: 'View and share your saved details', onTap: showEmergencyCard),
    ]),
    Card(child: SafetyDisclosure(
      key: const PageStorageKey('safety-sharing'),
      maintainState: true,
      leading: const Icon(Icons.notifications_outlined),
      title: const Text('Alerts and check-ins'),
      subtitle: const Text('Private inbox, location and sharing'),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: SafetyHub(
      api: api,
      t: t,
      contacts: (safety['contacts'] as List).cast<Json>(),
      quiet: silentMode,
      inbox: safety['inbox'] as Json?,
      onInbox: (value) async {
        if (!mounted) return;
        setState(() => safety['inbox'] = value);
        await saveSafety();
      },
    ))],
    )),

    const SizedBox(height: 20),
    TextFormField(
      initialValue: safety['medical']?.toString() ?? '',
      maxLines: 3,
      maxLength: 1000,
      decoration: const InputDecoration(
        labelText: 'Optional medical details (encrypted, on this device)',
        border: OutlineInputBorder(),
      ),
      onChanged: (v) {
        safety['medical'] = v;
        unawaited(saveSafety());
      },
    ),
    const SizedBox(height: 20),
    SafetyChecklist(
      checked: Map<String, dynamic>.from(safety['checklist'] as Map? ?? {}),
      onChanged: (v) {
        setState(() => safety['checklist'] = v);
        unawaited(saveSafety());
      },
    ),
    const SizedBox(height: 20),
    const Text('Favorite services', style: TextStyle(fontSize: 22)),
    ...records.where((r) => favorites.contains(r['id'])).map(helpline),
    const SizedBox(height: 20),
    Card(child: SafetyDisclosure(key: const PageStorageKey('automatic-alerts'), title: const Text('Automatic alert preferences'), leading: const Icon(Icons.send_outlined),
      children: [Padding(padding: const EdgeInsets.all(18), child: Column(children: [
    SwitchListTile(
      title: const Text(
        'Automatically alert permitted trusted contacts after SOS',
      ),
      subtitle: const Text(
        'Enable device SMS below or configure PostgreSQL, the private alert token and server providers. Each contact must consent and have permitted methods selected.',
      ),
      value: safety['automaticAlerts'] == true,
      onChanged: (v) {
        setState(() => safety['automaticAlerts'] = v);
        unawaited(saveSafety());
      },
    ),
    SwitchListTile(
      title: const Text('Use this phone to send automatic SMS'),
      subtitle: const Text(
        'Requests SMS permission when you start SOS. Uses your SIM and mobile plan; charges may apply. Only consenting contacts with SMS enabled are included. Submission does not confirm delivery.',
      ),
      value: safety['deviceSms'] == true,
      onChanged: (v) {
        setState(() => safety['deviceSms'] = v);
        unawaited(saveSafety());
      },
    ),
    TextFormField(
      initialValue: safety['alertToken']?.toString() ?? '',
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Private provider-alert token (encrypted on device)',
      ),
      onChanged: (v) {
        safety['alertToken'] = v;
        unawaited(saveSafety());
      },
    ),
      ]))])),
    const Text('Session history', style: TextStyle(fontSize: 22)),
    ...(safety['history'] as List)
        .take(30)
        .map(
          (h) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(h['status']),
            subtitle: Text(h['at']),
          ),
        ),
  ];
  List<Widget> settings() => [
    const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Global SOS · v0.6.0', style: TextStyle(fontSize: 12))),
    heading(
      'Settings',
      'Settings',
      'Set your country manually. GPS alone never decides an emergency jurisdiction.',
    ),
    SafetyPanel(title: 'Appearance & country', children: [
    DropdownButtonFormField<String>(
      key: ValueKey('language-$languageCode'),
      initialValue: languageCode,
      isExpanded: true,
      decoration: InputDecoration(labelText: t('Language')),
      items: AppLanguages.languages
          .map(
            (l) => DropdownMenuItem<String>(
              value: l['code'] as String,
              child: Text(l['name'] as String),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => languageCode = value);
        unawaited(prefs?.setString('language', value));
      },
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '32 languages for core navigation and SOS labels. Official service descriptions and detailed instructions retain their original wording. Device speech language packs are separate.',
      ),
    ),
    DropdownButtonFormField<String>(
      key: ValueKey('country-$country'),
      initialValue: country,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Current country',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Confirm country')),
        ...((directory?['countries'] as List?) ?? []).map(
          (c) => DropdownMenuItem(
            value: c['code'] as String,
            child: Text(c['name']),
          ),
        ),
      ],
      onChanged: active || countdown != null
          ? null
          : (v) {
              updateCountry(v ?? '');
            },
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Light theme'),
      value: light,
      onChanged: (v) {
        setState(() => light = v);
        unawaited(prefs?.setBool('light', v));
      },
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('High contrast'),
      value: contrast,
      onChanged: (v) {
        setState(() => contrast = v);
        unawaited(prefs?.setBool('contrast', v));
      },
    ),
]),
    Card(child: SafetyDisclosure(key: const PageStorageKey('voice-location-settings'), title: const Text('Voice & location preferences'), leading: const Icon(Icons.tune_rounded), children: [Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    const SizedBox(height: 20),
    DropdownButtonFormField<String>(
      initialValue: voiceLanguage,
      decoration: const InputDecoration(labelText: 'Preferred voice language'),
      items: const [
        DropdownMenuItem(value: 'en-IN', child: Text('English')),
        DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
        DropdownMenuItem(value: 'te-IN', child: Text('Telugu')),
        DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
      ],
      onChanged: (v) {
        setState(() => voiceLanguage = v ?? 'en-IN');
        unawaited(prefs?.setString('voiceLanguage', voiceLanguage));
      },
    ),
    SwitchListTile(
      title: const Text('Silent interface'),
      subtitle: const Text(
        'Disables app haptics and read-aloud controls. Phone and external apps keep their own sound settings.',
      ),
      value: silentMode,
      onChanged: (v) {
        setState(() => silentMode = v);
        unawaited(prefs?.setBool('silentMode', v));
      },
    ),
    OutlinedButton.icon(
      icon: const Icon(Icons.my_location),
      label: const Text('Detect my country / region'),
      onPressed: active || countdown != null ? null : detectCountry,
    ),
    SwitchListTile(
      title: const Text('Allow Android address lookup'),
      subtitle: const Text(
        'Optional: Android geocoding may send GPS coordinates to its provider to obtain state/city. Disabled uses coarse offline country polygons only.',
      ),
      value: addressConsent,
      onChanged: (v) {
        setState(() => addressConsent = v);
        unawaited(prefs?.setBool('addressConsent', v));
      },
    ),
]))])),
    SafetyPanel(title: 'Directory & connectivity', children: [
    OutlinedButton.icon(
      icon: const Icon(Icons.download_outlined),
      label: const Text('Open website APK download page'),
      onPressed: () async {
        final base = resolveServer(serverInput.text).replaceAll(RegExp(r'/+$'), '');
        final uri = Uri.tryParse(base);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          note('Enter your HTTPS website/backend URL first.');
          return;
        }
        await open(Uri.parse('$base/download'));
      },
    ),
    TextField(
      controller: serverInput,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'HTTPS Render server URL',
        hintText: officialServer,
        border: OutlineInputBorder(),
      ),
      onChanged: (v) => unawaited(prefs?.setString('server', v.trim())),
    ),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: sync, child: const Text('Synchronize directory')),
    const SizedBox(height: 24),
]),
    Card(child: SafetyDisclosure(key: const PageStorageKey('offline-model-settings'), title: const Text('Optional offline model'), leading: const Icon(Icons.memory_rounded), children: [Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text(
      'Optional offline language model',
      style: TextStyle(fontSize: 23),
    ),
    const Text(
      'SmolLM2-360M-Instruct · Q8_0 · Apache-2.0. Approximately 386 MB. English-focused intent routing. Device performance varies. Directory and rules work without it.',
      style: TextStyle(fontSize: 12, height: 1.7),
    ),
    if (modelProgress != null) LinearProgressIndicator(value: modelProgress),
    Wrap(
      spacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: model.downloading
              ? null
              : () async {
                  try {
                    setState(() => modelProgress = 0);
                    await model.download((v) {
                      if (mounted) setState(() => modelProgress = v);
                    });
                    note(
                      'Model downloaded and SHA-256 verified. Tap Load model.',
                    );
                  } catch (_) {
                    note(
                      'Model download failed or cancelled. Directory remains available.',
                    );
                  } finally {
                    if (mounted) setState(() => modelProgress = null);
                  }
                },
          child: const Text('Download model'),
        ),
        OutlinedButton(
          onPressed: model.downloading
              ? () {
                  model.cancelDownload();
                }
              : null,
          child: const Text('Cancel download'),
        ),
        FilledButton.tonal(
          onPressed: model.loaded
              ? null
              : () async {
                  try {
                    note('Verifying and loading model…');
                    await model.load();
                    if (mounted) setState(() {});
                    note(
                      'Offline model loaded. Chat remains on this device in offline mode.',
                    );
                  } catch (_) {
                    note(
                      'Model could not load. Check download, available memory and Android support.',
                    );
                  }
                },
          child: Text(model.loaded ? 'Model loaded' : 'Load model'),
        ),
      ],
    ),
    const SizedBox(height: 24),
]))])),
    Card(child: SafetyDisclosure(key: const PageStorageKey('privacy-settings'), title: const Text('Privacy & device data'), leading: const Icon(Icons.lock_outline_rounded), children: [Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text(
      'Public-service calls, SMS, WhatsApp and email open external applications; complete each action there. Optional provider alerts notify only consenting trusted contacts you explicitly enable, with a configured private backend.\n\nLocation sharing requires consent and a private server session. Links expire after one hour. Mark Safe or Cancel removes stored positions. Sharing stops when the app leaves the foreground.\n\nCountry detection gives a coarse offline suggestion and optional Android address lookup; confirm it yourself. No medical diagnosis, guaranteed response, background tracking or automatic emergency dispatch. Online routing requires your own configured server. Government webpage checks do not certify live availability.\n\nThe model identifies intent only. Untrusted model text is never displayed as contact information.',
      style: TextStyle(height: 1.7),
    ),
    OutlinedButton(
      onPressed: active || countdown != null || preparingSOS
          ? null
          : () async {
              final ctx = navigatorKey.currentContext;
              if (ctx == null) return;
              final confirmed = await showDialog<bool>(context: ctx, builder: (dialog) => AlertDialog(
                title: const Text('Delete private safety data?'),
                content: const Text('This removes contacts, medical notes, trip plans, preferences and safety history from this app. Incident journals are managed separately. Export anything you need first.'),
                actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep data')),
                  TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete data'))]));
              if (confirmed != true || !mounted || active || countdown != null || preparingSOS) return;
              await vault.clear();
              await prefs?.remove('favorites');
              if (mounted) {
                setState(() {
                  safety = {'contacts': <dynamic>[], 'history': <dynamic>[]};
                  favorites = [];
                  conversation = [];
                });
              }
              note('Private safety data deleted. Offline directory retained.');
            },
      child: const Text('Delete private safety data'),
    ),
]))])),
  ];

  @override
  Widget build(BuildContext context) {
    const navPages = [0, 3, 1, 2, 4];
    final statusLabel = syncing ? 'Updating directory…' : directory == null ? 'Loading directory…'
        : syncSummary;
    return MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => Directionality(
        textDirection: AppLanguages.get(languageCode)['direction'] == 'rtl' ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      title: 'Global SOS',
      debugShowCheckedModeBanner: false,
      theme: buildSafetyTheme(light: light, contrast: contrast),
      home: Builder(builder: (ctx) => PopScope(
        canPop: page == 0 && countdown == null && !preparingSOS,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || preparingSOS) return;
          if (countdown != null) {
            countdownTimer?.cancel();
            ++locationGeneration;
            pendingLocation = null;
            position = null;
          }
          setState(() { countdown = null; page = page == 5 ? settingsOrigin : 0; });
        },
        child: RepaintBoundary(
        key: const ValueKey('app-preview'),
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: page == 5 ? BackButton(onPressed: () => setState(() => page = settingsOrigin)) : null,
            title: Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(
                color: const Color(0xffd83750), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)),
              const SizedBox(width: 9),
              Expanded(child: Text(page == 5 ? t('Settings') : 'Global SOS',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4))),
            ]),
            actions: [
              TextButton(
                onPressed: active || countdown != null || preparingSOS ? null : chooseCountry,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.public_outlined, size: 18), const SizedBox(width: 5),
                  Text(country.isEmpty ? 'Country' : country, style: const TextStyle(fontSize: 13)),
                ]),
              ),
              if (page != 5) IconButton(tooltip: 'Settings & country',
                icon: const Icon(Icons.tune_rounded), onPressed: openSettings),
              const SizedBox(width: 6),
            ],
          ),
          body: directory == null
            ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shield_outlined, size: 48), const SizedBox(height: 18),
                  Text(status, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  OutlinedButton(onPressed: initialize, child: const Text('Retry loading')),
                ])))
            : Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Material(color: Theme.of(ctx).colorScheme.surface, borderRadius: BorderRadius.circular(14),
                    child: InkWell(key: const ValueKey('directory-status'), onTap: showConnectionDetails,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Icon(syncing ? Icons.sync_rounded : Icons.offline_pin_outlined, size: 17,
                            color: Theme.of(ctx).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12))),
                          const Icon(Icons.info_outline_rounded, size: 17),
                        ]))))),
                Expanded(child: SafeArea(top: false, bottom: false, child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: page == 2 ? assistantPage() : ListView(
                    key: PageStorageKey('safety-page-$page-$country'),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    children: switch (page) {
                      0 => home(), 1 => sos(), 2 => chat(), 3 => directoryPage(), 4 => safetyPage(), _ => settings(),
                    },
                  ),
                )))),
              ]),
          persistentFooterButtons: countdown == null ? null : [
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: cancelCountdown,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xffd83750), foregroundColor: Colors.white),
              icon: const Icon(Icons.close_rounded), label: const Text('Cancel countdown'))),
          ],
          bottomNavigationBar: page == 5 ? null : NavigationBar(
            selectedIndex: navPages.indexOf(page),
            labelBehavior: MediaQuery.textScalerOf(ctx).scale(14) > 20
                ? NavigationDestinationLabelBehavior.alwaysHide
                : NavigationDestinationLabelBehavior.onlyShowSelected,
            onDestinationSelected: (value) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => page = navPages[value]);
            },
            destinations: [
              NavigationDestination(key: const ValueKey('nav-home'), icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: t('Home')),
              NavigationDestination(key: const ValueKey('nav-directory'), icon: const Icon(Icons.travel_explore_outlined), label: t('All Helplines')),
              NavigationDestination(key: const ValueKey('nav-sos'), icon: const Icon(Icons.emergency_outlined, color: Color(0xffe95f74)), selectedIcon: const Icon(Icons.emergency_rounded, color: Color(0xffe95f74)), label: t('SOS')),
              NavigationDestination(key: const ValueKey('nav-assistant'), icon: const Icon(Icons.auto_awesome_outlined), selectedIcon: const Icon(Icons.auto_awesome_rounded), label: t('AI Assistant')),
              NavigationDestination(key: const ValueKey('nav-safety'), icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield_rounded), label: t('My Safety')),
            ],
          ),
        ),
      ))),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    countdownTimer?.cancel();
    unawaited(locationStream?.cancel());
    unawaited(model.dispose());
    unawaited(store.close());
    assistantScroll.dispose();
    chatInput.dispose();
    queryInput.dispose();
    regionInput.dispose();
    serverInput.dispose();
    super.dispose();
  }
}

const _fileBridge = MethodChannel('org.globalsos/device');

Future<bool> _saveTextFile(String name, String mime, String text) async =>
    await _fileBridge.invokeMethod<bool>('saveTextFile', {
      'name': name, 'mime': mime, 'text': text,
    }) ?? false;

String _calendarDate(DateTime value) => value.toUtc().toIso8601String()
    .replaceAll(RegExp(r'[-:]'), '')
    .replaceFirst(RegExp(r'\.\d+Z$'), 'Z');

String _vcardText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;');

String _fileLines(List<String> lines) {
  final output = StringBuffer();
  for (final line in lines) {
    var size = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final bytes = utf8.encode(character).length;
      if (size + bytes > 75) {
        output.write('\r\n ');
        size = 1;
      }
      output.write(character);
      size += bytes;
    }
    output.write('\r\n');
  }
  return output.toString();
}

class _TripPlanDialog extends StatefulWidget {
  const _TripPlanDialog({required this.initial, required this.persist});
  final Json initial;
  final Future<void> Function(Json?) persist;

  @override
  State<_TripPlanDialog> createState() => _TripPlanDialogState();
}

class _TripPlanDialogState extends State<_TripPlanDialog> {
  static const labels = {
    'destination': 'Destination',
    'route': 'Route or transport',
    'meetingPoint': 'Backup meeting point',
  };
  late final fields = {
    for (final key in labels.keys)
      key: TextEditingController(text: widget.initial[key] as String? ?? ''),
  };
  late DateTime? checkIn =
      DateTime.tryParse(widget.initial['checkIn'] as String? ?? '')?.toLocal();
  String status = '';
  bool busy = false;

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get checkInLabel => checkIn == null
      ? 'Choose planned check-in time'
      : '${MaterialLocalizations.of(context).formatCompactDate(checkIn!)} '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(checkIn!))} '
        '(${checkIn!.timeZoneName})';

  Json get plan => {
    for (final entry in fields.entries) entry.key: entry.value.text.trim(),
    'checkIn': checkIn?.toUtc().toIso8601String(),
  };

  bool get hasPlan =>
      checkIn != null || fields.values.any((field) => field.text.trim().isNotEmpty);

  String get summary => [
    'Global SOS trip plan',
    for (final entry in labels.entries)
      if (fields[entry.key]!.text.trim().isNotEmpty)
        '${entry.value}: ${fields[entry.key]!.text.trim()}',
    if (checkIn != null) 'Planned check-in: $checkInLabel',
    'I plan to check in myself. This plan sends no automatic alerts.',
  ].join('\n');

  Future<void> run(Future<String> Function() operation) async {
    setState(() => busy = true);
    try {
      final result = await operation();
      if (mounted) setState(() => status = result);
    } catch (_) {
      if (mounted) setState(() => status = 'The action could not be completed.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseTime() async {
    final now = DateTime.now();
    final last = DateTime(now.year + 2, now.month, now.day);
    final saved = checkIn;
    final day = await showDatePicker(
      context: context,
      firstDate: DateUtils.dateOnly(now),
      lastDate: last,
      initialDate: saved != null && !saved.isBefore(DateUtils.dateOnly(now)) &&
          !saved.isAfter(last) ? saved : now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(saved ?? now),
    );
    if (time == null || !mounted) return;
    setState(() => checkIn =
        DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<String> saveReminder() async {
    final date = checkIn;
    if (date == null || !date.isAfter(DateTime.now())) {
      return 'Choose a future time for the calendar reminder.';
    }
    final stamp = DateTime.now();
    final body = _fileLines([
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Global SOS//Trip Planner//EN',
      'BEGIN:VEVENT', 'UID:${stamp.microsecondsSinceEpoch}@global-sos',
      'DTSTAMP:${_calendarDate(stamp)}', 'DTSTART:${_calendarDate(date)}',
      'SUMMARY:Personal check-in', 'DESCRIPTION:Contact your trusted person yourself.',
      'BEGIN:VALARM', 'ACTION:DISPLAY', 'TRIGGER:PT0M',
      'DESCRIPTION:Time for your check-in', 'END:VALARM', 'END:VEVENT', 'END:VCALENDAR',
    ]);
    return await _saveTextFile('global-sos-check-in.ics', 'text/calendar', body)
        ? 'Calendar file saved. Import it into your calendar and check the reminder.'
        : 'Calendar export cancelled.';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trip plan and personal reminder'),
    content: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Saving is optional. A saved plan stays in this app’s private storage. Calendar reminders send no alerts to contacts.'),
        for (final entry in labels.entries)
          TextField(
            controller: fields[entry.key],
            maxLength: entry.key == 'route' ? 300 : 150,
            decoration: InputDecoration(labelText: entry.value),
            onChanged: (_) => setState(() {}),
          ),
        OutlinedButton(onPressed: busy ? null : chooseTime, child: Text(checkInLabel)),
        if (checkIn != null)
          TextButton(onPressed: busy ? null : () => setState(() => checkIn = null),
              child: const Text('Remove check-in time')),
        if (hasPlan)
          SafetyDisclosure(key: const PageStorageKey('trip-preview'), title: const Text('Preview plan'), children: [SelectableText(summary)]),
        Wrap(spacing: 6, children: [
          TextButton(onPressed: !hasPlan || busy ? null : () => run(() async {
            await widget.persist(plan);
            return 'Trip plan saved on this device.';
          }), child: const Text('Save plan')),
          TextButton(onPressed: !hasPlan || busy ? null : () => run(() async {
            await DeviceTools.shareText(summary);
            return 'Plan handed to the share sheet.';
          }), child: const Text('Share plan')),
          TextButton(onPressed: !hasPlan || busy ? null : () => run(() async {
            await Clipboard.setData(ClipboardData(text: summary));
            return 'Plan copied.';
          }), child: const Text('Copy plan')),
          TextButton(onPressed: !hasPlan || busy ? null : () => run(() async =>
            await _saveTextFile('global-sos-trip-plan.txt', 'text/plain', summary)
              ? 'Trip plan exported.' : 'Export cancelled.'),
            child: const Text('Export text')),
          TextButton(onPressed: checkIn == null || busy ? null : () => run(saveReminder),
            child: const Text('Export calendar reminder')),
          TextButton(onPressed: busy ? null : () => run(() async {
            await widget.persist(null);
            if (mounted) {
              for (final field in fields.values) {
                field.clear();
              }
              setState(() => checkIn = null);
            }
            return 'Saved trip plan cleared.';
          }), child: const Text('Clear plan')),
        ]),
        if (status.isNotEmpty) Semantics(liveRegion: true, child: Text(status)),
      ],
    )),
    actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context),
      child: const Text('Close'))],
  );
}

