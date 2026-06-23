import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

/// Read-only view of a planned (fixed-departure) tour. Built from the list
/// item returned by `/tours/fixed-departures`.
class FixedDepartureDetailScreen extends StatelessWidget {
  const FixedDepartureDetailScreen({super.key, required this.departure});
  final Map<String, dynamic> departure;

  String get _title =>
      (departure['package_name'] ?? departure['title'] ?? 'Fixed departure')
          .toString();

  String? _image() {
    final img = departure['image'];
    if (img is Map) {
      final gallery = img['gallery'];
      if (gallery is List && gallery.isNotEmpty) {
        final first = gallery.first;
        if (first is String) return first;
        if (first is Map) {
          final url = (first['url'] ?? first['src'] ?? first['image'] ?? '').toString();
          if (url.startsWith('http')) return url;
        }
      }
      final cover = (img['cover'] ?? img['url'] ?? '').toString();
      if (cover.startsWith('http')) return cover;
    }
    if (img is String && img.startsWith('http')) return img;
    return null;
  }

  String _duration() {
    final d = departure['duration'];
    if (d is Map) {
      final nights = d['nights'] ?? d['night'];
      final days = d['days'] ?? d['day'];
      if (nights != null && days != null) return '$days days · $nights nights';
      if (nights != null) return '$nights nights';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final image = _image();
    final start = departure['startDate'];
    final end = departure['endDate'];
    final status = (departure['status'] ?? '').toString();
    final price = departure['price'];
    final currency = (departure['currency'] ?? 'INR').toString();
    final seats = departure['seatsLeft'] ?? departure['availableSlots'];
    final place = [departure['city'], departure['country']]
        .where((e) => (e ?? '').toString().trim().isNotEmpty)
        .map((e) => e.toString())
        .toList()
        .toSet()
        .join(', ');
    final notes = (departure['notes'] is List)
        ? (departure['notes'] as List)
            .map((e) => e is Map ? (e['text'] ?? e['note'] ?? e).toString() : e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
        : <String>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: image != null ? 220 : 130,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(18, 0, 56, 14),
              title: Text(_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image.network(image, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _GradientBg())
                  else
                    const _GradientBg(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList.list(
              children: [
                if (place.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 17, color: AppColors.brand),
                      const SizedBox(width: 6),
                      Text(place,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      if (status.isNotEmpty) StatusChip(status, dense: true),
                    ],
                  ),
                const SizedBox(height: 14),

                // Price banner
                if (price != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(AppSpace.rLg),
                      boxShadow: AppShadow.card,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Starting from',
                                style: TextStyle(
                                    color: Color(0xFFEDE4FF), fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(Fmt.money(price, currency),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const Spacer(),
                        if ((departure['pricingMode'] ?? '').toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(AppSpace.rPill),
                            ),
                            child: Text('${departure['pricingMode']} pricing',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    children: [
                      _row(context, Icons.flight_takeoff_rounded, 'Departs',
                          Fmt.date(start)),
                      _row(context, Icons.flight_land_rounded, 'Returns',
                          Fmt.date(end)),
                      _row(context, Icons.schedule_rounded, 'Duration',
                          _duration()),
                      _row(context, Icons.event_seat_rounded, 'Seats left',
                          seats == null ? '' : '$seats'),
                    ],
                  ),
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notes',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 8),
                        ...notes.map((n) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.circle,
                                      size: 6, color: context.faint),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(n,
                                        style: TextStyle(
                                            color: context.inkSoft,
                                            fontSize: 13.5,
                                            height: 1.4)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.muted),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: context.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GradientBg extends StatelessWidget {
  const _GradientBg();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient),
      );
}
