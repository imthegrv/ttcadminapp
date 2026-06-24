import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'lead_detail_screen.dart';
import 'customer_detail_screen.dart';
import 'booking_detail_screen.dart';
import 'invoice_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _q = '';
  bool _loading = true;

  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _extract(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      for (final k in const ['items', 'data', 'results', 'docs']) {
        if (raw[k] is List) {
          return (raw[k] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    Future<List<Map<String, dynamic>>> grab(Future<dynamic> Function() c) async {
      try {
        return _extract(await c());
      } catch (_) {
        return [];
      }
    }

    final results = await Future.wait([
      grab(() => api.get('/crm/leads/FindAll')),
      grab(() => api.post('/crm/customers/FindAll', data: {})),
      grab(() => api.get('/bookings/getbookings')),
      grab(() => api.get('/accounting/invoice/all')),
    ]);
    if (!mounted) return;
    setState(() {
      _leads = results[0];
      _customers = results[1];
      _bookings = results[2];
      _invoices = results[3];
      _loading = false;
    });
  }

  bool _match(Map item, List<String> fields) {
    if (_q.isEmpty) return false;
    final hay = fields
        .map((f) {
          dynamic v = item;
          for (final p in f.split('.')) {
            if (v is! Map) return '';
            v = v[p];
          }
          return v?.toString() ?? '';
        })
        .join(' ')
        .toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final leadHits = _leads
        .where((e) => _match(e, ['FirstName', 'LastName', 'Email', 'Phone', 'CompanyName', 'LeadId']))
        .toList();
    final custHits = _customers
        .where((e) => _match(e, ['FirstName', 'LastName', 'PersonName', 'Email', 'Phone', 'CompanyName']))
        .toList();
    final bookHits = _bookings
        .where((e) => _match(e, ['bookingId', 'HotelName', 'PackageName', 'ActivityName', 'customerData.FirstName', 'customerData.Email']))
        .toList();
    final invHits = _invoices
        .where((e) => _match(e, ['invoiceNumber', 'clientData.PersonName', 'clientData.CompanyName', 'clientData.Email']))
        .toList();

    final total = leadHits.length + custHits.length + bookHits.length + invHits.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search leads, customers, bookings, invoices…',
            border: InputBorder.none,
            filled: false,
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _q = '');
                    },
                  ),
          ),
        ),
      ),
      body: _loading
          ? const ListSkeleton()
          : _q.isEmpty
              ? const StateMessage(
                  icon: Icons.search_rounded,
                  title: 'Search everything',
                  message:
                      'Find any lead, customer, booking or invoice by name, email, phone or number.',
                )
              : total == 0
                  ? StateMessage(
                      icon: Icons.search_off_rounded,
                      title: 'No matches for “${_controller.text}”',
                      message: 'Try a different name, number or email.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        _group('Leads', leadHits, Icons.person_search_rounded,
                            AppColors.brand,
                            (e) => _leadTitle(e),
                            (e) => (e['Email'] ?? e['Phone'] ?? '').toString(),
                            (e) => LeadDetailScreen(
                                leadId: (e['_id'] ?? e['id'] ?? e['LeadId']).toString(),
                                initial: e)),
                        _group('Customers', custHits, Icons.groups_2_rounded,
                            AppColors.warning,
                            (e) => _custTitle(e),
                            (e) => (e['Email'] ?? e['Phone'] ?? '').toString(),
                            (e) => CustomerDetailScreen(customer: e)),
                        _group('Bookings', bookHits, Icons.card_travel_rounded,
                            AppColors.info,
                            (e) => (e['HotelName'] ?? e['PackageName'] ?? e['ActivityName'] ?? 'Booking ${e['bookingId'] ?? ''}').toString(),
                            (e) => '#${e['bookingId'] ?? ''}',
                            (e) => BookingDetailScreen(
                                bookingId: (e['_id'] ?? e['bookingId']).toString(),
                                initial: e)),
                        _group('Invoices', invHits, Icons.receipt_long_rounded,
                            AppColors.success,
                            (e) => (e['invoiceNumber'] ?? e['clientData']?['PersonName'] ?? 'Invoice').toString(),
                            (e) => (e['clientData']?['PersonName'] ?? e['clientData']?['CompanyName'] ?? '').toString(),
                            (e) => InvoiceDetailScreen(
                                invoiceId: (e['_id'] ?? '').toString(), initial: e)),
                      ],
                    ),
    );
  }

  String _leadTitle(Map e) {
    final n = '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim();
    return n.isEmpty ? (e['CompanyName'] ?? e['Email'] ?? 'Lead').toString() : n;
  }

  String _custTitle(Map e) {
    final n = '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim();
    return n.isEmpty
        ? (e['PersonName'] ?? e['CompanyName'] ?? e['Email'] ?? 'Customer').toString()
        : n;
  }

  Widget _group(
    String label,
    List<Map<String, dynamic>> hits,
    IconData icon,
    Color tone,
    String Function(Map<String, dynamic>) title,
    String Function(Map<String, dynamic>) subtitle,
    Widget Function(Map<String, dynamic>) detail,
  ) {
    if (hits.isEmpty) return const SizedBox.shrink();
    final shown = hits.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
          child: Text(
            '${label.toUpperCase()} · ${hits.length}',
            style: TextStyle(
                color: context.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6),
          ),
        ),
        ...shown.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => detail(e))),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: tone, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title(e),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14.5)),
                          if (subtitle(e).trim().isNotEmpty)
                            Text(subtitle(e),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.faint),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
