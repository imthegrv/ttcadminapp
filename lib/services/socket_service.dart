import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

/// Thin wrapper around the TripClub Socket.IO server for real-time chat.
///
/// The backend authenticates by reading `handshake.auth.token` as the user
/// object (`{ _id, type, MasterCompanyId }`) and emits `newMessage` /
/// `typing` events to room members. See backend `src/socket.js`.
class SocketService {
  SocketService._();
  static final instance = SocketService._();

  io.Socket? _socket;
  String? _userId;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final connected = ValueNotifier<bool>(false);

  /// Every `newMessage` pushed by the server.
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// `typing` events: `{ sender, room }`.
  Stream<Map<String, dynamic>> get typing => _typing.stream;

  /// `app-notification` events — the full notification object the backend
  /// broadcasts to the company room (leads, bookings, customers, tasks, …).
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? get userId => _userId;

  void connect({required String userId, required String companyId}) {
    if (userId.isEmpty) return;
    if (_socket != null && _userId == userId) {
      if (!isConnected) _socket!.connect();
      return;
    }
    dispose();
    _userId = userId;

    final socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth({
            'token': {
              '_id': userId,
              'type': 'employee',
              'MasterCompanyId': companyId,
            }
          })
          .build(),
    );

    socket
      ..onConnect((_) {
        connected.value = true;
        debugPrint('[socket] connected');
      })
      ..onDisconnect((_) {
        connected.value = false;
        debugPrint('[socket] disconnected');
      })
      ..onConnectError((e) => debugPrint('[socket] connect error: $e'))
      ..on('newMessage', (data) {
        if (data is Map) _messages.add(Map<String, dynamic>.from(data));
      })
      ..on('typing', (data) {
        if (data is Map) _typing.add(Map<String, dynamic>.from(data));
      })
      ..on('app-notification', (data) {
        if (data is Map) _notifications.add(Map<String, dynamic>.from(data));
      });

    _socket = socket;
    socket.connect();
  }

  void joinRoom(String roomId) {
    if (roomId.isEmpty) return;
    _socket?.emit('joinChatRoom', {'roomId': roomId});
  }

  void leaveRoom(String roomId) {
    if (roomId.isEmpty) return;
    _socket?.emit('leaveChatRoom', {'roomId': roomId});
  }

  /// Emit a message over the socket. The server persists it and broadcasts
  /// `newMessage` to the room (including back to us).
  void sendMessage({
    required String roomId,
    required String content,
    required String senderId,
  }) {
    _socket?.emit('sendMessage', {
      'sender': {'id': senderId, 'type': 'employee'},
      'receiver': null,
      'content': content,
      'chatType': 'internal',
      'room': roomId,
    });
  }

  void sendTyping({required String roomId, required String senderId}) {
    _socket?.emit('typing', {
      'sender': {'id': senderId, 'type': 'employee'},
      'room': roomId,
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }
}
