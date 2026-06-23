import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/formatters.dart';
import '../widgets/form_kit.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _client = TextEditingController();
  final _email = TextEditingController();
  final _remarks = TextEditingController();
  final List<_InvoiceItem> _items = [_InvoiceItem()];
  String _currency = 'INR';
  bool _saving = false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.taxable);
  double get _gst => _items.fold(0, (sum, item) => sum + item.gst);
  double get _total => _subtotal + _gst;

  @override
  void dispose() {
    _client.dispose();
    _email.dispose();
    _remarks.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create invoice')),
        bottomNavigationBar: SubmitBar(
          label: 'Create invoice',
          icon: Icons.receipt_long_rounded,
          saving: _saving,
          onPressed: _save,
          helper: 'Total ${Fmt.money(_total, _currency)}',
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            const FormSection('Client', icon: Icons.person_rounded),
            TextField(controller: _client, decoration: const InputDecoration(labelText: 'Client name')),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Client email'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Invoice items',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_InvoiceItem())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) => _itemCard(entry.key, entry.value)),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const ['INR', 'USD', 'AED', 'EUR', 'GBP']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => _currency = value ?? 'INR'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _remarks,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Remarks / payment terms'),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _summary('Taxable value', _subtotal),
                    _summary('GST', _gst),
                    const Divider(),
                    _summary('Total', _total, bold: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _itemCard(int index, _InvoiceItem item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (_items.length > 1)
                      IconButton(
                        onPressed: () => setState(() {
                          _items.removeAt(index).dispose();
                        }),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                TextField(controller: item.name, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _number(item.qty, 'Qty')),
                    const SizedBox(width: 10),
                    Expanded(child: _number(item.rate, 'Rate')),
                    const SizedBox(width: 10),
                    Expanded(child: _number(item.gstRate, 'GST %')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _number(TextEditingController controller, String label) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label),
      );

  Widget _summary(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              Fmt.money(value, _currency),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14),
            ),
          ],
        ),
      );

  Future<void> _save() async {
    if (_client.text.trim().isEmpty || _items.any((item) => item.name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client and item descriptions are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().api.post(
        '/accounting/invoice/add',
        data: {
          'invoiceDate': DateTime.now().toUtc().toIso8601String(),
          'dueDate': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
          'currency': _currency,
          'clientData': {
            'PersonName': _client.text.trim(),
            'Email': _email.text.trim(),
            'BillingAddress': {},
            'TaxDetails': {},
          },
          'invoiceitems': _items.map((item) => item.payload()).toList(),
          'invoiceRemarks': _remarks.text.trim(),
          'TotalBeforeDiscount': _subtotal,
          'DiscountTotal': 0,
          'subTotal': _subtotal,
          'TaxableValue': _subtotal,
          'GstTotal': _gst,
          'total': _total,
          'PaymentStatus': 'Unpaid',
          'paymentRecords': [],
          'status': 'Active',
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create invoice: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _InvoiceItem {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  final gstRate = TextEditingController(text: '0');

  double get quantity => double.tryParse(qty.text) ?? 0;
  double get unitRate => double.tryParse(rate.text) ?? 0;
  double get taxPercent => double.tryParse(gstRate.text) ?? 0;
  double get taxable => quantity * unitRate;
  double get gst => taxable * taxPercent / 100;

  Map<String, dynamic> payload() => {
        'itemname': name.text.trim(),
        'desc': name.text.trim(),
        'qty': quantity,
        'rate': unitRate,
        'discount': 0,
        'gstRate': taxPercent,
        'isGstIncl': false,
        'itemSubtotal': taxable,
        'gst': gst,
        'total': taxable + gst,
      };

  void dispose() {
    name.dispose();
    qty.dispose();
    rate.dispose();
    gstRate.dispose();
  }
}
