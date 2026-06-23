import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class VisaDetailScreen extends StatelessWidget {
  const VisaDetailScreen({super.key, required this.country});
  final Map<String, dynamic> country;

  String get _name =>
      (country['country'] ?? country['countryName'] ?? 'Visa').toString();

  List<Map<String, dynamic>> get _categories {
    final raw = country['visaCategories'] ?? country['visaTypes'] ?? country['categories'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _faqs {
    final raw = country['faqs'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final image = (country['image'] ?? '').toString();
    final cats = _categories;
    final faqs = _faqs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: image.startsWith('http') ? 200 : 120,
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              title: Text(_name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              background: image.startsWith('http')
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(image, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: AppColors.warning)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x99000000)],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE08600), Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  '${cats.length} visa ${cats.length == 1 ? 'type' : 'types'}',
                  style: TextStyle(
                      color: context.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (cats.isEmpty)
                  const StateMessage(
                    icon: Icons.badge_outlined,
                    title: 'No visa types listed',
                    message: 'Pricing has not been configured for this country.',
                  )
                else
                  ...cats.map((c) => _visaTypeCard(context, c)),
                if (faqs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('FAQs',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...faqs.map((f) => _faqTile(context, f)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _visaTypeCard(BuildContext context, Map<String, dynamic> c) {
    final pricing = c['pricing'] is Map ? c['pricing'] as Map : const {};
    final currency = (pricing['currency'] ?? 'INR').toString();
    final adult = pricing['adult'] is Map ? pricing['adult'] as Map : const {};
    final b2c = adult['totalB2C'];
    final b2b = adult['totalB2B'];
    final available = c['availability'] != false;
    final docs = (c['commonDocuments'] is List)
        ? (c['commonDocuments'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final notes = (c['importantNotes'] is List)
        ? (c['importantNotes'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final desc = (c['description'] ?? '').toString().trim();

    final chips = <(String, String)>[
      if ((c['ProcessingTime'] ?? '').toString().isNotEmpty)
        ('Processing', c['ProcessingTime'].toString()),
      if ((c['AvailableEntry'] ?? '').toString().isNotEmpty)
        ('Entry', c['AvailableEntry'].toString()),
      if ((c['ApplyBefore'] ?? '').toString().isNotEmpty)
        ('Apply before', c['ApplyBefore'].toString()),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            (c['categoryName'] ?? 'Visa').toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (available ? AppColors.success : AppColors.danger)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSpace.rPill),
                        ),
                        child: Text(available ? 'Available' : 'Unavailable',
                            style: TextStyle(
                                color: available
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (b2c != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer (adult)',
                                style: TextStyle(
                                    color: context.muted, fontSize: 11)),
                            Text(Fmt.money(b2c, currency),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.warning)),
                          ],
                        ),
                        const SizedBox(width: 18),
                      ],
                      if (b2b != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agent',
                                style: TextStyle(
                                    color: context.muted, fontSize: 11)),
                            Text(Fmt.money(b2b, currency),
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.inkSoft)),
                          ],
                        ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: chips
                          .map((ch) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: context.surfaceAlt,
                                  borderRadius:
                                      BorderRadius.circular(AppSpace.rPill),
                                ),
                                child: Text('${ch.$1}: ${ch.$2}',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: context.inkSoft)),
                              ))
                          .toList(),
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(desc,
                        style: TextStyle(
                            color: context.inkSoft, fontSize: 13.5, height: 1.4)),
                  ],
                ],
              ),
            ),
            if (docs.isNotEmpty || notes.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  title: Text(
                      'Documents & notes (${docs.length + notes.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  children: [
                    if (docs.isNotEmpty)
                      ...docs.map((d) => _bullet(context, d, Icons.description_outlined)),
                    if (notes.isNotEmpty)
                      ...notes.map((n) =>
                          _bullet(context, n, Icons.info_outline_rounded)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: context.faint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: context.inkSoft, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _faqTile(BuildContext context, Map<String, dynamic> f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Text((f['question'] ?? '').toString(),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13.5)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text((f['answer'] ?? '').toString(),
                    style: TextStyle(
                        color: context.inkSoft, fontSize: 13.5, height: 1.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
