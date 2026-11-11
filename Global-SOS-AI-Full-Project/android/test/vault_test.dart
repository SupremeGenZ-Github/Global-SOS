import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_sos_ai/services.dart';

void main() {
  test('slow older saves cannot overwrite a newer edit or resurrect deleted data', () async {
    final values = <String?>[];
    final gates = <Completer<void>>[];
    final vault = SafetyVault(persist: (value) {
      values.add(value); final gate = Completer<void>(); gates.add(gate); return gate.future;
    });
    final first = vault.save({'medical': 'older notes'});
    final second = vault.save({'medical': 'newer notes'});
    final clear = vault.clear();
    await Future<void>.delayed(Duration.zero);
    expect(values, hasLength(1));
    gates[0].complete(); await first;
    await Future<void>.delayed(Duration.zero);
    expect(jsonDecode(values[1]!)['medical'], 'newer notes');
    expect(values, hasLength(2));
    gates[1].complete(); await second;
    await Future<void>.delayed(Duration.zero);
    expect(values, hasLength(3)); expect(values.last, isNull);
    gates[2].complete(); await clear;
  });
  test('a failed storage write is reported and does not block a later retry', () async {
    var attempts = 0;
    final vault = SafetyVault(persist: (_) async { if (++attempts == 1) throw StateError('Locked'); });
    await expectLater(vault.save({'contacts': []}), throwsStateError);
    await vault.save({'contacts': []});
    expect(attempts, 2);
  });
}
