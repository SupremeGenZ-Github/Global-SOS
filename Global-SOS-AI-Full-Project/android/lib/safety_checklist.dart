import 'package:flutter/material.dart';

const personalTasks = <String, String>{
  'country': 'Confirm my current country',
  'contacts': 'Add a trusted contact and review their details',
  'favorites': 'Save useful local services as favorites',
  'permissions': 'Review location and sharing permissions',
  'offline': 'Check that my offline directory is available',
  'battery': 'Check my phone battery and charging options',
};

class SafetyChecklist extends StatelessWidget {
  const SafetyChecklist({
    super.key,
    required this.checked,
    required this.onChanged,
  });
  final Map<String, dynamic> checked;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Personal readiness checklist',
        style: TextStyle(fontSize: 22),
      ),
      Text(
        '${personalTasks.keys.where((k) => checked[k] == true).length} of ${personalTasks.length} self-marked tasks. Personal reminders, not a safety assessment.',
      ),
      ...personalTasks.entries.map(
        (t) => CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.value),
          value: checked[t.key] == true,
          onChanged: (v) => onChanged({...checked, t.key: v == true}),
        ),
      ),
      TextButton(
        onPressed: () => onChanged({}),
        child: const Text('Reset checklist'),
      ),
    ],
  );
}
