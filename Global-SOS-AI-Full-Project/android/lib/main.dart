import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services.dart';
import 'device_tools.dart';
import 'safety_checklist.dart';

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
  });
  final Future<void> Function(String)? emergencyDialer;
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
  final queryInput = TextEditingController();
  final serverInput = TextEditingController();
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
  bool syncing = false, preparingSOS = false, deviceSmsGranted = false;
  int sosGeneration = 0, locationGeneration = 0;
  DateTime? lastSync;
  Future<void>? pendingLocation;
  Api get api => Api(serverInput.text.trim());
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
      try {
        s = await (widget.safetyLoader?.call() ?? vault.load());
      } catch (_) {
        s = {'contacts': <dynamic>[], 'history': <dynamic>[]};
      }
      s['contacts'] = s['contacts'] is List ? s['contacts'] : <dynamic>[];
      s['history'] = s['history'] is List ? s['history'] : <dynamic>[];
      final p = await SharedPreferences.getInstance();
      final c =
          await (widget.categoryLoader?.call() ??
              rootBundle
                  .loadString('assets/categories.json')
                  .then((text) => (jsonDecode(text) as List).cast<Json>()));
      if (!mounted) return;
      setState(() {
        directory = d;
        safety = s;
        prefs = p;
        categories = c;
        country = p.getString('country') ?? '';
        favorites = p.getStringList('favorites') ?? [];
        light = p.getBool('light') ?? false;
        contrast = p.getBool('contrast') ?? false;
        voiceLanguage = p.getString('voiceLanguage') ?? 'en-IN';
        silentMode = p.getBool('silentMode') ?? false;
        addressConsent = p.getBool('addressConsent') ?? false;
        serverInput.text =
            p.getString('server') ??
            const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://global-sos.onrender.com');
        if (serverInput.text.trim().isEmpty) serverInput.text = 'https://global-sos.onrender.com';
        status = 'Offline directory ready · version ${d['version']}';
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
    if (syncing) return;
    syncing = true;
    if (serverInput.text.trim().isEmpty) {
      note('Set your HTTPS server URL first.');
      setState(() => page = 5);
      syncing = false;
      return;
    }
    try {
      final d = await api.call('/directory');
      if (d['version'] == null || d['countries'] is! List || d['records'] is! List || (d['countries'] as List).isEmpty) throw const FormatException('Invalid directory');
      d['origin'] = 'server';
      d['bundle_release'] = directory?['bundle_release'] ?? 2;
      await store.replace(d);
      lastSync = DateTime.now();
      if (mounted) setState(() => directory = d);
      note('Directory synchronized · version ${d['version']}');
    } catch (_) {
      note(
        'Server unavailable. The saved offline directory remains available.',
      );
    } finally { syncing = false; }
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
    setState(() => page = 5);
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
    if (preparingSOS || active || countdown != null || !confirmCountry()) return;
    if (widget.emergencyDialer != null) { armCountdown(); return; }
    setState(() => preparingSOS = true);
    try {
      final choice = await showDialog<String>(context: navigatorKey.currentContext ?? context, builder: (ctx) => AlertDialog(
        title: const Text('Prepare your SOS'),
        content: Text('After five seconds, the police number opens in your dialer. Press Call there.\n\nChoose whether to include a fresh location in trusted-contact alerts. Denied permission never blocks emergency dialing.\n\n${(safety['contacts'] as List).length} trusted contacts saved. Only consenting contacts with enabled methods receive automatic alerts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'without'), child: const Text('Without location')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'location'), child: const Text('Include location')),
        ],
      ));
      if (choice == null || !mounted) return;
      ++locationGeneration;
      pendingLocation = null;
      locationConsent = choice == 'location';
      position = null;
      if (locationConsent) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          locationConsent = false;
          note('Location permission denied. SOS calling will still work.');
        }
      }
      deviceSmsGranted = safety['automaticAlerts'] == true && safety['deviceSms'] == true
          ? await DeviceTools.requestSmsPermission() : false;
      if (!mounted || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      if (locationConsent) pendingLocation = locate();
      armCountdown();
    } catch (_) { locationConsent = false; deviceSmsGranted = false; pendingLocation = null; note('Optional permissions unavailable. Continuing to the emergency dialer.'); if (mounted) armCountdown(); }
    finally { if (mounted) setState(() => preparingSOS = false); }
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
    try {
      await vault.save(safety);
    } catch (_) {
      note('Could not save private safety data.');
    }
  }

  Future<void> beginSOS() async {
    final generation = ++sosGeneration;
    setState(() { active = true; alertResults = []; });
    if (widget.emergencyDialer == null) unawaited(completeSOSAlerts(generation));
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
        if (c['alertConsent'] != true || !(c['methods'] as List? ?? []).contains('sms')) continue;
        final recipient = c['phone'].toString().replaceAll(RegExp(r'[^+0-9]'), '');
        if (handledSms.contains(recipient)) continue;
        handledSms.add(recipient);
        try {
          await DeviceTools.sendSms(recipient, alertMessage);
          if (mounted) setState(() => alertResults.add({'kind':'device SMS', 'recipient':recipient, 'status':'submitted to Android; delivery unconfirmed'}));
        } catch (_) {
          if (mounted) setState(() => alertResults.add({'kind':'device SMS', 'recipient':recipient, 'status':'submission failed or unknown; not retried automatically'}));
        }
      }
    }
    if (!active || generation != sosGeneration || serverInput.text.isEmpty) return;
    try {
      final created = await api.call('/sos', method:'POST', body:{'country':country});
      if (!mounted || !active || generation != sosGeneration) {
        await api.call('/sos/${created['id']}', method:'PATCH', capability:created['capability'], body:{'status':'cancelled'});
        return;
      }
      setState(() => session = created);
      if (locationConsent && position != null) {
        final p = position!;
        try { await api.call('/sos/${created['id']}/location', method:'POST', capability:created['capability'], body:{'lat':p.latitude,'lng':p.longitude,'accuracy':p.accuracy}); }
        catch (_) { note('Location upload failed. Alerts can still include the captured map position.'); }
      }
      if (active && generation == sosGeneration && safety['automaticAlerts'] == true) await notifyContacts(skipSms:handledSms);
    } catch (_) { note('Server session unavailable. Device SMS results appear above; other alerts were not submitted.'); }
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
      if (mounted && generation == locationGeneration && (preparingSOS || countdown != null || active || !locationConsent)) setState(() => position = pos);
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
      'I activated Global SOS AI and need help. Please contact me.'
      '${locationConsent && position != null ? ' Location: https://maps.google.com/?q=${position!.latitude},${position!.longitude}' : ''}'
      '${sharing ? ' Private session: $privateLink' : ''}';

  Future<void> notifyContacts({Set<String> skipSms = const {}}) async {
    if (session == null || notifying) return;
    final contacts = <Json>[];
    for (final c in safety['contacts'] as List) {
      if (c['alertConsent'] != true) continue;
      for (final method in (c['methods'] as List? ?? ['sms'])) {
        final recipient = method == 'email' ? c['email'] : c['phone'];
        if (recipient != null && recipient.toString().isNotEmpty) {
          if (method == 'sms' && skipSms.contains(recipient.toString().replaceAll(RegExp(r'[^+0-9]'), ''))) continue;
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
          () => alertResults = [...alertResults, ...(response['results'] as List).cast<Json>()],
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
        setState(() => alertResults = (r['results'] as List).cast<Json>());
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
      if (ok == true && mounted) {
        setState(() {
          country = suggested;
          regionFilter = address?['region']?.toString() ?? '';
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
      : '${serverInput.text.replaceAll(RegExp(r'/+$'), '')}/#share=${session!['id']}.${session!['capability']}';
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
      if (widget.directoryLoader == null && !active && (lastSync == null || DateTime.now().difference(lastSync!).inMinutes >= 5)) unawaited(sync());
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
    chatInput.clear();
    setState(() {
      busy = true;
      conversation.add({'text': text, 'user': true});
    });
    String intent = classify(text);
    String mode = 'Offline rules (not an LLM)';
    List<Json> selected = [];
    String? answer;
    try {
      if (allowOnline) {
        if (serverInput.text.isEmpty) throw StateError('Set server URL');
        final data = await api.call(
          '/chat',
          method: 'POST',
          body: {'country': country, 'message': text, 'allow_online': true},
        );
        selected = (data['records'] as List).cast<Json>();
        answer = data['message'];
        mode = data['mode'];
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
    } catch (_) {
      mode = 'Offline fallback rules';
      selected = selectRecords(
        records,
        country,
        category: intent == 'other' ? '' : intent,
        nationalOnly: true,
      );
      answer = 'Online routing unavailable. Use the saved contacts below.';
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
    if (!mounted) return;
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
  }

  Future<void> importContact() async {
    try {
      final contact = await DeviceTools.pickContact();
      if (contact == null || !mounted) return;
      (safety['contacts'] as List).add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':contact['name'] ?? 'Trusted contact','phone':contact['phone'],'email':'','alertConsent':false,'methods':<String>[]});
      await saveSafety();
      if (mounted) setState(() {});
    } catch (_) { note('Contact picker unavailable. Add the contact manually.'); }
  }

  Future<void> addContact() async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        email = TextEditingController();
    final result = await showDialog<bool>(
      context: navigatorKey.currentContext ?? context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trusted contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone with country code',
              ),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty ||
                  !RegExp(r'^\+?[0-9 ()-]{3,25}$').hasMatch(phone.text)) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      (safety['contacts'] as List).add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': name.text.trim(),
        'phone': phone.text,
        'email': email.text.trim(),
        'alertConsent': false,
        'methods': <String>[],
      });
      await saveSafety();
      if (mounted) setState(() {});
    }
    name.dispose();
    phone.dispose();
    email.dispose();
  }

  Widget helpline(Json r) {
    final cs = (r['channels'] as List).cast<Json>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (r['categories'] as List).join(' · ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Color(0xffe9938d),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Toggle favorite',
                  onPressed: () {
                    setState(
                      () => favorites.contains(r['id'])
                          ? favorites.remove(r['id'])
                          : favorites.add(r['id']),
                    );
                    unawaited(prefs?.setStringList('favorites', favorites));
                  },
                  icon: Icon(
                    favorites.contains(r['id'])
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            Text(
              r['name'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${r['city'] ?? r['region'] ?? r['country']} · ${r['jurisdiction']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cs
                  .map(
                    (c) => FilledButton.tonal(
                      onPressed: () => unawaited(contactService(c)),
                      child: Text(
                        '${c['kind'].toString().toUpperCase()}  ${c['value']}',
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...cs
                .where((c) => c['notes'] != null)
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${c['kind'].toString().toUpperCase()}: ${c['notes']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              cs.any((c) => c['immediate'] == true)
                  ? 'Has an emergency channel. Read channel restrictions.'
                  : 'Support / reporting service. For immediate danger, use SOS.',
              style: const TextStyle(fontSize: 12),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Source & service details',
                style: TextStyle(fontSize: 12),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${r['notes'] ?? 'No additional notes.'}\nHours: ${r['hours'] ?? 'not confirmed'}\nLanguages: ${r['languages'] ?? 'not confirmed'}\n${r['accessibility'] ?? 'Accessibility not confirmed.'}\nChecked: ${r['checked_at'].toString().substring(0, 10)} · ${r['verification_status']}\nGovernment webpage checked; service availability not tested.',
                    style: const TextStyle(fontSize: 12, height: 1.7),
                  ),
                ),
                TextButton(
                  onPressed: () => unawaited(
                    open(channelUri({'kind': 'web', 'value': r['source_url']})),
                  ),
                  child: const Text('Open official government source ↗'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget heading(String label, String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 23, top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xffe99088),
            fontSize: 11,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 35,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Text(description, style: const TextStyle(fontSize: 13, height: 1.6)),
      ],
    ),
  );
  Widget sosButton() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Semantics(
        label:
            'SOS. Long press or double tap to start a cancellable countdown.',
        button: true,
        child: GestureDetector(
          onLongPress: startCountdown,
          child: ElevatedButton(
            onPressed: startCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffe34e4e),
              foregroundColor: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: Color(0xff8e303c), width: 8),
              ),
              fixedSize: const Size(168, 168),
              elevation: 12,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 43,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'TAP OR HOLD',
                  style: TextStyle(fontSize: 8, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  List<Widget> home() => [
    heading(
      'ONE TAP. ONE CONVERSATION.',
      'Help is closer\nthan you think.',
      'Find the right service. Make the next step clear.',
    ),
    Card(
      color: const Color(0xff241c2c),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'IN AN EMERGENCY?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            sosButton(),
            const Text(
              'One moment. One action.',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calls and messages always need your action.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    ),
    Card(
      color: const Color(0xff202d47),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(height: 18),
            const Text(
              'You don’t have to\nfigure it out alone.',
              style: TextStyle(color: Colors.white, fontSize: 27, height: 1.2),
            ),
            const SizedBox(height: 15),
            const Text(
              'Describe what’s happening. Contacts come from the directory, never an AI guess.',
              style: TextStyle(color: Colors.white70, height: 1.6),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => setState(() => page = 2),
              child: const Text('Talk to the assistant ↗'),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 20),
    const Text(
      'What kind of help do you need?',
      style: TextStyle(fontSize: 21),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .take(6)
          .map(
            (c) => ActionChip(
              label: Text(c['name']),
              onPressed: () {
                setState(() {
                  category = c['id'];
                  page = 3;
                });
              },
            ),
          )
          .toList(),
    ),
    const SizedBox(height: 20),
    Text(
      '${records.map((r) => r['country']).toSet().length} countries with source-checked contacts · 193 UN member states in registry',
      style: const TextStyle(fontSize: 12, height: 1.7),
    ),
    const Text(
      'Government pages checked; operational availability and worldwide completeness are not certified.',
      style: TextStyle(fontSize: 11, height: 1.7),
    ),
  ];
  List<Widget> sos() => [
    heading(
      'YOU STAY IN CONTROL',
      'Emergency controls',
      'After five seconds, opens the verified emergency number in your phone dialer. Press Call there. Cancel below to stop.',
    ),
    if (preparingSOS) const LinearProgressIndicator(),
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${(safety['contacts'] as List).length} trusted contacts · ${safety['automaticAlerts'] == true ? 'Automatic alerts enabled' : 'Automatic alerts off'}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height:8),
      const Text('1  Choose location permission\n2  Five seconds to cancel\n3  Press Call in the dialer'),
      TextButton(onPressed: () => setState(() => page = 4), child: const Text('Manage contacts and alert methods')),
    ]))),
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
              FilledButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  ++locationGeneration;
                  pendingLocation = null;
                  setState(() {countdown = null; position = null;});
                },
                child: const Text('Cancel countdown'),
              ),
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
      'FIND YOUR NEXT STEP',
      'Safety assistant',
      'Confirm your country. Avoid unnecessary personal details.',
    ),
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
    if (conversation.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'What kind of help do you need?\nFor example: “There is smoke in my building.”',
          style: TextStyle(fontSize: 20, height: 1.7),
        ),
      ),
    ...conversation.map(
      (m) => Card(
        color: m['user'] == true ? const Color(0xff253650) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m['user'] == true ? 'YOU' : m['mode'] ?? chatMode,
                style: TextStyle(
                  fontSize: 10,
                  color: m['user'] == true ? Colors.white70 : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                m['text'],
                style: TextStyle(
                  height: 1.6,
                  color: m['user'] == true ? Colors.white : null,
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
    OutlinedButton.icon(
      icon: const Icon(Icons.mic),
      label: const Text('Voice input'),
      onPressed: () async {
        try {
          note(
            'Android speech service opens next. Offline recognition is preferred; its own network and privacy settings apply.',
          );
          final text = await DeviceTools.listen(voiceLanguage);
          if (text != null) chatInput.text = text;
        } catch (_) {
          note(
            'Voice input unavailable. Install a speech recognition service or type your message.',
          );
        }
      },
    ),
    TextField(
      controller: chatInput,
      maxLength: 2000,
      minLines: 1,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Tell me what’s happening…',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => sendChat(),
    ),
    FilledButton(
      onPressed: busy ? null : sendChat,
      child: const Text('Send ↗'),
    ),
  ];
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
        'OFFICIAL SOURCES. CLEAR CHOICES.',
        'All helplines',
        'Government sources and verification dates on every service card.',
      ),
      TextField(
        controller: queryInput,
        decoration: const InputDecoration(
          labelText: 'Search service or number',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => query = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
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
      DropdownButtonFormField<String>(
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
      if (filtered.isEmpty)
        Text(
          country.isEmpty
              ? 'Confirm your current country first.'
              : 'Official helpline information not yet verified.',
          style: const TextStyle(fontSize: 22),
        ),
      TextField(
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

  List<Widget> safetyPage() => [
    heading(
      'YOUR PERSONAL SAFETY SPACE',
      'My safety',
      'Contacts are stored in encrypted device storage. No account required.',
    ),
    FilledButton.icon(
      onPressed: addContact,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Add trusted contact'),
    ),
    OutlinedButton.icon(onPressed: importContact, icon: const Icon(Icons.contacts_outlined), label: const Text('Choose from phone contacts')),
    ...(safety['contacts'] as List).cast<Json>().map(
      (c) => trustedContact(c, controls: true),
    ),
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
      subtitle: const Text('Requests SMS permission when you start SOS. Uses your SIM and mobile plan; charges may apply. Only consenting contacts with SMS enabled are included. Submission does not confirm delivery.'),
      value: safety['deviceSms'] == true,
      onChanged: (v) { setState(() => safety['deviceSms'] = v); unawaited(saveSafety()); },
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
    heading(
      'ACCESSIBILITY & PRIVACY',
      'Make it yours',
      'Set your country manually. GPS alone never decides an emergency jurisdiction.',
    ),
    DropdownButtonFormField<String>(
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
              setState(() {
                country = v ?? '';
                conversation = [];
              });
              unawaited(prefs?.setString('country', country));
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
    const Text('Website & backend', style: TextStyle(fontSize: 23)),
    OutlinedButton.icon(
      icon: const Icon(Icons.download_outlined),
      label: const Text('Open website APK download page'),
      onPressed: () async {
        final base = serverInput.text.trim().replaceAll(RegExp(r'/+$'), '');
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
        hintText: 'https://your-service.onrender.com',
        border: OutlineInputBorder(),
      ),
      onChanged: (v) => unawaited(prefs?.setString('server', v.trim())),
    ),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: sync, child: const Text('Synchronize directory')),
    const SizedBox(height: 24),
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
    const Text('Privacy & limitations', style: TextStyle(fontSize: 23)),
    const Text(
      'Public-service calls, SMS, WhatsApp and email open external applications; complete each action there. Optional provider alerts notify only consenting trusted contacts you explicitly enable, with a configured private backend.\n\nLocation sharing requires consent and a private server session. Links expire after one hour. Mark Safe or Cancel removes stored positions. Sharing stops when the app leaves the foreground.\n\nCountry detection gives a coarse offline suggestion and optional Android address lookup; confirm it yourself. No medical diagnosis, guaranteed response, background tracking or automatic emergency dispatch. Online routing requires your own configured server. Government webpage checks do not certify live availability.\n\nThe model identifies intent only. Untrusted model text is never displayed as contact information.',
      style: TextStyle(height: 1.7),
    ),
    OutlinedButton(
      onPressed: active
          ? null
          : () async {
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
  ];
  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xffed6860),
      brightness: Brightness.dark,
      surface: const Color(0xff101b2d),
    );
    final scheme = light
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xffbd3c35),
            brightness: Brightness.light,
          )
        : darkScheme;
    final titles = [
      'Home',
      'SOS',
      'AI Assistant',
      'All Helplines',
      'My Safety',
      'Settings',
    ];
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Global SOS AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: light
            ? const Color(0xfff4f5f8)
            : const Color(0xff0b1221),
        inputDecorationTheme: InputDecorationTheme(filled:true, border:OutlineInputBorder(borderRadius:BorderRadius.circular(14), borderSide:BorderSide.none)),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize:const Size(48,50), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),
        appBarTheme: const AppBarTheme(centerTitle:false, elevation:0),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: contrast
                  ? (light ? Colors.black : Colors.white)
                  : scheme.outlineVariant,
            ),
          ),
        ),
        textTheme: contrast
            ? Typography.material2021().black.apply(
                bodyColor: light ? Colors.black : Colors.white,
                displayColor: light ? Colors.black : Colors.white,
              )
            : null,
      ),
      home: Builder(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.add_circle, color: Color(0xffef6b63)),
                SizedBox(width: 9),
                Text(
                  'GLOBAL SOS AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() => page = 5),
                child: Text(country.isEmpty ? 'Country' : country),
              ),
              IconButton(
                tooltip: 'Synchronize directory',
                icon: const Icon(Icons.sync),
                onPressed: sync,
              ),
              IconButton(
                tooltip: 'Settings & country',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => setState(() => page = 5),
              ),
            ],
          ),
          body: directory == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Text(status),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: scheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        '${country.isEmpty ? 'CONFIRM YOUR COUNTRY' : country}  ·  $status',
                        style: const TextStyle(fontSize: 10),
                        maxLines: 3,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 840),
                          child: ListView(
                            padding: const EdgeInsets.all(22),
                            children: switch (page) {
                              0 => home(),
                              1 => sos(),
                              2 => chat(),
                              3 => directoryPage(),
                              4 => safetyPage(),
                              _ => settings(),
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: page > 4 ? 0 : page,
            onDestinationSelected: (v) => setState(() => page = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.sos_outlined),
                label: 'SOS',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                label: 'Assistant',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                label: 'Directory',
              ),
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                label: 'My Safety',
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              children: [
                const DrawerHeader(child: Text('Global SOS AI')),
                for (var i = 0; i < titles.length; i++)
                  ListTile(
                    title: Text(titles[i]),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => page = i);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    countdownTimer?.cancel();
    unawaited(locationStream?.cancel());
    unawaited(model.dispose());
    unawaited(store.close());
    chatInput.dispose();
    queryInput.dispose();
    serverInput.dispose();
    super.dispose();
  }
}
