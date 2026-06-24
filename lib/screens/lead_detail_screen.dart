import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/contact_actions.dart';
import 'create_lead_screen.dart';
import 'employee_picker_screen.dart';

/// Lifecycle stages mirroring the backend lead model enum, in order.
const kLeadStages = [
  'New',
  'Contacted',
  'Qualified',
  'Proposal Sent',
  'Negotiating',
  'Closed-Won',
  'Closed-Lost',
];
const kLeadPriorities = ['High', 'Medium', 'Low'];
const kLeadStatuses = ['Open', 'On Hold', 'Closed'];

class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({super.key, required this.leadId, this.initial});
  final String leadId;
  final Map<String, dynamic>? initial;

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Map<String, dynamic>? _lead;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _lead = widget.initial;
    _load();
  }

  String get _id =>
      (_lead?['_id'] ?? _lead?['id'] ?? widget.leadId).toString();

  String get _name {
    final l = _lead ?? const {};
    final n = '${l['FirstName'] ?? ''} ${l['LastName'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (l['CompanyName'] ?? l['Email'] ?? 'Lead').toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context
          .read<AuthProvider>()
          .api
          .post('/crm/leads/view', data: {'LeadId': widget.leadId});
      if (!mounted) return;
      setState(() => _lead = Map<String, dynamic>.from(raw as Map));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this lead.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patch(
    Map<String, dynamic> changes, {
    required String action,
    String? notes,
    String? toast,
  }) async {
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().api.post('/crm/leads/update', data: {
        'id': _id,
        ...changes,
        'Updates': [
          {
            'Action': action,
            if (notes != null && notes.isNotEmpty) 'Notes': notes,
            'Date': DateTime.now().toIso8601String(),
            'PerformedBy': context.read<AuthProvider>().displayName,
          }
        ],
      });
      _dirty = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toast ?? action)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lead'),
          actions: [
            if (_lead != null)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CreateLeadScreen(lead: _lead)),
                  );
                  if (changed == true) {
                    _dirty = true;
                    _load();
                  }
                },
              ),
          ],
        ),
        body: _loading && _lead == null
            ? const ListSkeleton()
            : _error != null && _lead == null
                ? StateMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unavailable',
                    message: _error!,
                    tone: AppColors.danger,
                    onRetry: _load,
                  )
                : _body(),
      ),
    );
  }

  Widget _body() {
    final l = _lead ?? const {};
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _header(l),
          const SizedBox(height: 14),
          ContactActions(
            phone: (l['Phone'] ?? '').toString(),
            email: (l['Email'] ?? '').toString(),
          ),
          const SizedBox(height: 16),
          _stagePicker(l),
          const SizedBox(height: 14),
          _quickAttributes(l),
          const SizedBox(height: 14),
          _assigneeCard(l),
          const SizedBox(height: 14),
          _followUpCard(l),
          const SizedBox(height: 14),
          _requirementCard(l),
          _contactCard(l),
          const SizedBox(height: 14),
          _timeline(l),
        ],
      ),
    );
  }

  Widget _header(Map<String, dynamic> l) {
    final company = (l['CompanyName'] ?? '').toString();
    final dest =
        (l['PrefDestination'] ?? l['Destination'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppSpace.rXl),
        boxShadow: AppShadow.raised,
      ),
      child: Row(
        children: [
          InitialsAvatar(_name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                if (company.isNotEmpty || dest.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [company, dest].where((e) => e.isNotEmpty).join(' · '),
                    style: const TextStyle(color: Color(0xFFEDE4FF), fontSize: 13),
                  ),
                ],
                if ((l['LeadId'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#${l['LeadId']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagePicker(Map<String, dynamic> l) {
    final current = (l['LifecycleStage'] ?? 'New').toString();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Pipeline stage',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              if (_busy)
                const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kLeadStages.map((stage) {
              final selected = stage == current;
              final tone = stage.contains('Won')
                  ? AppColors.success
                  : stage.contains('Lost')
                      ? AppColors.danger
                      : AppColors.brand;
              return GestureDetector(
                onTap: _busy || selected
                    ? null
                    // Only LifecycleStage — PipelineStage has a different enum,
                    // sending a lifecycle value there fails server validation.
                    : () => _patch({'LifecycleStage': stage},
                        action: 'Stage moved to $stage'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? tone : context.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSpace.rPill),
                    border: Border.all(
                        color: selected ? tone : context.line),
                  ),
                  child: Text(stage,
                      style: TextStyle(
                          color: selected ? Colors.white : context.inkSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _quickAttributes(Map<String, dynamic> l) {
    return Row(
      children: [
        Expanded(
          child: _attrCard(
            'Priority',
            (l['Priority'] ?? 'Medium').toString(),
            Icons.flag_rounded,
            kLeadPriorities,
            (v) => _patch({'Priority': v}, action: 'Priority set to $v'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _attrCard(
            'Status',
            (l['Status'] ?? 'Open').toString(),
            Icons.circle_outlined,
            kLeadStatuses,
            (v) => _patch({'Status': v}, action: 'Status set to $v'),
          ),
        ),
      ],
    );
  }

  Widget _attrCard(String label, String value, IconData icon,
      List<String> options, ValueChanged<String> onPick) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: _busy
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Set $label',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      ...options.map((o) => ListTile(
                            leading: Icon(
                                o == value
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: o == value
                                    ? AppColors.brand
                                    : context.faint),
                            title: Text(o),
                            onTap: () => Navigator.pop(context, o),
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
              if (picked != null && picked != value) onPick(picked);
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.muted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.unfold_more_rounded, size: 16, color: context.faint),
            ],
          ),
          const SizedBox(height: 10),
          StatusChip(value),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _assignees(Map<String, dynamic> l) {
    final a = l['AssignedTo'];
    if (a is List) {
      return a.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Widget _assigneeCard(Map<String, dynamic> l) {
    final assignees = _assignees(l);
    final names = assignees
        .map((e) =>
            '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim().isEmpty
                ? (e['name'] ?? e['Email'] ?? 'Member').toString()
                : '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim())
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: _busy ? null : _assignLead,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (assignees.isEmpty ? context.muted : AppColors.brand)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_ind_rounded,
                color: assignees.isEmpty ? context.muted : AppColors.brand),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assigned to',
                    style: TextStyle(
                        color: context.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(names.isEmpty ? 'Unassigned — tap to assign' : names.join(', '),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: names.isEmpty ? context.muted : context.ink)),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, color: context.faint, size: 18),
        ],
      ),
    );
  }

  Future<void> _assignLead() async {
    final current = _assignees(_lead ?? const {});
    final picked = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeePickerScreen(
          multiSelect: true,
          title: 'Assign lead',
          preselectedIds:
              current.map((e) => (e['_id'] ?? e['id'] ?? '').toString()).toSet(),
        ),
      ),
    );
    if (picked == null) return;
    final assignedTo = picked
        .map((e) => {
              '_id': (e['_id'] ?? e['id'] ?? '').toString(),
              'FirstName': e['FirstName'] ?? '',
              'LastName': e['LastName'] ?? '',
              'Email': e['Email'] ?? e['email'] ?? '',
            })
        .toList();
    final names = picked
        .map((e) => '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    await _patch(
      {'AssignedTo': assignedTo},
      action: names.isEmpty ? 'Lead unassigned' : 'Assigned to $names',
    );
  }

  Widget _followUpCard(Map<String, dynamic> l) {
    final follow = l['FollowUp'] is Map ? l['FollowUp'] as Map : const {};
    final due = DateTime.tryParse((follow['DueDate'] ?? '').toString())?.toLocal();
    final notes = (follow['Notes'] ?? '').toString();
    final hasFollowUp = due != null;

    Color tone = AppColors.info;
    String label = 'Upcoming';
    if (due != null) {
      final today = DateTime.now();
      final startToday = DateTime(today.year, today.month, today.day);
      final endToday = startToday.add(const Duration(days: 1));
      if (due.isBefore(startToday)) {
        tone = AppColors.danger;
        label = 'Overdue';
      } else if (due.isBefore(endToday)) {
        tone = AppColors.warning;
        label = 'Due today';
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 18, color: hasFollowUp ? tone : context.muted),
              const SizedBox(width: 8),
              const Text('Follow-up',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              if (hasFollowUp)
                TextButton(
                  onPressed: _busy ? null : _clearFollowUp,
                  child: const Text('Clear'),
                ),
              TextButton.icon(
                onPressed: _busy ? null : _setFollowUp,
                icon: Icon(hasFollowUp ? Icons.edit_calendar_rounded
                    : Icons.add_alarm_rounded, size: 18),
                label: Text(hasFollowUp ? 'Reschedule' : 'Set'),
              ),
            ],
          ),
          if (!hasFollowUp)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'No follow-up set. Schedule one to get a reminder when it’s due.',
                  style: TextStyle(color: context.muted, fontSize: 13)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.event_rounded, color: tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(Fmt.dateTime(due),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppSpace.rPill),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      color: tone,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        Text(Fmt.relative(due),
                            style:
                                TextStyle(color: context.muted, fontSize: 12.5)),
                        if (notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(notes,
                                style: TextStyle(
                                    color: context.inkSoft, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setFollowUp() async {
    final l = _lead ?? const {};
    final existing =
        DateTime.tryParse(((l['FollowUp'] is Map ? l['FollowUp']['DueDate'] : null) ?? '')
            .toString())
            ?.toLocal();
    final initial = existing ?? DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final due =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final assignee = context.read<AuthProvider>().displayName;

    final notesC = TextEditingController(
        text: (l['FollowUp'] is Map ? l['FollowUp']['Notes'] : '')?.toString() ?? '');
    final notes = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Follow-up · ${Fmt.dateTime(due)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            TextField(
              controller: notesC,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'What is the follow-up about? (optional)'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, notesC.text.trim()),
                icon: const Icon(Icons.alarm_on_rounded, size: 18),
                label: const Text('Set reminder'),
              ),
            ),
          ],
        ),
      ),
    );
    if (notes == null) return; // cancelled

    await _patch(
      {
        'FollowUp': {
          'DueDate': due.toUtc().toIso8601String(),
          'Notes': notes,
          'AssignedTo': assignee,
        }
      },
      action: 'Follow-up set for ${Fmt.dateTime(due)}',
      notes: notes.isEmpty ? null : notes,
      toast: 'Follow-up scheduled',
    );
    await ReminderService.instance.scheduleLeadFollowUp(
      leadId: _id,
      leadName: _name,
      dueAt: due,
      notes: notes,
    );
  }

  Future<void> _clearFollowUp() async {
    await _patch(
      {'FollowUp': {}},
      action: 'Follow-up cleared',
      toast: 'Follow-up cleared',
    );
    await ReminderService.instance.cancelLeadFollowUp(_id);
  }

  Widget _requirementCard(Map<String, dynamic> l) {
    String budget() {
      final b = l['Budget'] is Map ? l['Budget'] as Map : const {};
      final min = b['Min'];
      final max = b['Max'];
      final cur = (b['Currency'] ?? 'INR').toString();
      if (min == null && max == null) return '';
      if (min != null && max != null) {
        return '${Fmt.money(min, cur)} – ${Fmt.money(max, cur)}';
      }
      return Fmt.money(min ?? max, cur);
    }

    String travellers() {
      final t = l['Travelers'] is Map ? l['Travelers'] as Map : const {};
      final parts = <String>[];
      int n(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
      if (n(t['Adults']) > 0) parts.add('${n(t['Adults'])} adult${n(t['Adults']) == 1 ? '' : 's'}');
      if (n(t['Children']) > 0) parts.add('${n(t['Children'])} child${n(t['Children']) == 1 ? '' : 'ren'}');
      if (n(t['Infants']) > 0) parts.add('${n(t['Infants'])} infant${n(t['Infants']) == 1 ? '' : 's'}');
      return parts.join(', ');
    }

    String travelDates() {
      final td = l['TravelDates'] is Map ? l['TravelDates'] as Map : const {};
      final start = Fmt.date(td['StartDate']);
      final nights = td['Nights'];
      if (start.isEmpty && nights == null) return '';
      return [
        if (start.isNotEmpty) start,
        if (nights != null && nights != 0) '${nights}N',
      ].join(' · ');
    }

    final months = (l['PrefMonth'] is List)
        ? (l['PrefMonth'] as List).where((e) => '$e'.trim().isNotEmpty).join(', ')
        : (l['PrefMonth'] ?? '').toString();
    final tags = (l['Tags'] is List)
        ? (l['Tags'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final score = l['LeadScore'];
    final desc = (l['Description'] ?? '').toString().trim();
    final shortTitle = (l['ShortTitle'] ?? '').toString().trim();

    final rows = <(IconData, String, String)>[
      (Icons.flight_takeoff_rounded, 'Destination',
          (l['PrefDestination'] ?? l['Destination'] ?? '').toString()),
      (Icons.account_balance_wallet_outlined, 'Budget', budget()),
      (Icons.groups_outlined, 'Travellers', travellers()),
      (Icons.event_outlined, 'Travel dates', travelDates()),
      (Icons.calendar_month_outlined, 'Preferred month', months),
      (Icons.label_outline_rounded, 'Reference', shortTitle),
    ].where((r) => r.$3.trim().isNotEmpty).toList();

    // Hide the card entirely if there's nothing meaningful to show.
    if (rows.isEmpty && desc.isEmpty && tags.isEmpty && (score == null || score == 0)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Trip & requirements',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                if (score != null && score != 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpace.rPill),
                    ),
                    child: Text('Score $score',
                        style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.$1, size: 18, color: context.muted),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: Text(r.$2,
                            style: TextStyle(
                                color: context.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(r.$3,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes / requirement',
                  style: TextStyle(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(desc,
                  style: const TextStyle(fontSize: 14, height: 1.45)),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppSpace.rPill),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.inkSoft)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactCard(Map<String, dynamic> l) {
    final rows = <(IconData, String, String)>[
      (Icons.email_outlined, 'Email', (l['Email'] ?? '').toString()),
      (Icons.phone_outlined, 'Phone', (l['Phone'] ?? '').toString()),
      (
        Icons.place_outlined,
        'Destination',
        (l['PrefDestination'] ?? l['Destination'] ?? '').toString()
      ),
      (Icons.source_outlined, 'Source', (l['LeadSource'] ?? l['Source'] ?? '').toString()),
    ].where((r) => r.$3.trim().isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(r.$1, size: 18, color: context.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$2,
                              style: TextStyle(
                                  color: context.muted, fontSize: 11.5)),
                          const SizedBox(height: 1),
                          Text(r.$3,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      color: context.faint,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: r.$3));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${r.$2} copied')),
                        );
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _timeline(Map<String, dynamic> l) {
    final updates = (l['Updates'] is List)
        ? List<Map<String, dynamic>>.from(
            (l['Updates'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
        : <Map<String, dynamic>>[];
    updates.sort((a, b) => (b['Date'] ?? '').toString().compareTo((a['Date'] ?? '').toString()));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Activity',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _logActivity,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Log'),
              ),
            ],
          ),
          if (updates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No activity logged yet.',
                  style: TextStyle(color: context.muted, fontSize: 13)),
            )
          else
            ...updates.take(20).toList().asMap().entries.map((entry) {
              final u = entry.value;
              final last = entry.key == updates.take(20).length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: AppColors.brand, shape: BoxShape.circle),
                        ),
                        if (!last)
                          Expanded(
                              child: Container(
                                  width: 2, color: context.line)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((u['Action'] ?? 'Update').toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13.5)),
                            if ((u['Notes'] ?? '').toString().trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(u['Notes'].toString(),
                                    style: TextStyle(
                                        color: context.inkSoft, fontSize: 13)),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                Fmt.relative(u['Date']),
                                if ((u['PerformedBy'] ?? '').toString().isNotEmpty)
                                  u['PerformedBy'].toString(),
                              ].where((e) => e.isNotEmpty).join(' · '),
                              style:
                                  TextStyle(color: context.faint, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _logActivity() async {
    final controller = TextEditingController();
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log activity',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'e.g. Called the client about the Bali quote…'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Save note'),
              ),
            ),
          ],
        ),
      ),
    );
    if (note != null && note.isNotEmpty) {
      await _patch({}, action: 'Note added', notes: note, toast: 'Activity logged');
    }
  }
}
