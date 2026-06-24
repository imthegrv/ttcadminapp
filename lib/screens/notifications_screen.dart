import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_center.dart';
import '../services/deep_link_router.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static (IconData, Color) _visuals(String type) => switch (type) {
        'lead' => (Icons.campaign_rounded, AppColors.warning),
        'booking' => (Icons.event_available_rounded, AppColors.success),
        'customer' => (Icons.person_add_alt_1_rounded, AppColors.brand),
        'task' => (Icons.task_alt_rounded, AppColors.info),
        'cancel' => (Icons.event_busy_rounded, AppColors.danger),
        'invoice' => (Icons.receipt_long_rounded, AppColors.success),
        'meeting' => (Icons.event_rounded, AppColors.accent),
        _ => (Icons.notifications_rounded, AppColors.info),
      };

  String _dayGroup(dynamic createdAt) {
    final d = DateTime.tryParse('${createdAt ?? ''}')?.toLocal();
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final center = context.watch<NotificationCenter>();
    final items = center.items;

    // Build a flat list with day-group headers.
    final rows = <Widget>[];
    String? lastGroup;
    for (final n in items) {
      final g = _dayGroup(n['createdAt']);
      if (g != lastGroup) {
        lastGroup = g;
        rows.add(_GroupHeader(g));
      }
      rows.add(_NotificationTile(n));
    }

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: center.refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.canvas,
              title: const Text('Notifications'),
              actions: [
                if (center.unread > 0)
                  TextButton(
                    onPressed: center.markAllRead,
                    child: const Text('Mark all read'),
                  ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: center.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            if (center.loading && items.isEmpty)
              const SliverToBoxAdapter(child: ListSkeleton())
            else if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      'New leads, bookings and customer activity will show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(delegate: SliverChildListDelegate(rows)),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: context.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n);
  final Map<String, dynamic> n;

  @override
  Widget build(BuildContext context) {
    final center = context.read<NotificationCenter>();
    final type = (n['type'] ?? 'system').toString();
    final (icon, tone) = NotificationsScreen._visuals(type);
    final read = center.isRead(n);
    final title = (n['title'] ?? 'Notification').toString();
    final message = (n['message'] ?? '').toString();
    final link = (n['link'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(13),
        color: read ? null : tone.withValues(alpha: 0.05),
        onTap: () {
          center.markRead(n);
          if (link.isNotEmpty || type.isNotEmpty) {
            DeepLinkRouter.handle({'type': type, 'link': link});
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tone, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight:
                                    read ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 14.5,
                                color: context.ink)),
                      ),
                      const SizedBox(width: 8),
                      Text(Fmt.relative(n['createdAt']),
                          style:
                              TextStyle(color: context.faint, fontSize: 11.5)),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.inkSoft, fontSize: 13, height: 1.35)),
                  ],
                ],
              ),
            ),
            if (!read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
