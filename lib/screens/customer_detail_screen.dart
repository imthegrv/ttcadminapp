import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customer});
  final Map<String, dynamic> customer;

  String _str(List<String> keys) {
    for (final k in keys) {
      dynamic v = customer;
      for (final part in k.split('.')) {
        if (v is! Map) {
          v = null;
          break;
        }
        v = v[part];
      }
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  String get _name {
    final n = '${_str(['FirstName'])} ${_str(['LastName'])}'.trim();
    return n.isNotEmpty
        ? n
        : (_str(['CompanyName', 'PersonName', 'Email']).isNotEmpty
            ? _str(['CompanyName', 'PersonName', 'Email'])
            : 'Customer');
  }

  @override
  Widget build(BuildContext context) {
    final company = _str(['CompanyName']);
    final type = _str(['CustomerType']);
    final status = _str(['Status']);
    final outstanding = customer['OutstandingBalance'];

    final contact = <(IconData, String, String)>[
      (Icons.email_outlined, 'Email', _str(['Email', 'email'])),
      (Icons.phone_outlined, 'Phone', _str(['Phone', 'phone'])),
      (Icons.cake_outlined, 'Date of birth', _str(['Dob'])),
      (Icons.tag_rounded, 'Customer ID', _str(['UniqueId'])),
    ].where((r) => r.$3.trim().isNotEmpty).toList();

    final address = [
      _str(['BillingAddress.Address']),
      _str(['BillingAddress.City']),
      _str(['BillingAddress.State']),
      _str(['BillingAddress.Country']),
      _str(['BillingAddress.ZipCode']),
    ].where((e) => e.trim().isNotEmpty).toList();

    final taxReg = _str(['TaxDetails.IsTaxRegistered']);
    final taxId = _str(['TaxDetails.TaxId']);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppSpace.rXl),
              border: Border.all(color: context.line),
              boxShadow: context.cardShadow,
            ),
            child: Row(
              children: [
                InitialsAvatar(_name, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      if (company.isNotEmpty &&
                          company != _name) ...[
                        const SizedBox(height: 2),
                        Text(company,
                            style: TextStyle(
                                color: context.muted, fontSize: 13.5)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (type.isNotEmpty) StatusChip(type, dense: true),
                          if (status.isNotEmpty)
                            StatusChip(status, dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (outstanding != null)
            _accountCard(context, outstanding),

          if (contact.isNotEmpty)
            _card(
              context,
              'Contact',
              Column(
                children: contact
                    .map((r) => _row(context, r.$1, r.$2, r.$3, copyable: true))
                    .toList(),
              ),
            ),

          if (address.isNotEmpty)
            _card(
              context,
              'Billing address',
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: context.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(address.join(', '),
                        style: const TextStyle(
                            fontSize: 14, height: 1.4, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),

          if (taxReg.isNotEmpty || taxId.isNotEmpty)
            _card(
              context,
              'Tax',
              Column(
                children: [
                  if (taxReg.isNotEmpty)
                    _row(context, Icons.verified_outlined, 'Tax registered',
                        taxReg),
                  if (taxId.isNotEmpty)
                    _row(context, Icons.receipt_outlined, 'Tax ID', taxId,
                        copyable: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context, dynamic outstanding) {
    final value = outstanding is num
        ? outstanding.toDouble()
        : double.tryParse('$outstanding') ?? 0;
    final owes = value > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (owes ? AppColors.danger : AppColors.success)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpace.rLg),
        border: Border.all(
            color: (owes ? AppColors.danger : AppColors.success)
                .withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(owes ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded,
              color: owes ? AppColors.danger : AppColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owes ? 'Outstanding balance' : 'No outstanding balance',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: context.inkSoft)),
                const SizedBox(height: 2),
                Text(Fmt.money(value, 'INR'),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: owes ? AppColors.danger : AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: context.muted, fontSize: 11.5)),
                const SizedBox(height: 1),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              color: context.faint,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
              },
            ),
        ],
      ),
    );
  }
}
