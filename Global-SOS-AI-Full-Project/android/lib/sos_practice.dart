import 'dart:async';
import 'package:flutter/material.dart';

/// A local rehearsal. This widget has no access to calling or messaging APIs.
class SosPractice extends StatefulWidget {
  const SosPractice({super.key});

  @override
  State<SosPractice> createState() => _SosPracticeState();
}

class _SosPracticeState extends State<SosPractice> {
  Timer? _timer;
  int _remaining = 5;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.timer_outlined),
      title: const Text('Practice SOS'),
      content: Semantics(
        liveRegion: true,
        child: Text(
          _remaining > 0
              ? 'Practice countdown: $_remaining seconds. This rehearsal only displays a timer.'
              : 'Practice complete. A real SOS opens the dialer, where you press Call.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_remaining > 0 ? 'Cancel practice' : 'Done'),
        ),
      ],
    );
  }
}
