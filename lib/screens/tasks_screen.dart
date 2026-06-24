import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/form_kit.dart';
import 'employee_picker_screen.dart';

const _kStatuses = ['Pending', 'In Progress', 'Completed', 'Archived'];
const _kPriorities = ['Low', 'Medium', 'High', 'Urgent'];

Color _priorityTone(String p) => switch (p) {
      'Urgent' => AppColors.danger,
      'High' => AppColors.warning,
      'Low' => AppColors.muted,
      _ => AppColors.info,
    };

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _loading = true;
  String? _error;
  String _filter = 'Active';
  List<Map<String, dynamic>> _tasks = [];

  static const _filters = ['Active', 'Pending', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context.read<AuthProvider>().api.get('/todo');
      final list = raw is List
          ? raw
          : raw is Map
              ? (raw['data'] ?? raw['results'] ?? raw['tasks'])
              : null;
      if (!mounted) return;
      setState(() => _tasks = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : []);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load tasks.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == 'Active') {
      return _tasks
          .where((t) => t['status'] != 'Completed' && t['status'] != 'Archived')
          .toList();
    }
    return _tasks.where((t) => t['status'] == _filter).toList();
  }

  List<String> _assigneeIds(Map<String, dynamic> t) {
    final a = t['assignees'];
    if (a is List) {
      return a
          .map((e) => e is Map ? (e['_id'] ?? e['id'] ?? '').toString() : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final single = t['assignee'];
    if (single is Map) return [(single['_id'] ?? single['id'] ?? '').toString()];
    if (single != null) return [single.toString()];
    return [];
  }

  Future<void> _setStatus(Map<String, dynamic> t, String status) async {
    final id = (t['_id'] ?? '').toString();
    setState(() => t['status'] = status);
    try {
      await context.read<AuthProvider>().api.put('/todo/$id', data: {
        'title': t['title'],
        'description': t['description'] ?? '',
        'priority': t['priority'] ?? 'Medium',
        'status': status,
        if (t['dueDate'] != null) 'dueDate': t['dueDate'],
        'assignees': _assigneeIds(t),
      });
    } catch (e) {
      // Backend only lets the task creator edit → surface that.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Only the task creator can change its status.')));
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const TaskEditorScreen()));
          if (created == true) _load();
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New task'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.canvas,
              title: const Text('Tasks'),
              actions: [
                IconButton(
                    onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(child: _filterBar()),
            if (_loading)
              const SliverToBoxAdapter(child: ListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Unavailable',
                  message: _error!,
                  tone: AppColors.danger,
                  onRetry: _load,
                ),
              )
            else if (_visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.task_alt_rounded,
                  title: 'No tasks here',
                  message: 'Create a task to assign work to your team.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList.separated(
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(_visible[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: _filters.map((f) {
            final selected = f == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.brand : context.surface,
                    borderRadius: BorderRadius.circular(AppSpace.rPill),
                    border: Border.all(
                        color: selected ? AppColors.brand : context.line),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected ? Colors.white : context.inkSoft)),
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _card(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'Pending').toString();
    final priority = (t['priority'] ?? 'Medium').toString();
    final done = status == 'Completed';
    final assignees = t['assignees'] is List
        ? (t['assignees'] as List).whereType<Map>().toList()
        : <Map>[];
    final names = assignees
        .map((e) => '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return AppCard(
      onTap: () => _statusSheet(t),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _setStatus(t, done ? 'Pending' : 'Completed'),
            child: Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: done ? AppColors.success : context.faint,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((t['title'] ?? 'Task').toString(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? context.muted : context.ink)),
                if ((t['description'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(t['description'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(status, dense: true),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _priorityTone(priority).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpace.rPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_rounded,
                              size: 11, color: _priorityTone(priority)),
                          const SizedBox(width: 4),
                          Text(priority,
                              style: TextStyle(
                                  color: _priorityTone(priority),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    if (t['dueDate'] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_rounded,
                              size: 12, color: context.muted),
                          const SizedBox(width: 3),
                          Text(Fmt.date(t['dueDate']),
                              style: TextStyle(
                                  color: context.muted, fontSize: 11.5)),
                        ],
                      ),
                    if (names.isNotEmpty)
                      Text('→ ${names.join(', ')}',
                          style: TextStyle(
                              color: context.faint,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _statusSheet(Map<String, dynamic> t) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text((t['title'] ?? 'Task').toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ..._kStatuses.map((s) => ListTile(
                  leading: Icon(
                      s == t['status']
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: s == t['status'] ? AppColors.brand : context.faint),
                  title: Text(s),
                  onTap: () => Navigator.pop(context, s),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != t['status']) _setStatus(t, picked);
  }
}

/// ---------------------------------------------------------------------------
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key});
  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _priority = 'Medium';
  String _status = 'Pending';
  DateTime? _due;
  List<Map<String, dynamic>> _assignees = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default-assign to the current user.
    final u = context.read<AuthProvider>().user;
    final id = (u['_id'] ?? u['id'] ?? '').toString();
    if (id.isNotEmpty) {
      _assignees = [
        {'_id': id, 'FirstName': u['FirstName'] ?? '', 'LastName': u['LastName'] ?? ''}
      ];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New task')),
      bottomNavigationBar: SubmitBar(
        label: 'Create task',
        icon: Icons.add_task_rounded,
        saving: _saving,
        onPressed: _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _kPriorities
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _kStatuses
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'Pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_rounded),
              title: const Text('Due date'),
              subtitle: Text(_due == null ? 'Not set' : Fmt.date(_due)),
              trailing: _due == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due ?? DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _due = d);
              },
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_alt_rounded),
              title: const Text('Assignees'),
              subtitle: Text(_assignees.isEmpty
                  ? 'Tap to assign'
                  : _assignees
                      .map((e) =>
                          '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim())
                      .where((s) => s.isNotEmpty)
                      .join(', ')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await Navigator.push<List<Map<String, dynamic>>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeePickerScreen(
                      multiSelect: true,
                      title: 'Assign to',
                      preselectedIds: _assignees
                          .map((e) => (e['_id'] ?? e['id'] ?? '').toString())
                          .toSet(),
                    ),
                  ),
                );
                if (picked != null) setState(() => _assignees = picked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A task title is required.')));
      return;
    }
    final ids = _assignees
        .map((e) => (e['_id'] ?? e['id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assign the task to at least one person.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().api.post('/todo', data: {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'priority': _priority,
        'status': _status,
        if (_due != null) 'dueDate': _due!.toUtc().toIso8601String(),
        'assignees': ids,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create task: $e')));
      }
    }
  }
}
