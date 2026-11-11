import 'package:flutter/material.dart';

class ContactEditor extends StatefulWidget {
  const ContactEditor({super.key});
  @override
  State<ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<ContactEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();

  void save() {
    if (!(form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name.text.trim(), 'phone': phone.text.trim(), 'email': email.text.trim(),
      'alertConsent': false, 'methods': <String>[],
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add someone you trust'), scrollable: true,
    content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Save their number first. You can choose alert permissions and contact methods afterwards.'),
      const SizedBox(height: 20),
      TextFormField(controller: name, maxLength: 100, textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Name'),
        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Enter a contact name.' : null),
      const SizedBox(height: 12),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Phone with country code', hintText: '+91 …'),
        validator: (value) => RegExp(r'^\+?[0-9 ()-]{3,25}$').hasMatch(value?.trim() ?? '') &&
          (value ?? '').replaceAll(RegExp(r'\D'), '').length >= 3 ? null : 'Enter a valid phone number.'),
      const SizedBox(height: 16),
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Email (optional)'), onFieldSubmitted: (_) => save(),
        validator: (value) => value == null || value.trim().isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
          ? null : 'Check the email address.'),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: save, child: const Text('Save contact'))],
  );

  @override
  void dispose() { name.dispose(); phone.dispose(); email.dispose(); super.dispose(); }
}
