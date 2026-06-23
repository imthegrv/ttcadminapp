import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class MeetingManagementScreen extends StatefulWidget {
  const MeetingManagementScreen({super.key});

  @override
  State<MeetingManagementScreen> createState() => _MeetingManagementScreenState();
}

class _MeetingManagementScreenState extends State<MeetingManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _meetings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await context.read<AuthProvider>().api.get('/crm/meetings/list');
      final rows = response is Map ? response['meetings'] : response;
      if (mounted) {
        final list = rows is List
            ? rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        setState(() => _meetings = list);
        // Re-arm on-device reminders for upcoming meetings.
        ReminderService.instance.syncFromMeetings(list);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meetings')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New meeting'),
        ),
        body: _loading
            ? const ListSkeleton()
            : RefreshIndicator(
                color: AppColors.brand,
                onRefresh: _load,
                child: _meetings.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          StateMessage(
                            icon: Icons.event_available_rounded,
                            title: 'No meetings scheduled',
                            message:
                                'Tap “New meeting” to add one to the calendar.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _meetings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _meetingCard(_meetings[index]),
                      ),
              ),
      );

  Widget _meetingCard(Map<String, dynamic> meeting) {
    final type = (meeting['meetingType'] ?? 'call').toString();
    final status = (meeting['status'] ?? 'scheduled').toString();
    final icon = switch (type) {
      'video' => Icons.videocam_rounded,
      'in-person' => Icons.people_alt_rounded,
      'follow-up' => Icons.replay_rounded,
      _ => Icons.call_rounded,
    };
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _edit(meeting),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((meeting['title'] ?? 'Meeting').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(_format(meeting['startAt']),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                StatusChip(status, dense: true),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, color: context.faint, size: 19),
        ],
      ),
    );
  }

  String _format(dynamic value) {
    final formatted = Fmt.dateTime(value);
    return formatted.isEmpty ? 'No date set' : formatted;
  }

  Future<void> _edit([Map<String, dynamic>? meeting]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MeetingEditorScreen(meeting: meeting)),
    );
    if (changed == true) await _load();
  }
}

class MeetingEditorScreen extends StatefulWidget {
  const MeetingEditorScreen({super.key, this.meeting});
  final Map<String, dynamic>? meeting;

  @override
  State<MeetingEditorScreen> createState() => _MeetingEditorScreenState();
}

class _MeetingEditorScreenState extends State<MeetingEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late DateTime _start;
  late DateTime _end;
  late String _type;
  late String _status;
  int _reminderMinutes = 15;
  bool _saving = false;

  static const _reminderOptions = {
    -1: 'No reminder',
    0: 'At start time',
    5: '5 minutes before',
    15: '15 minutes before',
    30: '30 minutes before',
    60: '1 hour before',
    1440: '1 day before',
  };

  @override
  void initState() {
    super.initState();
    final m = widget.meeting ?? const {};
    _title = TextEditingController(text: (m['title'] ?? '').toString());
    _description = TextEditingController(text: (m['description'] ?? '').toString());
    _location = TextEditingController(text: (m['location'] ?? '').toString());
    _start = DateTime.tryParse((m['startAt'] ?? '').toString())?.toLocal() ??
        DateTime.now().add(const Duration(minutes: 30));
    _end = DateTime.tryParse((m['endAt'] ?? '').toString())?.toLocal() ??
        _start.add(const Duration(minutes: 30));
    _type = (m['meetingType'] ?? 'call').toString();
    _status = (m['status'] ?? 'scheduled').toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.meeting == null ? 'New meeting' : 'Edit meeting'),
          actions: [
            if (widget.meeting != null)
              IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 14),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 14),
            _dateTile('Starts', _start, (value) => setState(() => _start = value)),
            _dateTile('Ends', _end, (value) => setState(() => _end = value)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Meeting type'),
              items: const ['call', 'video', 'in-person', 'follow-up']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'call'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const ['scheduled', 'completed', 'cancelled']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _reminderMinutes,
              decoration: const InputDecoration(
                labelText: 'Reminder',
                prefixIcon: Icon(Icons.notifications_active_outlined),
              ),
              items: _reminderOptions.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _reminderMinutes = v ?? 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save meeting'),
              ),
            ),
          ],
        ),
      );

  Widget _dateTile(String label, DateTime value, ValueChanged<DateTime> changed) =>
      Card(
        child: ListTile(
          title: Text(label),
          subtitle: Text(Fmt.dateTime(value)),
          trailing: const Icon(Icons.schedule_rounded),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              initialDate: value,
            );
            if (date == null || !mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(value),
            );
            if (time == null) return;
            changed(DateTime(date.year, date.month, date.day, time.hour, time.minute));
          },
        ),
      );

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _toast('Please add a title for the meeting.');
      return;
    }
    if (!_end.isAfter(_start)) {
      _toast('The end time must be after the start time.');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = context.read<AuthProvider>().api;
      final payload = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _location.text.trim(),
        'meetingType': _type,
        'status': _status,
        'startAt': _start.toUtc().toIso8601String(),
        'endAt': _end.toUtc().toIso8601String(),
      };
      String meetingId = (widget.meeting?['_id'] ?? '').toString();
      if (widget.meeting == null) {
        // createMeeting responds with { success, meeting: {...} }.
        final created = await api.post('/crm/meetings/create', data: payload);
        final m = created is Map ? (created['meeting'] ?? created) : null;
        if (m is Map) {
          meetingId = (m['_id'] ?? m['id'] ?? '').toString();
        }
      } else {
        await api.post('/crm/meetings/update/${widget.meeting!['_id']}', data: payload);
      }

      // Arrange / cancel the on-device reminder.
      if (meetingId.isNotEmpty) {
        if (_status == 'scheduled' && _reminderMinutes >= 0) {
          await ReminderService.instance.scheduleMeeting(
            meetingId: meetingId,
            title: _title.text.trim(),
            startAt: _start,
            minutesBefore: _reminderMinutes,
            location: _location.text.trim(),
          );
        } else {
          await ReminderService.instance.cancelMeeting(meetingId);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final s = e.toString();
      _toast('Could not save meeting: ${s.length > 90 ? '${s.substring(0, 90)}…' : s}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = (widget.meeting!['_id'] ?? '').toString();
    try {
      await context.read<AuthProvider>().api.delete('/crm/meetings/$id');
      await ReminderService.instance.cancelMeeting(id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast('Could not delete meeting.');
    }
  }
}
