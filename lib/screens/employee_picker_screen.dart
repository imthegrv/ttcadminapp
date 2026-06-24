import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Reusable employee picker. Returns the selected employee map(s) via
/// [Navigator.pop] — a `List<Map<String,dynamic>>` (single-select returns a
/// one-item list, or null if cancelled).
class EmployeePickerScreen extends StatefulWidget {
  const EmployeePickerScreen({
    super.key,
    this.multiSelect = false,
    this.title = 'Select employee',
    this.preselectedIds = const {},
  });
  final bool multiSelect;
  final String title;
  final Set<String> preselectedIds;

  @override
  State<EmployeePickerScreen> createState() => _EmployeePickerScreenState();
}

class _EmployeePickerScreenState extends State<EmployeePickerScreen> {
  bool _loading = true;
  String? _error;
  String _search = '';
  List<Map<String, dynamic>> _employees = [];
  late final Set<String> _selected = {...widget.preselectedIds};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _id(Map e) => (e['_id'] ?? e['id'] ?? '').toString();
  String _name(Map e) {
    final n = '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim();
    return n.isEmpty ? (e['Email'] ?? 'Employee').toString() : n;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context.read<AuthProvider>().api.get('/hrm/employees/all');
      final list = raw is List
          ? raw
          : raw is Map
              ? (raw['data'] ?? raw['items'] ?? raw['employees'])
              : null;
      final rows = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _employees = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not load the team directory. The HR module may be disabled.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Map<String, dynamic> e) {
    final id = _id(e);
    if (widget.multiSelect) {
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
    } else {
      Navigator.pop(context, [e]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _search.isEmpty
        ? _employees
        : _employees
            .where((e) => [_name(e), e['Email'], e['Designation']]
                .join(' ')
                .toLowerCase()
                .contains(_search.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.multiSelect)
            TextButton(
              onPressed: () {
                final picked = _employees
                    .where((e) => _selected.contains(_id(e)))
                    .toList();
                Navigator.pop(context, picked);
              },
              child: Text('Done (${_selected.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search colleagues…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const ListSkeleton()
                : _error != null
                    ? StateMessage(
                        icon: Icons.badge_outlined,
                        title: 'Directory unavailable',
                        message: _error!,
                        tone: AppColors.danger,
                        onRetry: _load,
                      )
                    : visible.isEmpty
                        ? const StateMessage(
                            icon: Icons.groups_2_rounded,
                            title: 'No colleagues found',
                            message: 'Try a different search.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _tile(visible[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> e) {
    final name = _name(e);
    final selected = _selected.contains(_id(e));
    final sub = [e['Designation'], e['Email']]
        .where((v) => (v ?? '').toString().trim().isNotEmpty)
        .map((v) => v.toString())
        .take(1)
        .join(' · ');
    return AppCard(
      padding: const EdgeInsets.all(12),
      color: selected ? AppColors.brand.withValues(alpha: 0.06) : null,
      onTap: () => _toggle(e),
      child: Row(
        children: [
          InitialsAvatar(name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (widget.multiSelect)
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.brand : context.faint,
            )
          else
            Icon(Icons.chevron_right_rounded, color: context.faint),
        ],
      ),
    );
  }
}
