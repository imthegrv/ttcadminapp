import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/reminder_service.dart';
import '../services/socket_service.dart';

/// App-wide notification state: loads the backend list, listens to the live
/// `app-notification` socket stream, surfaces a local OS notification for each
/// new one, and tracks the unread count for the badge.
class NotificationCenter extends ChangeNotifier {
  ApiClient? _api;
  String _myId = '';
  StreamSubscription? _sub;

  List<Map<String, dynamic>> items = [];
  bool loading = false;
  bool _bound = false;

  int get unread => items.where((n) => !isRead(n)).length;

  bool isRead(Map n) {
    final rb = n['readBy'];
    if (rb is List) return rb.map((e) => e.toString()).contains(_myId);
    return n['read'] == true;
  }

  /// Call once after login (socket connected). Idempotent.
  void bind(ApiClient api, String myId, SocketService socket) {
    _api = api;
    _myId = myId;
    if (_bound) return;
    _bound = true;
    _sub = socket.notifications.listen(_onLive);
    refresh();
  }

  void unbind() {
    _sub?.cancel();
    _sub = null;
    _bound = false;
    items = [];
    _myId = '';
  }

  Future<void> refresh() async {
    if (_api == null) return;
    loading = true;
    notifyListeners();
    try {
      final raw = await _api!.get('/notifications',
          query: {'page': 1, 'limit': 60, 'type': 'all'});
      final list = raw is Map ? (raw['results'] ?? raw['data'] ?? raw['items']) : raw;
      items = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (_) {
      // keep whatever we had
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _onLive(Map<String, dynamic> n) {
    final id = (n['_id'] ?? '').toString();
    if (id.isNotEmpty && items.any((e) => (e['_id'] ?? '').toString() == id)) {
      return; // dedupe
    }
    items.insert(0, n);
    notifyListeners();
    // Surface it as a local OS notification (works on iOS sideload too).
    ReminderService.instance.showAlert(
      title: (n['title'] ?? 'TripClub').toString(),
      body: (n['message'] ?? '').toString(),
      type: (n['type'] ?? '').toString(),
      link: (n['link'] ?? '').toString(),
    );
  }

  Future<void> markRead(Map<String, dynamic> n) async {
    if (isRead(n)) return;
    final rb = n['readBy'] is List ? List.from(n['readBy']) : <dynamic>[];
    rb.add(_myId);
    n['readBy'] = rb;
    notifyListeners();
    try {
      await _api?.patch('/notifications/${n['_id']}/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    var changed = false;
    for (final n in items) {
      if (!isRead(n)) {
        final rb = n['readBy'] is List ? List.from(n['readBy']) : <dynamic>[];
        rb.add(_myId);
        n['readBy'] = rb;
        changed = true;
      }
    }
    if (changed) notifyListeners();
    try {
      await _api?.patch('/notifications/mark-all-read');
    } catch (_) {}
  }
}
