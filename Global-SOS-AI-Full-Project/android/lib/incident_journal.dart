import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services.dart';

class IncidentJournal extends StatefulWidget {
  const IncidentJournal({super.key});
  @override
  State<IncidentJournal> createState() => _IncidentJournalState();
}

class _IncidentJournalState extends State<IncidentJournal> {
  static const channel = MethodChannel('org.globalsos/device');
  static const storageKey = 'incident_journal_v1';
  final storage = SafetyVault().secure;
  final title = TextEditingController(), notes = TextEditingController();
  List<Json> records = [], media = [];
  Json? original;
  bool ready = false, busy = false, editing = false;
  String status = '';
  final added = <String>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final saved = await storage.read(key: storageKey);
      final decoded = saved == null ? <dynamic>[] : jsonDecode(saved) as List;
      if (decoded.length > 50) {
        throw const FormatException('Too many entries');
      }
      final loaded = <Json>[];
      for (final item in decoded) {
        final row = Map<String, dynamic>.from(item as Map);
        if (row['id'] is! String || row['title'] is! String || row['notes'] is! String ||
            row['createdAt'] is! String || row['media'] is! List || (row['media'] as List).length > 10) {
          throw const FormatException('Invalid incident');
        }
        final attachments = <Json>[];
        for (final source in row['media'] as List) {
          final file = Map<String, dynamic>.from(source as Map);
          final info = await channel.invokeMapMethod<String, dynamic>('incidentInfo', {'id': file['id']});
          attachments.add({...file, 'path': info?['path'], 'missing': info == null});
        }
        row['media'] = attachments;
        loaded.add(row);
      }
      if (!mounted) {
        return;
      }
      setState(() { records = loaded; ready = true; });
      try {
        await channel.invokeMethod<void>('incidentCleanup', {'ids': loaded.expand((record) => (record['media'] as List).map((file) => file['id'])).toList()});
      } catch (_) { /* Entries remain available when stale-file cleanup fails. */ }
    } catch (_) {
      if (mounted) {
        setState(() => status = 'The journal could not be opened. Saved entries have been retained. Try again.');
      }
    }
  }

  Future<void> write(List<Json> next) async {
    await storage.write(key: storageKey, value: jsonEncode(next));
    if (mounted) {
      setState(() => records = next);
    }
  }

  Future<void> run(Future<String> Function() action) async {
    if (busy) {
      return;
    }
    setState(() { busy = true; status = ''; });
    try {
      final result = await action();
      if (mounted) {
        setState(() => status = result);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => status = error.message ?? 'Media action unavailable.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = 'The action could not be completed. Check device storage and try again.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void start(Json? record) {
    setState(() {
      original = record;
      title.text = record?['title'] as String? ?? '';
      notes.text = record?['notes'] as String? ?? '';
      media = (record?['media'] as List? ?? []).map((file) => Map<String, dynamic>.from(file as Map)).toList();
      added.clear(); editing = true; status = '';
    });
  }

  Future<String> attach({bool? video}) async {
    if (media.length >= 10) {
      return 'Use up to 10 attachments per incident.';
    }
    final file = await channel.invokeMapMethod<String, dynamic>(video == null ? 'incidentPick' : 'incidentCapture', video == null ? null : {'video': video});
    if (file == null) {
      return 'Media selection cancelled.';
    }
    final size = media.fold<int>(0, (sum, item) => sum + ((item['size'] as num?)?.toInt() ?? 0));
    if (size + (file['size'] as num).toInt() > 200 * 1024 * 1024) {
      await channel.invokeMethod<void>('incidentDelete', {'ids': [file['id']]});
      return 'Keep each incident under 200 MB.';
    }
    if (!mounted) {
      await channel.invokeMethod<void>('incidentDelete', {'ids': [file['id']]});
      return '';
    }
    setState(() { media.add(Map<String, dynamic>.from(file)); added.add(file['id'] as String); });
    return 'Attachment added to the draft. Save the incident to keep it.';
  }

  Future<String> save() async {
    if (title.text.trim().isEmpty && notes.text.trim().isEmpty && media.isEmpty) {
      return 'Add a title, notes, or an attachment.';
    }
    if (original == null && records.length >= 50) {
      return 'Export and delete an older entry before saving another (50-entry limit).';
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final next = <String, dynamic>{
      'id': original?['id'] ?? '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
      'title': title.text.trim().isEmpty ? 'Untitled incident' : title.text.trim(),
      'notes': notes.text.trim(), 'createdAt': original?['createdAt'] ?? now,
      'updatedAt': now, 'media': media,
    };
    final removed = (original?['media'] as List? ?? []).where((file) => !media.any((item) => item['id'] == file['id'])).map((file) => file['id']).toList();
    await write([next, ...records.where((record) => record['id'] != next['id'])]);
    if (mounted) {
      setState(() { editing = false; original = null; media = []; added.clear(); });
    }
    try {
      await channel.invokeMethod<void>('incidentDelete', {'ids': removed});
    } catch (_) { return 'Incident saved. Some removed files could not be cleared from app storage.'; }
    return 'Incident saved on this device.';
  }

  Future<bool> discard() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Discard this draft?'), content: const Text('Unsaved notes and attachments will be removed.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep editing')),
        TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Discard'))],
    ));
    if (confirmed != true) {
      return false;
    }
    await run(() async {
      await channel.invokeMethod<void>('incidentDelete', {'ids': added.toList()});
      if (mounted) {
        setState(() { editing = false; original = null; media = []; added.clear(); });
      }
      return 'Draft discarded.';
    });
    return !editing;
  }

  String summary(Json record) => '${record['title']}\nCreated: ${record['createdAt']}\nUpdated: ${record['updatedAt']}\n\n${record['notes']}';
  List<String> ids(Json record) => (record['media'] as List).map((file) => file['id'] as String).toList();

  Future<void> remove(Json record) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Delete this incident?'), content: const Text('Its notes and attachments will be removed from this app.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep')),
        TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete'))],
    ));
    if (confirmed != true || !mounted) {
      return;
    }
    await run(() async {
      await write(records.where((item) => item['id'] != record['id']).toList());
      try { await channel.invokeMethod<void>('incidentDelete', {'ids': ids(record)}); }
      catch (_) { return 'Entry removed. Some files could not be cleared from app storage.'; }
      return 'Incident deleted.';
    });
  }

  Widget attachment(Json file, {int? index}) => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (file['missing'] == true) const Text('Attachment is no longer available')
      else if (file['type'].toString().startsWith('image/') && file['path'] is String)
        Image.file(File(file['path'] as String), height: 180, cacheWidth: 640, fit: BoxFit.contain,
          errorBuilder: (_, error, stack) => const Text('Preview unavailable. Try opening the original.'))
      else const Padding(padding: EdgeInsets.all(18), child: Icon(Icons.movie_outlined, size: 42)),
      Text(file['name'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
      Text('${(((file['size'] as num?) ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB'),
      Wrap(children: [
        TextButton(onPressed: busy || file['missing'] == true ? null : () => run(() async {
          await channel.invokeMethod<void>('incidentView', {'id': file['id']}); return 'Opened in the selected viewer.';
        }), child: const Text('Open original')),
        if (index != null) TextButton(onPressed: busy ? null : () => run(() async {
          if (added.contains(file['id'])) {
            await channel.invokeMethod<void>('incidentDelete', {'ids': [file['id']]});
            added.remove(file['id']);
          }
          if (mounted) {
            setState(() => media.removeAt(index));
          }
          return 'Attachment removed from the draft.';
        }), child: const Text('Remove')),
      ]),
    ]),
  ));

  @override
  void dispose() { title.dispose(); notes.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !editing && !busy,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && editing && !busy) {
        await discard();
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Incident journal')),

      bottomNavigationBar: editing ? Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(top: false, child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
        child: Row(children: [
          Expanded(child: FilledButton.icon(onPressed: busy ? null : () => run(save),
            icon: const Icon(Icons.check_rounded), label: const Text('Save incident'))),
          const SizedBox(width: 10),
          IconButton(tooltip: 'Discard draft', onPressed: busy ? null : discard,
            icon: const Icon(Icons.close_rounded)),
        ]),
      ))) : null,

      body: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(18), children: [
        const Text('Photos, videos and notes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        const Text('Entries stay in this app until you export or share them. Notes use encrypted storage. Media files use the app’s private storage and are removed if you uninstall. Export anything you need to retain.'),
        const SizedBox(height: 14),
        if (!ready) OutlinedButton(onPressed: busy ? null : load, child: const Text('Retry journal storage')),
        if (ready && !editing) FilledButton.icon(onPressed: busy ? null : () => start(null), icon: const Icon(Icons.add), label: const Text('New incident')),
        if (editing) ...[
          TextField(controller: title, enabled: !busy, maxLength: 100, decoration: const InputDecoration(labelText: 'Incident title')),
          TextField(controller: notes, enabled: !busy, maxLength: 4000, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'Notes')),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: busy ? null : () => run(() => attach(video: false)), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Take photo')),
            OutlinedButton.icon(onPressed: busy ? null : () => run(() => attach(video: true)), icon: const Icon(Icons.videocam_outlined), label: const Text('Record video')),
            OutlinedButton(onPressed: busy ? null : () => run(() => attach()), child: const Text('Choose existing file')),
          ]),
          const Text('Up to 10 attachments, 100 MB per file and 200 MB per entry. Video capture requests a 60-second limit from the camera app.'),
          for (var index = 0; index < media.length; index++) attachment(media[index], index: index),

        ] else ...[
          Text('${records.length} / 50 saved incidents'),
          if (ready && records.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Start an entry to keep notes and media together.')),
          for (final record in records) Card(child: ExpansionTile(
            key: PageStorageKey('incident-${record['id']}'),
            leading: const Icon(Icons.folder_outlined), title: Text(record['title'] as String),
            subtitle: Text('${DateTime.tryParse(record['createdAt'] as String)?.toLocal() ?? record['createdAt']} · ${(record['media'] as List).length} attachments'),
            children: [Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SelectableText(record['notes'] as String),
              for (final file in record['media'] as List) attachment(Map<String, dynamic>.from(file as Map)),
              Wrap(spacing: 8, children: [
                TextButton(onPressed: busy ? null : () => start(record), child: const Text('Edit')),
                TextButton(onPressed: busy ? null : () => run(() async {
                  await channel.invokeMethod<void>('incidentShare', {'ids': ids(record), 'text': summary(record)});
                  return 'Share sheet opened. Delivery is unconfirmed.';
                }), child: const Text('Share incident')),
                TextButton(onPressed: busy ? null : () => run(() async {
                  final saved = await channel.invokeMethod<bool>('incidentExport', {'ids': ids(record), 'text': summary(record)});
                  return saved == true ? 'Incident ZIP exported.' : 'Export cancelled.';
                }), child: const Text('Export ZIP')),
                TextButton(onPressed: busy ? null : () => remove(record), child: const Text('Delete')),
              ]),
            ]))],
          )),
        ],
        if (busy) const LinearProgressIndicator(),
        Semantics(liveRegion: true, child: Text(status)),
      ]),
    ),
  );
}

