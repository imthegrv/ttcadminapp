import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

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
      final raw =
          await context.read<AuthProvider>().api.get('/crm/leads/dashboard');
      if (!mounted) return;
      setState(() => _data = raw is Map ? Map<String, dynamic>.from(raw) : {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load analytics.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals =
        _data['totals'] is Map ? Map<String, dynamic>.from(_data['totals']) : {};
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.canvas,
              title: const Text('Lead analytics'),
              actions: [
                IconButton(
                    onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 4),
              ],
            ),
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
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _kpis(totals),
                    const SizedBox(height: 22),
                    _breakdown('Lifecycle stage', _data['lifecycle'], 'stage'),
                    _breakdown('Pipeline stage', _data['pipeline'], 'stage'),
                    _breakdown('Lead source', _data['source'], 'source'),
                    _breakdown('Lost reasons', _data['lostReasons'], 'reason'),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kpis(Map totals) {
    int n(String k) {
      final v = totals[k];
      return v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    }

    final cards = [
      ('Total leads', n('total'), Icons.person_search_rounded, AppColors.brand),
      ('Open', n('openLeads'), Icons.lock_open_rounded, AppColors.info),
      ('Unassigned', n('unassigned'), Icons.person_off_rounded, AppColors.warning),
      ('Overdue', n('overdueFollowUps'), Icons.warning_amber_rounded,
          AppColors.danger),
      ('Due today', n('dueToday'), Icons.today_rounded, AppColors.accent),
      ('Next 7 days', n('upcoming7Days'), Icons.date_range_rounded,
          AppColors.success),
    ];
    final avg = (totals['avgLeadScore'] ?? '0').toString();

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: cards.map((c) => _kpiCard(c.$1, c.$2, c.$3, c.$4)).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppSpace.rLg),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Average lead score',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              Text(avg,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, int value, IconData icon, Color tone) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppSpace.rLg),
        border: Border.all(color: context.line),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tone, size: 17),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Fmt.count(value),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: context.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdown(String title, dynamic raw, String labelKey) {
    final rows = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxCount = rows.fold<int>(
        1, (m, r) => (r['count'] is num && r['count'] > m) ? r['count'].toInt() : m);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            ...rows.map((r) {
              final label = (r[labelKey] ?? 'Unknown').toString();
              final count = r['count'] is num ? r['count'].toInt() : 0;
              final frac = (count / maxCount).clamp(0.04, 1.0);
              final tone = StatusPalette.tone(label);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(Fmt.humanize(label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text('$count',
                            style: TextStyle(
                                color: context.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 7,
                        backgroundColor: context.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(tone),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
