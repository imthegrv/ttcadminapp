import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

typedef ResourceLoader = Future<dynamic> Function(AuthProvider auth);
typedef ResourceTap = Future<bool?> Function(Map<String, dynamic> item);

/// Generic, configurable list surface used for every read-mostly resource
/// (leads, bookings, invoices, customers, mail, visa prices, notifications).
class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.loader,
    required this.primaryFields,
    this.subtitleFields = const [],
    this.statusFields = const [],
    this.trailingFields = const [],
    this.amountField,
    this.currencyField,
    this.useInitials = false,
    this.accent,
    this.emptyMessage = 'Nothing here yet',
    this.floatingAction,
    this.onItemTap,
  });

  final String title;
  final IconData icon;
  final ResourceLoader loader;
  final List<String> primaryFields;
  final List<String> subtitleFields;

  /// Fields scanned (in order) for a status value rendered as a chip.
  final List<String> statusFields;

  /// Fields scanned for a trailing meta value (auto-formatted if it looks
  /// like a date).
  final List<String> trailingFields;

  /// When set, the trailing meta shows formatted money from this field.
  final String? amountField;
  final String? currencyField;

  /// People-like resources show gradient initials instead of an icon tile.
  final bool useInitials;
  final Color? accent;

  final String emptyMessage;
  final Widget? floatingAction;
  final ResourceTap? onItemTap;

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _search = '';

  Color get _accent => widget.accent ?? AppColors.brand;

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
      final raw = await widget.loader(context.read<AuthProvider>());
      if (!mounted) return;
      setState(() => _items = _extract(raw));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('connectionError') || text.contains('SocketException')) {
      return 'No connection. Check your network and try again.';
    }
    if (text.contains('401') || text.contains('403')) {
      return 'Your session may have expired. Sign out and back in.';
    }
    return 'Something went wrong while loading.';
  }

  List<Map<String, dynamic>> _extract(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      for (final key in const [
        'items', 'data', 'results', 'meetings', 'messages', 'notifications', 'docs', 'rows'
      ]) {
        final value = raw[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  dynamic _field(Map<String, dynamic> item, String path) {
    dynamic value = item;
    for (final part in path.split('.')) {
      if (value is! Map) return null;
      value = value[part];
    }
    return value;
  }

  String _first(Map<String, dynamic> item, List<String> fields) {
    for (final field in fields) {
      final value = _field(item, field);
      if (value != null && value.toString().trim().isNotEmpty) {
        return value is List ? value.join(', ') : value.toString();
      }
    }
    return '';
  }

  String _trailing(Map<String, dynamic> item) {
    if (widget.amountField != null) {
      final amount = _field(item, widget.amountField!);
      if (amount != null && amount.toString().trim().isNotEmpty) {
        final currency =
            (widget.currencyField != null ? _field(item, widget.currencyField!) : null)
                    ?.toString() ??
                'INR';
        return Fmt.money(amount, currency);
      }
    }
    final raw = _first(item, widget.trailingFields);
    if (raw.isEmpty) return '';
    return Fmt.looksLikeDate(raw) ? Fmt.relative(raw) : raw;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((item) {
      if (_search.isEmpty) return true;
      return item.values.join(' ').toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      floatingActionButton: widget.floatingAction,
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 116,
              backgroundColor: context.canvas,
              automaticallyImplyLeading: Navigator.canPop(context),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                expandedTitleScale: 1.6,
                title: Text(widget.title,
                    style: TextStyle(
                        color: context.ink, fontWeight: FontWeight.w800)),
              ),
              actions: [
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'Search ${widget.title.toLowerCase()}…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => setState(() => _search = ''),
                              ),
                      ),
                    ),
                    if (!_loading && _error == null && _items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Text(
                              '${visible.length} ${visible.length == 1 ? 'result' : 'results'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(child: ListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load ${widget.title.toLowerCase()}',
                  message: _error!,
                  tone: AppColors.danger,
                  onRetry: _load,
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: widget.icon,
                  title: _search.isEmpty ? widget.emptyMessage : 'No matches',
                  message: _search.isEmpty
                      ? 'Pull down to refresh and check again.'
                      : 'Try a different search term.',
                  onRetry: _search.isEmpty ? _load : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _card(visible[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final title = _first(item, widget.primaryFields);
    final subtitle = _first(item, widget.subtitleFields);
    final status = _first(item, widget.statusFields);
    final trailing = _trailing(item);
    final displayTitle = title.isEmpty ? 'Untitled record' : title;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _open(item),
      child: Row(
        children: [
          widget.useInitials
              ? InitialsAvatar(displayTitle, size: 46)
              : Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: _accent, size: 22),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  StatusChip(status, dense: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (trailing.isNotEmpty)
                Text(
                  trailing,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: context.inkSoft,
                  ),
                ),
              const SizedBox(height: 6),
              Icon(Icons.chevron_right_rounded,
                  color: context.faint, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (widget.onItemTap != null) {
      final changed = await widget.onItemTap!(item);
      if (changed == true) await _load();
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.surface,
      builder: (_) => _RecordDetails(
        item: item,
        title: _first(item, widget.primaryFields),
        status: _first(item, widget.statusFields),
        icon: widget.icon,
        useInitials: widget.useInitials,
      ),
    );
  }
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({
    required this.item,
    required this.title,
    required this.status,
    required this.icon,
    required this.useInitials,
  });
  final Map<String, dynamic> item;
  final String title;
  final String status;
  final IconData icon;
  final bool useInitials;

  static const _hidden = {
    '_id', '__v', '__t', 'id', 'companyId', 'masterCompanyId', 'updatedAt'
  };

  String _format(String key, dynamic value) {
    if (value is Map) {
      return value.entries
          .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
          .map((e) => '${Fmt.humanize(e.key)}: ${e.value}')
          .join('\n');
    }
    if (value is List) return value.map((e) => e.toString()).join(', ');
    final text = value.toString();
    if (Fmt.looksLikeDate(text)) return Fmt.dateTime(text);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final entries = item.entries
        .where((e) =>
            !_hidden.contains(e.key) &&
            e.value != null &&
            e.value.toString().trim().isNotEmpty)
        .toList();
    final displayTitle = title.isEmpty ? 'Record details' : title;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.66,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Row(
            children: [
              useInitials
                  ? InitialsAvatar(displayTitle, size: 52)
                  : Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: AppColors.brand),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      StatusChip(status),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 6),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.humanize(entry.key),
                    style: TextStyle(
                      color: context.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _format(entry.key, entry.value),
                    style: TextStyle(
                      color: context.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
