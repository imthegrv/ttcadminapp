import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'deep_link_router.dart';

/// Schedules on-device local notifications that remind the team about lead
/// follow-ups — these fire at the due time even when the app is closed.
///
/// Uses the `timezone` package (a transitive dependency of
/// flutter_local_notifications). We schedule against an absolute instant
/// expressed in UTC, so the reminder fires at the right moment regardless of
/// the device's local zone without needing the IANA zone name.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'tripclub_followups';
  static const _meetingChannelId = 'tripclub_meetings';
  static const _alertChannelId = 'tripclub_alerts';

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            DeepLinkRouter.handle(
                Map<String, dynamic>.from(jsonDecode(payload) as Map));
          } catch (_) {}
        },
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        'Lead follow-ups',
        description: 'Reminders for lead follow-ups that are due.',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _meetingChannelId,
        'Meeting reminders',
        description: 'Reminders before scheduled meetings start.',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _alertChannelId,
        'Live alerts',
        description: 'New leads, bookings, customers and other live activity.',
        importance: Importance.high,
      ));
      _ready = true;
    } catch (e) {
      debugPrint('[reminders] init failed: $e');
    }
  }

  int _alertSeq = 700000;

  /// Show an immediate local notification for a live socket alert. Works on
  /// iOS even without push entitlements (it's a local notification). Tapping
  /// deep-links via [link]/[type].
  Future<void> showAlert({
    required String title,
    required String body,
    String? type,
    String? link,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        _alertSeq++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannelId,
            'Live alerts',
            channelDescription:
                'New leads, bookings, customers and other live activity.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({'type': type ?? '', 'link': link ?? ''}),
      );
    } catch (e) {
      debugPrint('[alerts] show failed: $e');
    }
  }

  int _idFor(String leadId) => leadId.hashCode & 0x7fffffff;

  Future<Set<int>> _pendingIds() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.map((p) => p.id).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  /// (Re)schedule a follow-up reminder. No-op for past due times.
  Future<void> scheduleLeadFollowUp({
    required String leadId,
    required String leadName,
    required DateTime dueAt,
    String? notes,
  }) async {
    await init();
    if (!_ready) return;
    await cancelLeadFollowUp(leadId);
    if (!dueAt.isAfter(DateTime.now())) return;

    final when = tz.TZDateTime.from(dueAt.toUtc(), tz.UTC);
    final payload = jsonEncode({
      'type': 'lead',
      'link': '/crm/leads/view-$leadId',
    });
    try {
      await _plugin.zonedSchedule(
        _idFor(leadId),
        'Follow up: $leadName',
        (notes == null || notes.isEmpty)
            ? 'A lead follow-up is due now.'
            : notes,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Lead follow-ups',
            channelDescription: 'Reminders for lead follow-ups that are due.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[reminders] schedule failed: $e');
    }
  }

  Future<void> cancelLeadFollowUp(String leadId) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_idFor(leadId));
    } catch (_) {}
  }

  /// Re-arm reminders for a batch of follow-up board items so they survive
  /// app restarts / reinstalls. Each item is the raw lead map from
  /// `/crm/leads/followups`.
  Future<void> syncFromFollowUps(List<Map<String, dynamic>> items) async {
    await init();
    if (!_ready) return;
    final pending = await _pendingIds();
    for (final lead in items) {
      final id = (lead['_id'] ?? lead['id'] ?? lead['LeadId'] ?? '').toString();
      final follow = lead['FollowUp'];
      final dueRaw = follow is Map ? follow['DueDate'] : null;
      final due = DateTime.tryParse(dueRaw?.toString() ?? '');
      if (id.isEmpty || due == null) continue;
      if (pending.contains(_idFor(id))) continue; // keep the existing one
      final name = '${lead['FirstName'] ?? ''} ${lead['LastName'] ?? ''}'.trim();
      await scheduleLeadFollowUp(
        leadId: id,
        leadName: name.isEmpty ? 'Lead' : name,
        dueAt: due.toLocal(),
        notes: follow is Map ? follow['Notes']?.toString() : null,
      );
    }
  }

  // --- Meetings -------------------------------------------------------------

  int _meetingIdFor(String meetingId) => 'meeting:$meetingId'.hashCode & 0x7fffffff;

  /// Schedule a reminder [minutesBefore] a meeting starts. Falls back to the
  /// start time itself if the lead-time has already passed. No-op for past
  /// meetings or when [minutesBefore] is 0 and the start is in the past.
  Future<void> scheduleMeeting({
    required String meetingId,
    required String title,
    required DateTime startAt,
    int minutesBefore = 15,
    String? location,
  }) async {
    await init();
    if (!_ready) return;
    await cancelMeeting(meetingId);
    if (minutesBefore < 0) return; // caller chose "no reminder"

    final remindAt = startAt.subtract(Duration(minutes: minutesBefore));
    final fireAt = remindAt.isAfter(DateTime.now()) ? remindAt : startAt;
    if (!fireAt.isAfter(DateTime.now())) return;

    final leadsTime = remindAt.isAfter(DateTime.now()) && minutesBefore > 0;
    final body = leadsTime
        ? 'Starts in $minutesBefore min${(location ?? '').isNotEmpty ? ' · $location' : ''}'
        : 'Starting now${(location ?? '').isNotEmpty ? ' · $location' : ''}';
    final when = tz.TZDateTime.from(fireAt.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(
        _meetingIdFor(meetingId),
        'Meeting: $title',
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _meetingChannelId,
            'Meeting reminders',
            channelDescription: 'Reminders before scheduled meetings start.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '{"type":"meeting","link":""}',
      );
    } catch (e) {
      debugPrint('[reminders] meeting schedule failed: $e');
    }
  }

  Future<void> cancelMeeting(String meetingId) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_meetingIdFor(meetingId));
    } catch (_) {}
  }

  /// Re-arm reminders for a batch of meetings (raw maps from
  /// `/crm/meetings/list`). Cancelled / completed / past meetings are skipped.
  Future<void> syncFromMeetings(List<Map<String, dynamic>> items,
      {int minutesBefore = 15}) async {
    await init();
    if (!_ready) return;
    final pending = await _pendingIds();
    for (final m in items) {
      final id = (m['_id'] ?? m['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final start = DateTime.tryParse((m['startAt'] ?? '').toString());
      final status = (m['status'] ?? 'scheduled').toString();
      if (start == null || status != 'scheduled') {
        await cancelMeeting(id);
        continue;
      }
      if (pending.contains(_meetingIdFor(id))) continue; // keep existing choice
      await scheduleMeeting(
        meetingId: id,
        title: (m['title'] ?? 'Meeting').toString(),
        startAt: start.toLocal(),
        minutesBefore: minutesBefore,
        location: m['location']?.toString(),
      );
    }
  }
}
