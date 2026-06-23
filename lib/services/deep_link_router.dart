import 'package:flutter/material.dart';
import '../screens/lead_detail_screen.dart';
import '../screens/booking_detail_screen.dart';
import '../screens/mailbox_screen.dart';
import '../screens/meeting_management_screen.dart';
import '../screens/operations_shell.dart';
import 'navigation_service.dart';

/// Translates a push-notification payload (`{ type, link, notificationId }`)
/// into in-app navigation.
///
/// Backend link formats (see TTCBackendAPI):
///   `/crm/leads/view-{id}`          → lead detail
///   `/bookings/view/{bookingId}`    → bookings
///   `/crm/orders/view-booking-{id}` → bookings
///   `/crm/customers/view-{id}`      → customers
///   anything else                   → notifications list
class DeepLinkRouter {
  DeepLinkRouter._();

  static void handle(Map<String, dynamic> data) {
    final link = (data['link'] ?? '').toString();
    final type = (data['type'] ?? '').toString().toLowerCase();
    // Defer until the navigator exists (e.g. cold start from a terminated app).
    WidgetsBinding.instance.addPostFrameCallback((_) => _route(link, type));
  }

  static void _route(String link, String type) {
    final nav = NavigationService.nav;
    final ctx = NavigationService.context;
    if (nav == null || ctx == null) return;

    Widget? screen;

    final leadId = _after(link, 'leads/view-');
    final bookingId =
        _after(link, 'bookings/view/') ?? _after(link, 'orders/view-booking-');
    if (leadId != null) {
      screen = LeadDetailScreen(leadId: leadId);
    } else if (type == 'lead') {
      screen = ResourceCatalog.leads(ctx);
    } else if (bookingId != null) {
      screen = BookingDetailScreen(bookingId: bookingId);
    } else if (type == 'booking') {
      screen = ResourceCatalog.bookings(ctx);
    } else if (link.contains('customers/view-') || type == 'customer') {
      screen = ResourceCatalog.customers(ctx);
    } else if (type == 'invoice') {
      screen = ResourceCatalog.invoices(ctx);
    } else if (type == 'meeting' || link.contains('meetings/')) {
      screen = const MeetingManagementScreen();
    } else if (type == 'email' || type == 'mail') {
      screen = const MailboxScreen();
    } else {
      screen = ResourceCatalog.notifications(ctx);
    }

    nav.push(MaterialPageRoute(builder: (_) => screen!));
  }

  /// Returns the trailing id after [marker], or null if not present.
  static String? _after(String link, String marker) {
    final idx = link.indexOf(marker);
    if (idx < 0) return null;
    final tail = link.substring(idx + marker.length).trim();
    final id = tail.split(RegExp(r'[/?#]')).first;
    return id.isEmpty ? null : id;
  }
}
