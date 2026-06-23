import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'lead_wizard_screen.dart';
import 'lead_detail_screen.dart';
import 'booking_detail_screen.dart';
import 'invoice_detail_screen.dart';
import 'mailbox_screen.dart';
import 'follow_ups_screen.dart';
import 'create_booking_screen.dart';
import 'create_invoice_screen.dart';
import 'meeting_management_screen.dart';
import 'chat_screen.dart';
import 'resource_list_screen.dart';
import '../services/push_notification_service.dart';
import '../services/socket_service.dart';
import '../services/reminder_service.dart';

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key});

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      PushNotificationService.instance.initialize(auth.api);
      ReminderService.instance.init();
      final userId =
          (auth.user['_id'] ?? auth.user['id'] ?? '').toString();
      SocketService.instance
          .connect(userId: userId, companyId: auth.companyId);
    });
  }

  static const _destinations = [
    NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.person_search_outlined),
        selectedIcon: Icon(Icons.person_search_rounded),
        label: 'Leads'),
    NavigationDestination(
        icon: Icon(Icons.card_travel_outlined),
        selectedIcon: Icon(Icons.card_travel_rounded),
        label: 'Bookings'),
    NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Invoices'),
    NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _Dashboard(onJump: (i) => setState(() => _index = i)),
      ResourceCatalog.leads(context, onChanged: () => setState(() {})),
      ResourceCatalog.bookings(context),
      ResourceCatalog.invoices(context),
      const MoreScreen(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1150,
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded,
                      color: Colors.white),
                ),
              ),
              destinations: _destinations
                  .map((item) => NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: Text(item.label),
                      ))
                  .toList(),
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: _destinations,
            ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Resource catalog — one source of truth for every list surface.
/// ---------------------------------------------------------------------------
class ResourceCatalog {
  ResourceCatalog._();

  static Widget leads(BuildContext context, {VoidCallback? onChanged}) =>
      ResourceListScreen(
        title: 'Leads',
        icon: Icons.person_search_rounded,
        useInitials: true,
        loader: (auth) => auth.api.get('/crm/leads/FindAll'),
        primaryFields: const ['FirstName', 'CompanyName', 'Email', 'LeadId'],
        subtitleFields: const ['Email', 'Phone', 'PrefDestination', 'Destination'],
        statusFields: const ['LifecycleStage', 'PipelineStage', 'Priority'],
        trailingFields: const ['createdAt', 'updatedAt'],
        floatingAction: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push<bool>(ctx,
                  MaterialPageRoute(builder: (_) => const LeadWizardScreen()));
              onChanged?.call();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('New lead'),
          ),
        ),
        onItemTap: (lead) {
          final id = (lead['_id'] ?? lead['id'] ?? lead['LeadId'] ?? '').toString();
          return Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => LeadDetailScreen(leadId: id, initial: lead),
            ),
          );
        },
      );

  static Widget bookings(BuildContext context) => ResourceListScreen(
        title: 'Bookings',
        icon: Icons.card_travel_rounded,
        accent: AppColors.info,
        loader: (auth) => auth.api.get('/bookings/getbookings'),
        primaryFields: const [
          'PackageName', 'HotelName', 'ActivityName', 'customerData.FirstName', 'bookingId'
        ],
        subtitleFields: const ['bookingId', '__t', 'customerData.Email'],
        statusFields: const ['bookingStatus', 'PaymentStatus'],
        amountField: 'Pricing.TotalPrice',
        currencyField: 'currency',
        trailingFields: const ['DateOfBooking', 'createdAt'],
        floatingAction: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            onPressed: () => Navigator.push<bool>(ctx,
                MaterialPageRoute(builder: (_) => const CreateBookingScreen())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New booking'),
          ),
        ),
        onItemTap: (b) {
          final id = (b['_id'] ?? b['bookingId'] ?? '').toString();
          return Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => BookingDetailScreen(bookingId: id, initial: b)),
          );
        },
      );

  static Widget invoices(BuildContext context) => ResourceListScreen(
        title: 'Invoices',
        icon: Icons.receipt_long_rounded,
        accent: AppColors.success,
        loader: (auth) => auth.api.get('/accounting/invoice/all'),
        primaryFields: const [
          'invoiceNumber', 'clientData.PersonName', 'clientData.CompanyName'
        ],
        subtitleFields: const ['clientData.Email', 'invoiceNumber'],
        statusFields: const ['PaymentStatus', 'status'],
        amountField: 'total',
        currencyField: 'currency',
        trailingFields: const ['invoiceDate', 'createdAt'],
        floatingAction: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            onPressed: () => Navigator.push<bool>(ctx,
                MaterialPageRoute(builder: (_) => const CreateInvoiceScreen())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New invoice'),
          ),
        ),
        onItemTap: (inv) {
          final id = (inv['_id'] ?? '').toString();
          return Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoiceId: id, initial: inv)),
          );
        },
      );

  static Widget customers(BuildContext context) => ResourceListScreen(
        title: 'Customers',
        icon: Icons.groups_2_rounded,
        useInitials: true,
        loader: (auth) => auth.api.post('/crm/customers/FindAll', data: {}),
        primaryFields: const ['FirstName', 'PersonName', 'CompanyName', 'Email'],
        subtitleFields: const ['Email', 'Phone'],
        statusFields: const ['status'],
        trailingFields: const ['createdAt'],
      );

  static Widget emails(BuildContext context) => const MailboxScreen();

  static Widget visa(BuildContext context) => ResourceListScreen(
        title: 'Visa prices',
        icon: Icons.badge_outlined,
        accent: AppColors.warning,
        loader: (auth) => auth.api
            .get('/tours/visa-countries', query: {'includeVisaType': true}),
        primaryFields: const ['countryName', 'country'],
        subtitleFields: const ['currency', 'visaCountryId'],
        trailingFields: const ['currency'],
      );

  static Widget notifications(BuildContext context) => ResourceListScreen(
        title: 'Notifications',
        icon: Icons.notifications_none_rounded,
        accent: AppColors.accent,
        loader: (auth) => auth.api.get('/notifications',
            query: {'page': 1, 'limit': 40, 'type': 'all'}),
        primaryFields: const ['title', 'message'],
        subtitleFields: const ['message', 'body'],
        statusFields: const ['type'],
        trailingFields: const ['createdAt'],
      );
}

