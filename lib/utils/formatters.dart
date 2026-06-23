/// Lightweight formatting helpers (no `intl` dependency so the app stays
/// buildable offline against the bundled SDK).
class Fmt {
  Fmt._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _currencySymbols = {
    'INR': '₹',
    'USD': '\$',
    'AED': 'AED ',
    'EUR': '€',
    'GBP': '£',
    'SAR': 'SAR ',
    'SGD': 'S\$',
  };

  /// `23 Jun 2026`
  static String date(dynamic value) {
    final d = _parse(value);
    if (d == null) return '';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// `23 Jun 2026 · 3:45 PM`
  static String dateTime(dynamic value) {
    final d = _parse(value);
    if (d == null) return '';
    return '${date(d)} · ${time(d)}';
  }

  /// `3:45 PM`
  static String time(dynamic value) {
    final d = _parse(value);
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// `2h ago`, `Yesterday`, `3d ago`, then absolute date.
  static String relative(dynamic value) {
    final d = _parse(value);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  /// `₹ 1,23,456.00` style grouping (Western grouping for simplicity).
  static String money(dynamic amount, [String currency = 'INR']) {
    final n = _num(amount);
    if (n == null) return '';
    final symbol = _currencySymbols[currency.toUpperCase()] ?? '$currency ';
    final fixed = n.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final grouped = _group(parts[0]);
    final sign = n < 0 ? '-' : '';
    return '$sign$symbol$grouped.${parts[1]}';
  }

  /// `1,234` integer grouping with no decimals.
  static String count(dynamic value) {
    final n = _num(value);
    if (n == null) return '0';
    return _group(n.round().toString());
  }

  /// Turn `PaymentStatus` / `created_at` / `customerData.FirstName` into a
  /// readable label.
  static String humanize(String key) {
    final last = key.contains('.') ? key.split('.').last : key;
    final spaced = last
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([A-Z])([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}');
    final trimmed = spaced.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Up to two initials from a name string.
  static String initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static DateTime? _parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }

  static num? _num(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  /// Heuristic: does this string look like an ISO date/time?
  static bool looksLikeDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
}
