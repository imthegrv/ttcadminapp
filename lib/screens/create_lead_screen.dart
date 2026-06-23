import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';
import '../widgets/form_kit.dart';

class CreateLeadScreen extends StatefulWidget {
  const CreateLeadScreen({super.key, this.lead});
  final Map<String, dynamic>? lead;

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _destination;
  late final TextEditingController _notes;
  late String _lifecycle;
  late String _priority;
  bool _saving = false;

  bool get _editing => widget.lead != null;

  @override
  void initState() {
    super.initState();
    final lead = widget.lead ?? const {};
    String value(String key) => (lead[key] ?? '').toString();
    _firstName = TextEditingController(text: value('FirstName'));
    _lastName = TextEditingController(text: value('LastName'));
    _email = TextEditingController(text: value('Email'));
    _phone = TextEditingController(text: value('Phone'));
    _destination =
        TextEditingController(text: value('PrefDestination').isNotEmpty ? value('PrefDestination') : value('Destination'));
    _notes = TextEditingController(text: value('Description'));
    _lifecycle = value('LifecycleStage').isEmpty ? 'New' : value('LifecycleStage');
    const priorities = ['High', 'Medium', 'Low'];
    final p = value('Priority');
    _priority = priorities.contains(p) ? p : 'Medium';
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _destination, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit lead' : 'Create lead')),
        bottomNavigationBar: SubmitBar(
          label: _editing ? 'Save changes' : 'Create lead',
          icon: _editing ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
          saving: _saving,
          onPressed: _save,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              if (_editing) ...[
                Center(child: InitialsAvatar(_firstName.text, size: 64)),
                const SizedBox(height: 18),
              ],
              const FormSection('Contact details', icon: Icons.person_rounded),
              _field(_firstName, 'First name', required: true),
              _field(_lastName, 'Last name'),
              _field(_email, 'Email', keyboard: TextInputType.emailAddress),
              _field(_phone, 'Phone', keyboard: TextInputType.phone),
              _field(_destination, 'Preferred destination'),
              const SizedBox(height: 6),
              const FormSection('Pipeline', icon: Icons.timeline_rounded),
              DropdownButtonFormField<String>(
                value: _lifecycle,
                decoration: const InputDecoration(labelText: 'Lead stage'),
                items: const [
                  'New', 'Returning Customer', 'Contacted', 'Qualified',
                  'Proposal Sent', 'Negotiating', 'Closed-Won', 'Closed-Lost'
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => _lifecycle = value ?? 'New'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const ['High', 'Medium', 'Low']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setState(() => _priority = value ?? 'Medium'),
              ),
              const SizedBox(height: 14),
              _field(_notes, 'Notes', maxLines: 4),
            ],
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label,
          {bool required = false, TextInputType? keyboard, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: required
              ? (value) => (value ?? '').trim().isEmpty ? '$label is required' : null
              : null,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'FirstName': _firstName.text.trim(),
      'LastName': _lastName.text.trim(),
      'Email': _email.text.trim(),
      'Phone': _phone.text.trim(),
      'PrefDestination': _destination.text.trim(),
      'Description': _notes.text.trim(),
      'LifecycleStage': _lifecycle,
      'PipelineStage': _lifecycle,
      'Priority': _priority,
    };
    try {
      final api = context.read<AuthProvider>().api;
      if (_editing) {
        await api.post('/crm/leads/update', data: {
          'id': widget.lead!['_id'] ?? widget.lead!['id'],
          ...payload,
          'Updates': [
            {
              'Action': 'Lead updated from operations app',
              'Notes': _notes.text.trim(),
              'Date': DateTime.now().toIso8601String(),
            }
          ],
        });
      } else {
        await api.post('/crm/leads/AddNew', data: {
          ...payload,
          'LeadSource': 'TripClub Operations App',
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save lead: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