/// ---------------------------------------------------------------------------
/// Dashboard
/// ---------------------------------------------------------------------------
class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.onJump});
  final ValueChanged<int> onJump;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  final Map<String, int?> _counts = {
    'leads': null,
    'bookings': null,
    'invoices': null,
    'meetings': null,
  };
  List<Map<String, dynamic>> _todayMeetings = [];
  List<Map<String, dynamic>> _dueFollowItems = [];
  bool _agendaLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final local = d.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  int _len(dynamic raw) {
    if (raw is List) return raw.length;
    if (raw is Map) {
      for (final k in const ['items', 'data', 'results', 'meetings', 'docs']) {
        if (raw[k] is List) return (raw[k] as List).length;
      }
      if (raw['total'] is num) return (raw['total'] as num).toInt();
    }
    return 0;
  }

  Future<void> _loadStats() async {
    final api = context.read<AuthProvider>().api;
    Future<void> grab(String key, Future<dynamic> Function() call) async {
      try {
        final raw = await call();
        if (mounted) setState(() => _counts[key] = _len(raw));
      } catch (_) {
        if (mounted) setState(() => _counts[key] = -1);
      }
    }

    Future<void> followUps() async {
      try {
        final raw = await api.get('/crm/leads/followups', query: {'status': 'all'});
        final rows = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final dueItems = rows
            .where((e) =>
                e['followUpStatus'] == 'overdue' || e['followUpStatus'] == 'today')
            .toList();
        if (mounted) setState(() => _dueFollowItems = dueItems);
        ReminderService.instance.syncFromFollowUps(rows);
      } catch (_) {}
    }

    Future<void> meetings() async {
      try {
        final raw = await api.get('/crm/meetings/list');
        final rows = raw is Map ? raw['meetings'] : raw;
        final list = rows is List
            ? rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final today = list
            .where((m) =>
                (m['status'] ?? 'scheduled') == 'scheduled' &&
                _isToday(DateTime.tryParse((m['startAt'] ?? '').toString())))
            .toList();
        if (mounted) {
          setState(() {
            _counts['meetings'] = list.length;
            _todayMeetings = today;
          });
        }
        ReminderService.instance.syncFromMeetings(list);
      } catch (_) {
        if (mounted) setState(() => _counts['meetings'] = -1);
      }
    }

    await Future.wait([
      grab('leads', () => api.get('/crm/leads/FindAll')),
      grab('bookings', () => api.get('/bookings/getbookings')),
      grab('invoices', () => api.get('/accounting/invoice/all')),
      meetings(),
      followUps(),
    ]);
    if (mounted) setState(() => _agendaLoading = false);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _confirmSignOut(BuildContext context, AuthProvider auth) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (yes != true) return;
    await PushNotificationService.instance.unregister(auth.api);
    SocketService.instance.dispose();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wide = MediaQuery.sizeOf(context).width > 650;

    final actions = <_QuickAction>[
      _QuickAction('New lead', Icons.person_add_alt_1_rounded, AppColors.brand,
          () => const LeadWizardScreen()),
      _QuickAction('New booking', Icons.add_card_rounded, AppColors.info,
          () => const CreateBookingScreen()),
      _QuickAction('New invoice', Icons.request_quote_rounded,
          AppColors.success, () => const CreateInvoiceScreen()),
      _QuickAction('Follow-ups', Icons.notifications_active_rounded,
          AppColors.danger, () => const FollowUpsScreen()),
      _QuickAction('Meetings', Icons.event_rounded, AppColors.accent,
          () => const MeetingManagementScreen()),
      _QuickAction('Customers', Icons.groups_2_rounded, AppColors.warning,
          () => ResourceCatalog.customers(context)),
      _QuickAction('Team chat', Icons.forum_rounded, AppColors.brandBright,
          () => const ChatScreen()),
    ];

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _loadStats,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: context.canvas,
            toolbarHeight: 72,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                InitialsAvatar(auth.displayName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_greeting,
                          style: TextStyle(
                              color: context.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                      Text(
                        auth.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: context.isDark ? 'Light mode' : 'Dark mode',
                onPressed: () => context.read<ThemeController>().toggle(context),
                icon: Icon(context.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ResourceCatalog.notifications(context))),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => _confirmSignOut(context, auth),
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 6),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _heroCard(),
                const SizedBox(height: 20),
                _statsGrid(wide),
                const SizedBox(height: 24),
                _todayAgenda(),
                const SizedBox(height: 24),
                const SectionHeader('Quick actions'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 3 : 2,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: actions.length,
                  itemBuilder: (_, i) => _actionTile(actions[i]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<_AgendaItem> _buildAgenda() {
    final items = <_AgendaItem>[];

    for (final m in _todayMeetings) {
      final start =
          DateTime.tryParse((m['startAt'] ?? '').toString())?.toLocal();
      if (start == null) continue;
      final type = (m['meetingType'] ?? 'call').toString();
      final loc = (m['location'] ?? '').toString();
      items.add(_AgendaItem(
        when: start,
        overdue: false,
        icon: switch (type) {
          'video' => Icons.videocam_rounded,
          'in-person' => Icons.people_alt_rounded,
          'demo' => Icons.slideshow_rounded,
          'follow-up' => Icons.replay_rounded,
          _ => Icons.call_rounded,
        },
        tone: AppColors.accent,
        title: (m['title'] ?? 'Meeting').toString(),
        subtitle: [type, if (loc.isNotEmpty) loc].join(' · '),
        timeLabel: Fmt.time(start),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MeetingManagementScreen())),
      ));
    }

    for (final f in _dueFollowItems) {
      final follow = f['FollowUp'] is Map ? f['FollowUp'] as Map : const {};
      final due = DateTime.tryParse((follow['DueDate'] ?? '').toString())?.toLocal();
      if (due == null) continue;
      final overdue = f['followUpStatus'] == 'overdue';
      final name = '${f['FirstName'] ?? ''} ${f['LastName'] ?? ''}'.trim();
      final display = name.isEmpty
          ? (f['CompanyName'] ?? f['Email'] ?? 'Lead').toString()
          : name;
      final notes = (follow['Notes'] ?? '').toString();
      final id = (f['_id'] ?? f['id'] ?? f['LeadId'] ?? '').toString();
      items.add(_AgendaItem(
        when: due,
        overdue: overdue,
        icon: Icons.notifications_active_rounded,
        tone: overdue ? AppColors.danger : AppColors.warning,
        title: 'Follow up: $display',
        subtitle: notes.isEmpty ? 'Lead follow-up' : notes,
        timeLabel: overdue ? 'Overdue' : Fmt.time(due),
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      LeadDetailScreen(leadId: id, initial: f)));
          _loadStats();
        },
      ));
    }

    items.sort((a, b) => a.when.compareTo(b.when));
    return items;
  }

  Widget _todayAgenda() {
    final agenda = _buildAgenda();
    final dateLabel = Fmt.date(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Today',
          subtitle: dateLabel,
          action: agenda.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpace.rPill),
                  ),
                  child: Text('${agenda.length}',
                      style: const TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
        ),
        if (_agendaLoading)
          Column(
            children: List.generate(
                2,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Skeleton(height: 64, radius: AppSpace.rLg),
                    )),
          )
        else if (agenda.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppSpace.rLg),
              border: Border.all(color: context.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wb_sunny_rounded,
                      color: AppColors.success),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your day is clear',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text('No meetings or follow-ups due today.',
                          style: TextStyle(
                              color: context.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...agenda.map(_agendaRow),
      ],
    );
  }

  Widget _agendaRow(_AgendaItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: item.onTap,
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(item.timeLabel.replaceAll(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: item.tone,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          height: 1.15)),
                ],
              ),
            ),
            Container(width: 1, height: 38, color: context.line),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, color: item.tone, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.muted, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.brand, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    final pending = _counts['leads'];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppSpace.rXl),
        boxShadow: AppShadow.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Operations pulse',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            pending == null
                ? 'Bringing your workspace up to date…'
                : pending <= 0
                    ? 'All caught up. New leads, bookings and alerts will surface here.'
                    : 'You have $pending lead${pending == 1 ? '' : 's'} in the pipeline. Keep the momentum going.',
            style: const TextStyle(
                color: Color(0xFFF3E8FF), height: 1.45, fontSize: 14.5),
          ),
          const SizedBox(height: 16),
          Text(
            Fmt.dateTime(DateTime.now()).split(' · ').first,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(bool wide) {
    final stats = [
      _Stat('Leads', _counts['leads'], Icons.person_search_rounded,
          AppColors.brand, 1),
      _Stat('Bookings', _counts['bookings'], Icons.card_travel_rounded,
          AppColors.info, 2),
      _Stat('Invoices', _counts['invoices'], Icons.receipt_long_rounded,
          AppColors.success, 3),
      _Stat('Meetings', _counts['meetings'], Icons.event_rounded,
          AppColors.accent, null),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: wide ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: stats.map(_statCard).toList(),
    );
  }

  Widget _statCard(_Stat stat) {
    final value = stat.value;
    return GestureDetector(
      onTap: stat.jumpTo == null ? null : () => widget.onJump(stat.jumpTo!),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppSpace.rLg),
          border: Border.all(color: context.line),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(stat.icon, color: stat.color, size: 18),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Skeleton(width: 42, height: 22, radius: 6),
                        )
                      else
                        Text(
                          value < 0 ? '—' : Fmt.count(value),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: context.ink,
                              height: 1),
                        ),
                      const SizedBox(height: 3),
                      Text(stat.label,
                          style: TextStyle(
                              color: context.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (stat.jumpTo != null)
                  Icon(Icons.arrow_outward_rounded,
                      size: 15, color: context.faint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(_QuickAction action) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => action.builder())),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppSpace.rLg),
          border: Border.all(color: context.line),
          boxShadow: AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 20),
            ),
            Text(action.label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.ink)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.color, this.builder);
  final String label;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color, this.jumpTo);
  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final int? jumpTo;
}

