import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Pick a colleague to start (or resume) a direct internal chat with.
/// Returns the chat room map via [Navigator.pop].
class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() =>
      _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _opening;
  List<Map<String, dynamic>> _employees = [];

  String get _myId {
    final u = context.read<AuthProvider>().user;
    return (u['_id'] ?? u['id'] ?? '').toString();
  }

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
      final raw = await context.read<AuthProvider>().api.get('/hrm/employees/all');
      final list = raw is List
          ? raw
          : raw is Map
              ? (raw['data'] ?? raw['items'] ?? raw['employees'])
              : null;
      final rows = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      rows.removeWhere((e) => (e['_id'] ?? e['id']).toString() == _myId);
      if (!mounted) return;
      setState(() => _employees = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not load the team directory. The HR module may be disabled for your company.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(Map<String, dynamic> e) {
    final n = '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (e['Email'] ?? e['email'] ?? 'Employee').toString();
  }

  Future<void> _openChat(Map<String, dynamic> emp) async {
    final empId = (emp['_id'] ?? emp['id']).toString();
    if (empId.isEmpty || _opening != null) return;
    setState(() => _opening = empId);
    try {
      final auth = context.read<AuthProvider>();
      final myFirst =
          (auth.user['FirstName'] ?? auth.displayName).toString().split(' ').first;
      final theirFirst = _name(emp).split(' ').first;
      final names = [myFirst, theirFirst]..sort();
      final room = await auth.api.post('/chat/rooms/internal', data: {
        'name': '${names[0]} & ${names[1]}',
        'members': [
          {'id': _myId, 'type': 'employee'},
          {'id': empId, 'type': 'employee'},
        ],
      });
      if (!mounted) return;
      Navigator.pop(context, Map<String, dynamic>.from(room as Map));
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _search.isEmpty
        ? _employees
        : _employees
            .where((e) => [_name(e), e['Email'], e['Designation'], e['Department']]
                .join(' ')
                .toLowerCase()
                .contains(_search.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('New chat')),
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
                            message: 'Try a different search term.',
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _tile(visible[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> e) {
    final name = _name(e);
    final sub = [e['Designation'], e['Department'], e['Email']]
        .where((v) => (v ?? '').toString().trim().isNotEmpty)
        .map((v) => v.toString())
        .take(1)
        .join(' · ');
    final online = e['isOnline'] == true;
    final opening = _opening == (e['_id'] ?? e['id']).toString();
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: opening ? null : () => _openChat(e),
      child: Row(
        children: [
          Stack(
            children: [
              InitialsAvatar(name, size: 46),
              if (online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          opening
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.chat_bubble_outline_rounded,
                  color: context.faint, size: 20),
        ],
      ),
    );
  }
}
