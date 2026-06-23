import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId, this.initial});
  final String invoiceId;
  final Map<String, dynamic>? initial;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Map<String, dynamic>? _inv;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inv = widget.initial;
    _load();
  }

  String get _id => (_inv?['_id'] ?? widget.invoiceId).toString();
  String get _currency => (_inv?['currency'] ?? 'INR').toString();

  double _num(dynamic v) => v is num
      ? v.toDouble()
      : double.tryParse(v?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '') ?? '') ?? 0;

  double get _total => _num(_inv?['total']);
  List<Map<String, dynamic>> get _records => _inv?['paymentRecords'] is List
      ? List<Map<String, dynamic>>.from((_inv!['paymentRecords'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)))
      : [];
  double get _received =>
      _records.fold(0.0, (s, r) => s + _num(r['amountPaid'] ?? r['amount']));

  String get _clientName {
    final c = _inv?['clientData'] is Map ? _inv!['clientData'] as Map : const {};
    return (c['PersonName'] ?? c['CompanyName'] ?? 'Client').toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context.read<AuthProvider>().api.get(
          '/accounting/invoice/byid', query: {'invoiceId': widget.invoiceId});
      if (!mounted) return;
      setState(() => _inv = Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this invoice.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> body, String toast) async {
    setState(() => _busy = true);
    try {
      await context
          .read<AuthProvider>()
          .api
          .patch('/accounting/invoice/update/$_id', data: body);
      _dirty = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(toast)));
      }
    } catch (e) {
      if (mounted) {
        final s = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Update failed: ${s.length > 90 ? '${s.substring(0, 90)}…' : s}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invoice'),
          actions: [
            if (_inv != null)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy ? null : _editClient,
              ),
          ],
        ),
        body: _loading && _inv == null
            ? const ListSkeleton()
            : _error != null && _inv == null
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
                      _amountsCard(),
                      const SizedBox(height: 14),
                      _itemsCard(),
                      const SizedBox(height: 14),
                      _paymentsCard(),
                    ],
                  ),
      ),
    );
  }

  Widget _header() {
    final number = (_inv?['invoiceNumber'] ?? '').toString();
    final status = (_inv?['PaymentStatus'] ?? '').toString();
    final date = _inv?['invoiceDate'];
    final due = _inv?['dueDate'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15A36E), Color(0xFF84CC16)],
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
              const Icon(Icons.receipt_long_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(number.isEmpty ? 'Invoice' : number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(Fmt.money(_total, _currency),
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_clientName,
              style: const TextStyle(color: Color(0xFFE8FCE8), fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status.isNotEmpty) _ghostChip(status),
              if (date != null) _ghostChip('Issued ${Fmt.date(date)}'),
              if (due != null) _ghostChip('Due ${Fmt.date(due)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ghostChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSpace.rPill),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );

  Widget _amountsCard() {
    final taxable = _num(_inv?['TaxableValue'] ?? _inv?['subTotal']);
    final gst = _num(_inv?['GstTotal']);
    final balance = (_total - _received).clamp(0, double.infinity).toDouble();
    return AppCard(
      child: Column(
        children: [
          _row('Taxable value', taxable),
          _row('GST', gst),
          const Divider(height: 22),
          _row('Total', _total, bold: true),
          _row('Received', _received, tone: AppColors.success),
          _row('Balance due', balance,
              tone: balance > 0 ? AppColors.danger : context.muted, bold: balance > 0),
        ],
      ),
    );
  }

  Widget _row(String label, double v, {bool bold = false, Color? tone}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: tone ?? context.inkSoft,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
            Text(Fmt.money(v, _currency),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                    fontSize: bold ? 16 : 14,
                    color: tone)),
          ],
        ),
      );

  Widget _itemsCard() {
    final items = _inv?['invoiceitems'] is List
        ? List<Map<String, dynamic>>.from((_inv!['invoiceitems'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)))
        : <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              (it['itemname'] ?? it['desc'] ?? 'Item').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                              '${it['qty'] ?? 1} × ${Fmt.money(it['rate'], _currency)}',
                              style:
                                  TextStyle(color: context.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(Fmt.money(it['total'] ?? it['itemSubtotal'], _currency),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _paymentsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Payments',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              TextButton.icon(
                onPressed: _busy || _received >= _total && _total > 0
                    ? null
                    : _recordPayment,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Record'),
              ),
            ],
          ),
          if (_records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('No payments recorded yet.',
                  style: TextStyle(color: context.muted, fontSize: 13)),
            )
          else
            ..._records.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((r['paymentMethod'] ?? 'Payment').toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13.5)),
                            if ((r['datePaid'] ?? '').toString().isNotEmpty ||
                                (r['note'] ?? '').toString().isNotEmpty)
                              Text(
                                  [
                                    if ((r['datePaid'] ?? '').toString().isNotEmpty)
                                      Fmt.date(r['datePaid']),
                                    if ((r['note'] ?? '').toString().isNotEmpty)
                                      r['note'].toString(),
                                  ].join(' · '),
                                  style: TextStyle(
                                      color: context.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(Fmt.money(r['amountPaid'] ?? r['amount'], _currency),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _recordPayment() async {
    final amountC = TextEditingController(
        text: ((_total - _received).clamp(0, double.infinity)).toStringAsFixed(0));
    final noteC = TextEditingController();
    final paidBy = context.read<AuthProvider>().displayName;
    String method = 'Bank Transfer';
    final res = await showModalBottomSheet<Map<String, dynamic>>(
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
                  'Bank Transfer', 'Card', 'Cash', 'UPI', 'Cheque', 'Other'
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setSheet(() => method = v ?? 'Bank Transfer'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.notes_rounded)),
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
                      'note': noteC.text.trim(),
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
    if (res == null) return;
    final records = [
      ..._records,
      {
        'amountPaid': res['amount'].toString(),
        'datePaid': DateTime.now().toIso8601String(),
        'paymentMethod': res['method'],
        'note': res['note'],
        'paidBy': paidBy,
      }
    ];
    await _patch(
      {'paymentRecords': records, 'total': _total},
      'Payment recorded',
    );
  }

  Future<void> _editClient() async {
    final c = _inv?['clientData'] is Map ? _inv!['clientData'] as Map : const {};
    final name = TextEditingController(
        text: (c['PersonName'] ?? c['CompanyName'] ?? '').toString());
    final email = TextEditingController(text: (c['Email'] ?? '').toString());
    final remarks =
        TextEditingController(text: (_inv?['invoiceRemarks'] ?? '').toString());
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
            const Text('Edit invoice',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 16),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Client name')),
            const SizedBox(height: 12),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Client email')),
            const SizedBox(height: 12),
            TextField(
                controller: remarks,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Remarks')),
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
    await _patch({
      'clientData': {
        'PersonName': name.text.trim(),
        'Email': email.text.trim(),
      },
      'invoiceRemarks': remarks.text.trim(),
    }, 'Invoice updated');
  }
}