class _AgendaItem {
  const _AgendaItem({
    required this.when,
    required this.overdue,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
  });
  final DateTime when;
  final bool overdue;
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final String timeLabel;
  final VoidCallback onTap;
}

/// ---------------------------------------------------------------------------
/// More tools
/// ---------------------------------------------------------------------------
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  List<(String, String, IconData, Color, Widget Function())> _tools(
          BuildContext context) =>
      [
        ('Follow-ups', 'Leads due for follow-up', Icons.notifications_active_rounded,
            AppColors.danger, () => const FollowUpsScreen()),
        ('Customers', 'Browse your client directory', Icons.groups_2_rounded,
            AppColors.warning, () => ResourceCatalog.customers(context)),
        ('Meetings', 'Schedule and manage meetings', Icons.event_rounded,
            AppColors.accent, () => const MeetingManagementScreen()),
        ('Mailbox', 'Read and triage team email', Icons.mail_outline_rounded,
            AppColors.info, () => ResourceCatalog.emails(context)),
        ('Team chat', 'Message your colleagues', Icons.forum_rounded,
            AppColors.brandBright, () => const ChatScreen()),
        ('Visa prices', 'Look up visa fees by country', Icons.badge_outlined,
            AppColors.success, () => ResourceCatalog.visa(context)),
        ('Notifications', 'All your recent alerts',
            Icons.notifications_none_rounded, AppColors.brand,
            () => ResourceCatalog.notifications(context)),
      ];

  @override
  Widget build(BuildContext context) {
    final tools = _tools(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: context.canvas,
          automaticallyImplyLeading: false,
          expandedHeight: 104,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            expandedTitleScale: 1.5,
            title: Text('More tools',
                style: TextStyle(
                    color: context.ink, fontWeight: FontWeight.w800)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          sliver: SliverList.separated(
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final tool = tools[i];
              return AppCard(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => tool.$5())),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: tool.$4.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(tool.$3, color: tool.$4),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tool.$1,
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(tool.$2,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.faint),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
