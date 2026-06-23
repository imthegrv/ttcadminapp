import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

const kBookingStatuses = [
  'Booked',
  'Confirmed',
  'Completed',
  'Cancelled',
  'Refunded',
  'Expired',
];

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId, this.initial});
  final String bookingId;
  final Map<String, dynamic>? initial;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _b;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _b = widget.initial;
    _load();
  }

  String get _id =>
      (_b?['_id'] ?? _b?['bookingId'] ?? widget.bookingId).toString();

  dynamic _f(String path) {
    dynamic v = _b;
    for (final p in path.split('.')) {
      if (v is! Map) return null;
      v = v[p];
    }
    return v;
  }

  String _str(List<String> paths) {
    for (final p in paths) {
      final v = _f(p);
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  String get _title {
    final t = _str(['HotelName', 'ActivityName', 'PackageName', 'TaxiName',
        'ShipName', 'visaType', 'ServiceName']);
    return t.isNotEmpty ? t : 'Booking ${_str(['bookingId'])}';
  }

  String get _currency => _str(['currency', 'Pricing.Currency']).isEmpty
      ? 'INR'
      : _str(['currency', 'Pricing.Currency']);

  double get _total {
    for (final p in ['Pricing.TotalPrice', 'Pricing.Pricing.TotalPrice',
        'amountPaid']) {
      final v = _f(p);
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final paid = double.tryParse(_f('amountPaid')?.toString() ?? '') ?? 0;
    final due = double.tryParse(_f('amountDue')?.toString() ?? '') ?? 0;
    return paid + due;
  }

  double get _paid =>
      double.tryParse(_f('amountPaid')?.toString() ?? '') ??
      _payments.fold(0.0, (s, p) => s + (double.tryParse('${p['amount']}') ?? 0));

  List<Map<String, dynamic>> get _payments => _f('payments') is List
      ? List<Map<String, dynamic>>.from(
          (_f('payments') as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
      : [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context
          .read<AuthProvider>()
          .api
          .get('/bookings/getbooking/${widget.bookingId}');
      if (!mounted) return;
      setState(() => _b = Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this booking.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(String path, Map<String, dynamic> body, String toast) async {
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().api.post('/bookings/$path/$_id', data: body);
      _dirty = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(toast)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update failed: ${_clean(e)}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clean(Object e) {
    final s = e.toString();
    return s.length > 90 ? '${s.substring(0, 90)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: _loading && _b == null
            ? const ListSkeleton()
            : _error != null && _b == null
                ? StateMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unavailable',
                    message: _error!,
                    tone: AppColors.danger,
                    onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _statusCard(),
                      const SizedBox(height: 14),
                      _paymentCard(),
                      const SizedBox(height: 14),
                      _detailsCard(),
                    ],
                  ),
      ),
    );
  }

  Widget _header() {
    final type = _str(['__t', 'type', 'bookingType']).replaceAll('Booking', '');
    final customer = _str(['customerData.FirstName', 'customerData.GivenName']);
    final customerFull =
        '$customer ${_str(['customerData.LastName', 'customerData.FamilyName'])}'.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpace.rXl),
        boxShadow: AppShadow.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_travel_rounded, color: Colors.white),
              const SizedBox(width: 8),
              if (type.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              Text('#${_str(['bookingId'])}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          if (customerFull.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_rounded, color: Color(0xFFD6ECFF), size: 15),
                const SizedBox(width: 5),
                Text(customerFull,
                    style: const TextStyle(color: Color(0xFFD6ECFF), fontSize: 13.5)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    final current = _str(['bookingStatus']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Booking status',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              if (_busy)
                const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kBookingStatuses.map((s) {
              final selected = s == current;
              final tone = s == 'Cancelled' || s == 'Expired'
                  ? AppColors.danger
                  : s == 'Completed' || s == 'Confirmed'
                      ? AppColors.success
                      : s == 'Refunded'
                          ? AppColors.warning
                          : AppColors.info;
              return GestureDetector(
                onTap: _busy || selected
                    ? null
                    : () => _update('update', {'bookingStatus': s},
                        'Status set to $s'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? tone : context.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSpace.rPill),
                    border:
                        Border.all(color: selected ? tone : context.line),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          color: selected ? Colors.white : context.inkSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final total = _total;
    final paid = _paid;
    final due = (total - paid).clamp(0, double.infinity).toDouble();
    final status = _str(['PaymentStatus']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Payment',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 10),
              if (status.isNotEmpty) StatusChip(status, dense: true),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _recordPayment,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Record'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _amountRow('Total', total, bold: true),
          _amountRow('Received', paid, tone: AppColors.success),
          _amountRow('Balance due', due,
              tone: due > 0 ? AppColors.danger : context.muted),
          if (_payments.isNotEmpty) ...[
            const Divider(height: 24),
            ..._payments.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.payments_rounded,
                          size: 16, color: context.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            (p['method'] ?? 'Payment').toString(),
                            if ((p['reference'] ?? '').toString().isNotEmpty)
                              '· ${p['reference']}',
                            if (p['date'] != null) '· ${Fmt.date(p['date'])}',
                          ].join(' '),
                          style: TextStyle(fontSize: 12.5, color: context.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(Fmt.money(p['amount'], _currency),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(String label, double value, {bool bold = false, Color? tone}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: tone ?? context.inkSoft,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
          Text(Fmt.money(value, _currency),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                  fontSize: bold ? 16 : 14,
                  color: tone)),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    final rows = <(String, String)>[
      ('Supplier', _str(['SupplierName'])),
      ('Supplier ref', _str(['SupplierBookingId', 'SupplierBookingId'])),
      ('Confirmation', _str(['ConfirmationNo'])),
      ('Check-in', Fmt.date(_f('CheckInDate') ?? _f('TravelDate') ?? _f('SailingDate'))),
      ('Check-out', Fmt.date(_f('CheckOutDate'))),
      ('Destination', _str(['HotelAddress', 'DeparturePort', 'visaCountry'])),
      ('Email', _str(['customerData.Email'])),
      ('Phone', _str(['customerData.Phone'])),
      ('Notes', _str(['Notes'])),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _editOperational,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Text('No additional details.',
                style: TextStyle(color: context.muted, fontSize: 13))
          else
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(r.$1,
                            style: TextStyle(
                                color: context.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(r.$2,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _recordPayment() async {
    final amountC = TextEditingController(
        text: ((_total - _paid).clamp(0, double.infinity)).toStringAsFixed(0));
    final refC = TextEditingController();
    String method = 'Bank Transfer';
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record payment',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 16),
              TextField(
                controller: amountC,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Amount ($_currency)',
                    prefixIcon: const Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  'Bank Transfer', 'Card', 'Cash', 'UPI', 'Cheque', 'Manual Payment'
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setSheet(() => method = v ?? 'Bank Transfer'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refC,
                decoration: const InputDecoration(
                    labelText: 'Reference (optional)',
                    prefixIcon: Icon(Icons.tag_rounded)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final amt = double.tryParse(amountC.text.trim()) ?? 0;
                    if (amt <= 0) return;
                    Navigator.pop(ctx, {
                      'amount': amt,
                      'method': method,
                      'reference': refC.text.trim(),
                    });
                  },
                  child: const Text('Save payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    final payments = [
      ..._payments,
      {
        'amount': result['amount'],
        'currency': _currency,
        'method': result['method'],
        'reference': result['reference'],
        'date': DateTime.now().toIso8601String(),
      }
    ];
    await _update('update-financials', {'payments': payments}, 'Payment recorded');
  }

  Future<void> _editOperational() async {
    final supplier = TextEditingController(text: _str(['SupplierName']));
    final ref = TextEditingController(text: _str(['SupplierBookingId']));
    final conf = TextEditingController(text: _str(['ConfirmationNo']));
    final notes = TextEditingController(text: _str(['Notes']));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit booking details',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 16),
            TextField(
                controller: supplier,
                decoration: const InputDecoration(labelText: 'Supplier')),
            const SizedBox(height: 12),
            TextField(
                controller: ref,
                decoration:
                    const InputDecoration(labelText: 'Supplier reference')),
            const SizedBox(height: 12),
            TextField(
                controller: conf,
                decoration:
                    const InputDecoration(labelText: 'Confirmation number')),
            const SizedBox(height: 12),
            TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save changes')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _update(
      'update',
      {
        'SupplierName': supplier.text.trim(),
        'SupplierBookingId': ref.text.trim(),
        'ConfirmationNo': conf.text.trim(),
        'Notes': notes.text.trim(),
      },
      'Booking updated',
    );
  }
}
