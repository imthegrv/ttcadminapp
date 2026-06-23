import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'lead_detail_screen.dart';

class FollowUpsScreen extends StatefulWidget {
  const FollowUpsScreen({super.key, this.initialFilter = 'all'});
  final String initialFilter;

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  late String _filter = widget.initialFilter;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  static const _filters = ['all', 'overdue', 'today', 'upcoming'];

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
      final raw = await context
          .read<AuthProvider>()
          .api
          .get('/crm/leads/followups', query: {'status': 'all'});
      final rows = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _items = rows);
      // Re-arm on-device reminders for everything still upcoming.
      ReminderService.instance.syncFromFollowUps(rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load follow-ups.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _count(String status) => status == 'all'
      ? _items.length
      : _items.where((e) => e['followUpStatus'] == status).length;

  List<Map<String, dynamic>> get _visible => _filter == 'all'
      ? _items
      : _items.where((e) => e['followUpStatus'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.canvas,
              title: const Text('Follow-ups'),
              actions: [
                IconButton(
                    onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 6),
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.event_available_rounded,
                  title: _filter == 'all'
                      ? 'No follow-ups scheduled'
                      : 'Nothing ${_filter == 'upcoming' ? 'coming up' : _filter}',
                  message:
                      'Set a follow-up date on a lead to see it tracked here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
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

  Widget _filterBar() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: _filters.map((f) {
          final selected = f == _filter;
          final tone = _toneFor(f);
          final count = _count(f);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? tone : context.surface,
                  borderRadius: BorderRadius.circular(AppSpace.rPill),
                  border:
                      Border.all(color: selected ? tone : context.line),
                ),
                child: Row(
                  children: [
                    Text(_label(f),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected ? Colors.white : context.inkSoft)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : tone.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppSpace.rPill),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : tone)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(String f) =>
      {'all': 'All', 'overdue': 'Overdue', 'today': 'Today', 'upcoming': 'Upcoming'}[f]!;
  Color _toneFor(String f) => switch (f) {
        'overdue' => AppColors.danger,
        'today' => AppColors.warning,
        'upcoming' => AppColors.info,
        _ => AppColors.brand,
      };

  Widget _card(Map<String, dynamic> lead) {
    final name =
        '${lead['FirstName'] ?? ''} ${lead['LastName'] ?? ''}'.trim();
    final display = name.isEmpty
        ? (lead['CompanyName'] ?? lead['Email'] ?? 'Lead').toString()
        : name;
    final follow = lead['FollowUp'] is Map ? lead['FollowUp'] as Map : const {};
    final due = follow['DueDate'];
    final notes = (follow['Notes'] ?? '').toString();
    final status = (lead['followUpStatus'] ?? 'upcoming').toString();
    final tone = _toneFor(status);

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        final id = (lead['_id'] ?? lead['id'] ?? lead['LeadId'] ?? '').toString();
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LeadDetailScreen(leadId: id, initial:
                  Map<String, dynamic>.from(lead))),
        );
        _load();
      },
      child: Row(
        children: [
          InitialsAvatar(display, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: tone),
                    const SizedBox(width: 5),
                    Text(Fmt.dateTime(due),
                        style: TextStyle(
                            color: tone,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpace.rPill),
            ),
            child: Text(_label(status == 'all' ? 'all' : status),
                style: TextStyle(
                    color: tone, fontWeight: FontWeight.w700, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
