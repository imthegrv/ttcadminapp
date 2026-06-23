import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form_kit.dart';
import 'lead_detail_screen.dart';

/// A guided, multi-step new-lead capture flow.
class LeadWizardScreen extends StatefulWidget {
  const LeadWizardScreen({super.key});

  @override
  State<LeadWizardScreen> createState() => _LeadWizardScreenState();
}

class _LeadWizardScreenState extends State<LeadWizardScreen> {
  final _page = PageController();
  int _step = 0;
  bool _saving = false;

  // Step 1 — contact
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();

  // Step 2 — trip
  final _destination = TextEditingController();
  final _month = TextEditingController();
  final _travelers = TextEditingController(text: '2');
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  String _currency = 'INR';

  // Step 3 — qualification
  String _stage = 'New';
  String _priority = 'Medium';
  String _source = 'Direct';
  final _notes = TextEditingController();

  static const _steps = ['Contact', 'Trip', 'Qualify', 'Review'];

  // Keys MUST match the backend Lead `Source` enum; values are display labels.
  static const _sourceOptions = {
    'Direct': 'Walk-in / Phone / Direct',
    'Referral': 'Referral',
    'Website': 'Website',
    'Social Media': 'Social Media',
    'Advertisement': 'Advertisement',
  };

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _email, _phone, _company,
      _destination, _month, _travelers, _budgetMin, _budgetMax, _notes,
    ]) {
      c.dispose();
    }
    _page.dispose();
    super.dispose();
  }

  bool get _contactValid =>
      _firstName.text.trim().isNotEmpty &&
      (_email.text.trim().isNotEmpty || _phone.text.trim().isNotEmpty);

  void _next() {
    if (_step == 0 && !_contactValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('First name and an email or phone are required.')),
      );
      return;
    }
    if (_step < _steps.length - 1) {
      _page.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      _page.previousPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New lead'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
      ),
      bottomNavigationBar: SubmitBar(
        label: _step == _steps.length - 1 ? 'Create lead' : 'Continue',
        icon: _step == _steps.length - 1
            ? Icons.check_rounded
            : Icons.arrow_forward_rounded,
        saving: _saving,
        onPressed: _next,
        helper: 'Step ${_step + 1} of ${_steps.length}',
      ),
      body: Column(
        children: [
          _progress(),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _contactStep(),
                _tripStep(),
                _qualifyStep(),
                _reviewStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    decoration: BoxDecoration(
                      color: (done || active)
                          ? AppColors.brand
                          : context.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_steps[i],
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.brand
                              : done
                                  ? context.inkSoft
                                  : context.faint)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepBody(String title, String subtitle, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text(title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: context.muted, fontSize: 13.5)),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard, int maxLines = 1, IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon == null ? null : Icon(icon),
          ),
        ),
      );

  Widget _contactStep() => _stepBody(
        'Who is this lead?',
        'Capture how to reach them. Email or phone is required.',
        [
          _field(_firstName, 'First name', icon: Icons.person_outline_rounded),
          _field(_lastName, 'Last name'),
          _field(_company, 'Company (optional)',
              icon: Icons.business_outlined),
          _field(_email, 'Email',
              keyboard: TextInputType.emailAddress,
              icon: Icons.alternate_email_rounded),
          _field(_phone, 'Phone',
              keyboard: TextInputType.phone, icon: Icons.phone_outlined),
        ],
      );

  Widget _tripStep() => _stepBody(
        'Trip preferences',
        'What are they dreaming about? This helps qualify the lead.',
        [
          _field(_destination, 'Preferred destination',
              icon: Icons.place_outlined),
          _field(_month, 'Preferred month / dates',
              icon: Icons.event_outlined),
          _field(_travelers, 'Number of travellers',
              keyboard: TextInputType.number, icon: Icons.groups_outlined),
          Row(
            children: [
              Expanded(
                  child: _field(_budgetMin, 'Budget min',
                      keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_budgetMax, 'Budget max',
                      keyboard: TextInputType.number)),
            ],
          ),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(labelText: 'Budget currency'),
            items: const ['INR', 'USD', 'AED', 'EUR', 'GBP']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _currency = v ?? 'INR'),
          ),
        ],
      );

  Widget _qualifyStep() => _stepBody(
        'Qualify the lead',
        'Set the starting stage, priority and where it came from.',
        [
          const FormSection('Stage'),
          DropdownButtonFormField<String>(
            value: _stage,
            decoration: const InputDecoration(labelText: 'Lifecycle stage'),
            items: kLeadStages
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _stage = v ?? 'New'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: kLeadPriorities
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _source,
            decoration: const InputDecoration(labelText: 'Lead source'),
            items: _sourceOptions.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _source = v ?? 'Direct'),
          ),
          const SizedBox(height: 18),
          _field(_notes, 'Notes / requirements', maxLines: 4),
        ],
      );

  Widget _reviewStep() {
    String full = '${_firstName.text} ${_lastName.text}'.trim();
    if (full.isEmpty) full = 'New lead';
    final rows = <(String, String)>[
      ('Name', full),
      if (_company.text.trim().isNotEmpty) ('Company', _company.text.trim()),
      if (_email.text.trim().isNotEmpty) ('Email', _email.text.trim()),
      if (_phone.text.trim().isNotEmpty) ('Phone', _phone.text.trim()),
      if (_destination.text.trim().isNotEmpty)
        ('Destination', _destination.text.trim()),
      if (_month.text.trim().isNotEmpty) ('When', _month.text.trim()),
      ('Travellers', _travelers.text.trim().isEmpty ? '—' : _travelers.text.trim()),
      if (_budgetMin.text.trim().isNotEmpty || _budgetMax.text.trim().isNotEmpty)
        ('Budget',
            '$_currency ${_budgetMin.text.trim().isEmpty ? '0' : _budgetMin.text.trim()} – ${_budgetMax.text.trim().isEmpty ? '∞' : _budgetMax.text.trim()}'),
      ('Stage', _stage),
      ('Priority', _priority),
      ('Source', _source),
    ];
    return _stepBody(
      'Review & create',
      'Confirm the details before adding this lead to the pipeline.',
      [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  InitialsAvatar(full, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(full,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 4),
                        StatusChip(_stage),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(r.$1,
                              style: TextStyle(
                                  color: context.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text(r.$2,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        if (_notes.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes',
                    style: TextStyle(
                        color: context.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_notes.text.trim(),
                    style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final budget = <String, dynamic>{'Currency': _currency};
    final min = double.tryParse(_budgetMin.text.trim());
    final max = double.tryParse(_budgetMax.text.trim());
    if (min != null) budget['Min'] = min;
    if (max != null) budget['Max'] = max;

    final travellers = int.tryParse(_travelers.text.trim());
    final payload = {
      'FirstName': _firstName.text.trim(),
      'LastName': _lastName.text.trim(),
      if (_company.text.trim().isNotEmpty) 'CompanyName': _company.text.trim(),
      'Email': _email.text.trim(),
      'Phone': _phone.text.trim(),
      'PrefDestination': _destination.text.trim(),
      // PrefMonth is a String array on the backend.
      if (_month.text.trim().isNotEmpty) 'PrefMonth': [_month.text.trim()],
      // Travelers is an object { Adults, Children, Infants } (Adults >= 1).
      if (travellers != null && travellers > 0)
        'Travelers': {'Adults': travellers, 'Children': 0, 'Infants': 0},
      if (budget.length > 1) 'Budget': budget,
      'Description': _notes.text.trim(),
      'LifecycleStage': _stage,
      'Priority': _priority,
      // Source must be one of the backend enum values; keep the human label too.
      'Source': _source,
      'SourceDetails': _sourceOptions[_source] ?? _source,
      'LeadSource': 'TripClub Operations App',
    };

    try {
      final result = await context
          .read<AuthProvider>()
          .api
          .post('/crm/leads/AddNew', data: payload);
      if (!mounted) return;
      final created = result is Map ? Map<String, dynamic>.from(result) : null;
      final id =
          (created?['_id'] ?? created?['id'] ?? created?['LeadId'] ?? '').toString();
      if (id.isNotEmpty) {
        // Replace the wizard with the new lead's detail view.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  LeadDetailScreen(leadId: id, initial: created)),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create lead: $e')),
      );
    }
  }
}
