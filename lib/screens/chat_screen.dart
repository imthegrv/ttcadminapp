import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'employee_directory_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final id = auth.user['_id'] ?? auth.user['id'] ?? '';
    try {
      final raw = await auth.api.get('/chat/rooms/internal/$id');
      if (mounted) {
        setState(() => _rooms = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : []);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startDirectChat() async {
    final room = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeDirectoryScreen()),
    );
    if (room == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Team chat')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _startDirectChat,
          icon: const Icon(Icons.add_comment_rounded),
          label: const Text('New chat'),
        ),
        body: _loading
            ? const ListSkeleton()
            : RefreshIndicator(
                color: AppColors.brand,
                onRefresh: _load,
                child: _rooms.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          StateMessage(
                            icon: Icons.forum_rounded,
                            title: 'No conversations yet',
                            message:
                                'Team rooms you belong to will appear here.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final room = _rooms[index];
                          final last = room['lastMessage'] is Map
                              ? Map<String, dynamic>.from(
                                  room['lastMessage'] as Map)
                              : const <String, dynamic>{};
                          final name = (room['name'] ?? 'Team room').toString();
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(room: room)),
                            ),
                            child: Row(
                              children: [
                                InitialsAvatar(name,
                                    size: 46, icon: Icons.forum_rounded),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      const SizedBox(height: 3),
                                      Text(
                                        (last['content'] ?? 'No messages yet')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (Fmt.relative(
                                        last['timestamp'] ?? last['createdAt'])
                                    .isNotEmpty)
                                  Text(
                                      Fmt.relative(last['timestamp'] ??
                                          last['createdAt']),
                                      style: TextStyle(
                                          color: context.faint,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
      );
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.room});
  final Map<String, dynamic> room;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _peerTyping = false;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  Timer? _typingTimer;
  Timer? _typingOutThrottle;

  final _socket = SocketService.instance;

  String get _roomId => (widget.room['_id'] ?? widget.room['id']).toString();
  String get _myId {
    final user = context.read<AuthProvider>().user;
    return (user['_id'] ?? user['id'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _socket.joinRoom(_roomId);
    _msgSub = _socket.messages.listen(_onIncoming);
    _typingSub = _socket.typing.listen(_onTyping);
  }

  @override
  void dispose() {
    _socket.leaveRoom(_roomId);
    _msgSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _typingOutThrottle?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onIncoming(Map<String, dynamic> message) {
    if (!mounted) return;
    if ((message['room'] ?? '').toString() != _roomId) return;
    final id = (message['_id'] ?? '').toString();
    final exists =
        id.isNotEmpty && _messages.any((m) => (m['_id'] ?? '').toString() == id);
    if (exists) return;
    setState(() {
      _messages.add(message);
      _peerTyping = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  void _onTyping(Map<String, dynamic> event) {
    if (!mounted) return;
    if ((event['room'] ?? '').toString() != _roomId) return;
    final sender = event['sender'];
    final senderId = sender is Map ? (sender['id'] ?? '').toString() : '';
    if (senderId == _myId) return;
    setState(() => _peerTyping = true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3),
        () => mounted ? setState(() => _peerTyping = false) : null);
  }

  void _onChanged(String _) {
    // Throttle outbound typing pings to once per ~1.5s.
    if (_typingOutThrottle?.isActive ?? false) return;
    _socket.sendTyping(roomId: _roomId, senderId: _myId);
    _typingOutThrottle = Timer(const Duration(milliseconds: 1500), () {});
  }

  Future<void> _load() async {
    try {
      final raw = await context.read<AuthProvider>().api.get('/chat/rooms/$_roomId/messages');
      if (mounted) {
        setState(() => _messages = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : []);
        WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _mine(Map<String, dynamic> message) {
    final sender = message['sender'];
    return sender is Map && sender['id'].toString() == _myId;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text((widget.room['name'] ?? 'Team room').toString(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              ValueListenableBuilder<bool>(
                valueListenable: _socket.connected,
                builder: (_, online, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _peerTyping
                            ? AppColors.brand
                            : online
                                ? AppColors.success
                                : context.faint,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _peerTyping
                          ? 'typing…'
                          : online
                              ? 'Connected'
                              : 'Offline',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const StateMessage(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No messages yet',
                          message: 'Say hello to start the conversation.',
                        )
                      : RefreshIndicator(
                          color: AppColors.brand,
                          onRefresh: _load,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (_, index) =>
                                _bubble(_messages[index]),
                          ),
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  border: Border(top: BorderSide(color: context.line)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onChanged: _onChanged,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Write a message…',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.brand,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sending ? null : _send,
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: _sending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bubble(Map<String, dynamic> message) {
    final mine = _mine(message);
    final sender = message['sender'];
    final senderName =
        sender is Map ? (sender['name'] ?? sender['FirstName'] ?? '').toString() : '';
    final time = Fmt.time(message['timestamp'] ?? message['createdAt']);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.brand : context.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: context.line),
          boxShadow: mine ? null : AppShadow.card,
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine && senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(senderName,
                    style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            Text(
              (message['content'] ?? '').toString(),
              style: TextStyle(
                  color: mine ? Colors.white : context.ink,
                  fontSize: 14.5,
                  height: 1.35),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(time,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: mine
                            ? Colors.white.withValues(alpha: 0.7)
                            : context.faint)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _message.clear();

    // Prefer the live socket — the server persists and broadcasts the message
    // back via `newMessage`, which `_onIncoming` appends (deduped by _id).
    if (_socket.isConnected) {
      _socket.sendMessage(roomId: _roomId, content: text, senderId: _myId);
      return;
    }

    // Offline fallback: authenticated REST send.
    setState(() => _sending = true);
    try {
      final result = await context.read<AuthProvider>().api.post(
        '/chat/rooms/$_roomId/messages',
        data: {'content': text},
      );
      if (result is Map && mounted) {
        setState(() => _messages.add(Map<String, dynamic>.from(result)));
        WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
      }
    } catch (_) {
      if (mounted) {
        _message.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }
}
