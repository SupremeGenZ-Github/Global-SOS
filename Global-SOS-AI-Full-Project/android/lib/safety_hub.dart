import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'device_tools.dart';
import 'services.dart';

class SafetyHub extends StatefulWidget {
  const SafetyHub({
    super.key,
    required this.api,
    required this.contacts,
    required this.quiet,
    required this.inbox,
    required this.onInbox,
  });
  final Api api;
  final List<Json> contacts;
  final bool quiet;
  final Json? inbox;
  final Future<void> Function(Json?) onInbox;

  @override
  State<SafetyHub> createState() => _SafetyHubState();
}

class _SafetyHubState extends State<SafetyHub> {
  final invite = TextEditingController();
  final minutes = TextEditingController(text: '15');
  List<Json> alerts = [], checkins = [];
  Position? fix;
  bool includeFix = false, lastKnown = false, busy = false;
  String status = '';

  String? get keyToken => widget.inbox?['access_token'] as String?;
  String get location => fix == null
      ? ''
      : '${lastKnown || DateTime.now().difference(fix!.timestamp).inMinutes >= 2 ? 'Last known location' : 'Location'}'
            ' from ${fix!.timestamp.toUtc().toIso8601String()} '
            '(${fix!.accuracy.round()} m accuracy): https://maps.google.com/?q=${fix!.latitude},${fix!.longitude}';
  String get message =>
      (widget.quiet
          ? 'Please check in with me when you can.'
          : 'I need help. Please contact me.') +
      (includeFix && fix != null ? ' $location' : '');

  String requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Json> call(String path, {String method = 'GET', Json? body}) => widget
      .api
      .call('/safety$path', method: method, body: body, capability: keyToken);

