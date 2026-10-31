import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services.dart';

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
  });
  final Future<Json> Function()? directoryLoader;
  final Future<Json> Function()? safetyLoader;
  final Future<List<Json>> Function()? categoryLoader;
  @override
  State<GlobalSOS> createState() => _GlobalSOSState();
}

class _GlobalSOSState extends State<GlobalSOS> with WidgetsBindingObserver {
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
      final s = await (widget.safetyLoader?.call() ?? vault.load());
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
        serverInput.text =
            p.getString('server') ??
            const String.fromEnvironment('API_BASE_URL');
        status = 'Offline directory ready · version ${d['version']}';
      });
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
      context,
    )?.showSnackBar(SnackBar(content: Text(value)));
  }

  List<Json> get records => (directory?['records'] as List? ?? []).cast<Json>();
  Future<void> sync() async {
    if (serverInput.text.trim().isEmpty) {
      note('Set your HTTPS server URL first.');
      setState(() => page = 5);
      return;
    }
    try {
      final d = await api.call('/directory');
      await store.replace(d);
      if (mounted) setState(() => directory = d);
      note('Directory synchronized · version ${d['version']}');
    } catch (_) {
      note(
        'Server unavailable. The saved offline directory remains available.',
      );
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

  bool confirmCountry() {
    if (country.isNotEmpty) return true;
    note('Confirm your current country first.');
    setState(() => page = 5);
    return false;
  }

  void startCountdown() {
    if (!confirmCountry()) return;
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
    setState(() => active = true);
    (safety['history'] as List).insert(0, {
      'at': DateTime.now().toIso8601String(),
      'status': 'SOS started locally. No alerts sent.',
    });
    await saveSafety();
    if (serverInput.text.isNotEmpty) {
      try {
        final s = await api.call(
          '/sos',
          method: 'POST',
          body: {'country': country},
        );
        if (mounted && active) setState(() => session = s);
      } catch (_) {
        note('Local SOS active. Server session unavailable. No alerts sent.');
      }
    }
  }

  Future<void> locate() async {
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
      if (mounted) setState(() => position = pos);
      note(
        'Location captured locally. Confirm your country manually; GPS does not establish emergency jurisdiction.',
      );
    } catch (_) {
      note(
        'Unable to determine location. Manual country selection remains available.',
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
    if (state != AppLifecycleState.resumed) {
      unawaited(stopSharing());
      countdownTimer?.cancel();
      if (mounted) setState(() => countdown = null);
    }
  }

  Future<void> sendChat() async {
    final text = chatInput.text.trim();
    if (text.isEmpty || busy || !confirmCountry()) return;
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
        if (intent == 'other' && model.loaded) {
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
        if (isUrgent(text) && !selected.any((r) => (r['channels'] as List).any((c) => c['immediate'] == true))) {
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
          selected = [...immediate, ...selected.where((r) => !immediate.any((i) => i['id'] == r['id']))];
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
    if (!mounted) return;
    setState(() {
      chatMode = mode;
      conversation.add({
        'text': selected.isEmpty
            ? 'Official helpline information not yet verified for this country and category. Confirm your country. If danger is immediate, use your phone’s emergency calling screen or seek nearby help.'
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

  Future<void> addContact() async {
    final name = TextEditingController(), phone = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
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
      });
      await saveSafety();
      if (mounted) setState(() {});
    }
    name.dispose();
    phone.dispose();
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
              '${r['city'] ?? r['region'] ?? country} · ${r['jurisdiction']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cs
                  .map(
                    (c) => FilledButton.tonal(
                      onPressed: () => unawaited(open(channelUri(c))),
                      child: Text(
                        '${c['kind'].toString().toUpperCase()}  ${c['value']}',
                      ),
                    ),
                  )
                  .toList(),
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
            onPressed: () {
              if (confirmCountry()) {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Start SOS countdown?'),
                    content: const Text(
                      'This does not dispatch emergency services or send alerts automatically.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          startCountdown();
                        },
                        child: const Text('Start countdown'),
                      ),
                    ],
                  ),
                );
              }
            },
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
                  'HOLD TO ACTIVATE',
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
      'No automatic public emergency dispatch. No silent messages.',
    ),
    if (countdown != null)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Text(
                'Starting in $countdown',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 15),
              FilledButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  setState(() => countdown = null);
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
      const Text('SOS active · No alerts sent', style: TextStyle(fontSize: 24)),
      Text(
        session == null
            ? 'Local safety session only.'
            : 'Private server session available for one hour.',
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
    ...(safety['contacts'] as List).map(
      (c) => Card(
        child: ListTile(
          title: Text(c['name']),
          subtitle: const Text(
            'Review and send yourself. No delivery confirmation.',
          ),
          trailing: IconButton(
            tooltip: 'Open SMS composer',
            icon: const Icon(Icons.sms_outlined),
            onPressed: () => open(
              channelUri(
                {'kind': 'sms', 'value': c['phone']},
                message:
                    'I need help. Please contact me.${position != null ? ' My location: https://maps.google.com/?q=${position!.latitude},${position!.longitude}' : ''}${sharing ? ' Private session: $privateLink' : ''}',
              ),
            ),
          ),
        ),
      ),
    ),
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
    );
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
      ...filtered.map(helpline),
    ];
  }

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
    ...(safety['contacts'] as List).map(
      (c) => Card(
        child: ListTile(
          title: Text(c['name']),
          subtitle: Text(c['phone']),
          trailing: IconButton(
            tooltip: 'Remove contact',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => (safety['contacts'] as List).remove(c));
              unawaited(saveSafety());
            },
          ),
        ),
      ),
    ),
    const SizedBox(height: 20),
    const Text('Favorite services', style: TextStyle(fontSize: 22)),
    ...records.where((r) => favorites.contains(r['id'])).map(helpline),
    const SizedBox(height: 20),
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
    const Text('Website & backend', style: TextStyle(fontSize: 23)),
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
      'Calls, SMS, WhatsApp and email open external applications; you must complete each action. No message is silently sent.\n\nLocation sharing requires consent and a private server session. Links expire after one hour. Mark Safe or Cancel removes stored positions. Sharing stops when the app leaves the foreground.\n\nNo medical diagnosis, guaranteed response, automatic country lookup, background tracking or automatic emergency dispatch. Online routing requires your own configured server. Government webpage checks do not certify live availability.\n\nThe model identifies intent only. Untrusted model text is never displayed as contact information.',
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
      title: 'Global SOS AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: light
            ? const Color(0xfff4f5f8)
            : const Color(0xff0b1221),
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
