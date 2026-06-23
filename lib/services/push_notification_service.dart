import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';
import 'deep_link_router.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _token;

  Future<void> initialize(ApiClient api) async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      await _local.initialize(
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
      const channel = AndroidNotificationChannel(
        'tripclub_operations',
        'TripClub Operations',
        description: 'Operational alerts for leads, bookings, meetings and tasks.',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      _token = await messaging.getToken();
      if ((_token ?? '').isNotEmpty) await _register(api, _token!);
      messaging.onTokenRefresh.listen((token) {
        _token = token;
        _register(api, token);
      });
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Tap handling: background → foreground, and cold start from terminated.
      FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => DeepLinkRouter.handle(message.data));
      final initial = await messaging.getInitialMessage();
      if (initial != null) DeepLinkRouter.handle(initial.data);

      _initialized = true;
    } catch (error) {
      debugPrint('Push notifications are awaiting Firebase native configuration: $error');
    }
  }

  Future<void> unregister(ApiClient api) async {
    if ((_token ?? '').isEmpty) return;
    try {
      await api.post('/notifications/devices/unregister', data: {'token': _token});
    } catch (_) {
      // Logout must still complete if the device is offline.
    }
  }

  Future<void> _register(ApiClient api, String token) => api.post(
        '/notifications/devices/register',
        data: {
          'token': token,
          'platform': switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.iOS => 'ios',
            _ => 'unknown',
          },
          'deviceName': defaultTargetPlatform.name,
          'appVersion': '1.0.0',
        },
      );

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title ?? 'TripClub',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tripclub_operations',
          'TripClub Operations',
          channelDescription: 'Operational alerts for the TripClub team.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      // Carry the deep-link data so a tap on the local notification routes too.
      payload: jsonEncode(message.data),
    );
  }
}