  Future<void> perform(Future<String> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      status = '';
    });
    try {
      final result = await action();
      if (mounted) setState(() => status = result);
    } catch (error) {
      if (mounted) setState(() => status = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String> refresh() async {
    final data = await call('/inbox');
    if (mounted) {
      setState(() {
        alerts = (data['alerts'] as List).cast<Json>();
        checkins = (data['checkins'] as List).cast<Json>();
      });
    }
    return 'Inbox updated.';
  }

  Future<String> locate() async {
    if (fix != null) setState(() => lastKnown = true);
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on device location to get a fresh fix.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return 'Location access is unavailable. You can share a message without it.';
    }
    final result = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 12),
      ),
    );
    if (mounted) {
      setState(() {
        fix = result;
        lastKnown = false;
      });
    }
    return 'Location captured. Choose whether to include it.';
  }

  Future<String> compose(Json contact, bool whatsapp) async {
    final phone = (contact['phone'] ?? '').toString().replaceAll(
      RegExp(r'[^+0-9]'),
      '',
    );
    if (whatsapp && !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone)) {
      return 'Save this contact with a country code for WhatsApp.';
    }
    final uri = whatsapp
        ? Uri.https('wa.me', '/${phone.substring(1)}', {'text': message})
        : Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    return await launchUrl(uri, mode: LaunchMode.externalApplication)
        ? 'Composer opened. Check the recipient and press Send.'
        : 'Could not open the composer.';
  }

  @override
  void dispose() {
    invite.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      Text('Safety tools', style: Theme.of(context).textTheme.titleLarge),
      OutlinedButton(
        onPressed: busy ? null : () => perform(locate),
        child: const Text('Get current location'),
      ),
      if (fix != null) ...[
        SelectableText(location),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: includeFix,
          onChanged: (value) => setState(() => includeFix = value ?? false),
          title: const Text('Include this location when I share'),
        ),
      ],
      ...widget.contacts
          .where((c) => (c['phone'] ?? '').toString().isNotEmpty)
          .map(
            (c) => Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => perform(() => compose(c, false)),
                  child: Text('SMS · ${c['name']}'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => perform(() => compose(c, true)),
                  child: Text('WhatsApp · ${c['name']}'),
                ),
              ],
            ),
          ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => perform(() async {
                await DeviceTools.shareText(message);
                return 'Share sheet opened.';
              }),
        child: const Text('Share to another app'),
      ),
      const Divider(),
      Text('Private app inbox', style: Theme.of(context).textTheme.titleMedium),
      const Text(
        'Share only your invite with trusted people. Check here for incoming alerts.',
      ),
      if (keyToken == null)
        FilledButton(
          onPressed: busy
              ? null
              : () => perform(() async {
                  final data = await call('/inbox', method: 'POST');
                  await widget.onInbox(data);
                  return 'Inbox created.';
                }),
          child: const Text('Create private inbox'),
        )
      else ...[
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => perform(refresh),
              child: const Text('Refresh inbox'),
            ),
            OutlinedButton(
              onPressed: () => perform(() async {
                await Clipboard.setData(
                  ClipboardData(text: widget.inbox!['invite'] as String),
                );
                return 'Invite copied.';
              }),
              child: const Text('Copy my invite'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Delete your inbox?'),
                          content: const Text(
                            'This removes its messages, invite and associated check-ins.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Keep'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted) return;
                      await perform(() async {
                        await call('/inbox', method: 'DELETE');
                        await widget.onInbox(null);
                        if (mounted) {
                          setState(() {
                            alerts = [];
                            checkins = [];
                          });
                        }
                        return 'Inbox deleted.';
                      });
                    },
              child: const Text('Delete inbox'),
            ),
          ],
        ),
        ...alerts.map(
          (a) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a['message'].toString()),
            subtitle: Text(
              '${a['created_at']} · ${a['read_at'] == null ? 'Unread' : 'Opened'}',
            ),
            trailing: a['read_at'] != null
                ? null
                : TextButton(
                    onPressed: busy
                        ? null
                        : () => perform(() async {
                            await call(
                              '/inbox/read',
                              method: 'POST',
                              body: {'id': a['id']},
                            );
                            return refresh();
                          }),
                    child: const Text('Mark opened'),
                  ),
          ),
        ),
      ],
      TextField(
        controller: invite,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Trusted contact’s inbox invite',
        ),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () => perform(() async {
                final data = await call(
                  '/alerts',
                  method: 'POST',
                  body: {
                    'invite': invite.text.trim(),
                    'message': message,
                    'request_id': requestId(),
                  },
                );
                return data['status'] == 'opened_in_app'
                    ? 'Recipient marked this alert opened.'
                    : 'Alert stored in recipient inbox.';
              }),
        child: const Text('Send in-app alert'),
      ),
      if (keyToken != null) ...[
        TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Check-in in minutes (1–1440)',
          ),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => perform(() async {
                  final duration = int.tryParse(minutes.text);
                  if (duration == null || duration < 1 || duration > 1440) {
                    return 'Enter 1–1440 minutes.';
                  }
                  await call(
                    '/checkins',
                    method: 'POST',
                    body: {
                      'invite': invite.text.trim(),
                      'minutes': duration,
                      'message':
                          'I missed a scheduled Global SOS check-in. Please contact me.',
                    },
                  );
                  await refresh();
                  return 'Check-in scheduled. A missed check-in goes to the recipient inbox while the server is running.';
                }),
          child: const Text('Schedule check-in'),
        ),
        ...checkins.map(
          (c) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${c['due_at']} · ${c['status']}'),
              if (c['status'] == 'pending')
                Wrap(
                  spacing: 8,
                  children: [
                    for (final state in ['safe', 'cancelled'])
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => perform(() async {
                                await call(
                                  '/checkins/${c['id']}',
                                  method: 'PATCH',
                                  body: {'status': state},
                                );
                                return refresh();
                              }),
                        child: Text(
                          state == 'safe' ? 'I’m safe' : 'Cancel check-in',
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
      if (busy) const LinearProgressIndicator(),
      if (status.isNotEmpty) Semantics(liveRegion: true, child: Text(status)),
    ],
  );
}
