import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Maps free-form status strings coming from the API (lead stages, payment
/// states, booking states, meeting states) to a consistent semantic colour.
class StatusPalette {
  StatusPalette._();

  static Color tone(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (s.isEmpty) return AppColors.muted;

    bool has(List<String> keys) => keys.any(s.contains);

    if (has(['paid', 'won', 'completed', 'confirmed', 'active', 'qualified',
        'success', 'approved', 'delivered', 'resolved'])) {
      return AppColors.success;
    }
    if (has(['unpaid', 'lost', 'cancelled', 'canceled', 'failed', 'overdue',
        'rejected', 'declined', 'closed-lost', 'inactive'])) {
      return AppColors.danger;
    }
    if (has(['pending', 'hold', 'on hold', 'partial', 'proposal', 'draft',
        'awaiting', 'processing', 'follow'])) {
      return AppColors.warning;
    }
    if (has(['new', 'contacted', 'scheduled', 'open', 'sent', 'in progress',
        'in-progress', 'booked'])) {
      return AppColors.info;
    }
    return AppColors.brand;
  }

  /// Background tint for a chip carrying this status.
  static Color tint(String? raw) => tone(raw).withValues(alpha: 0.12);
}
