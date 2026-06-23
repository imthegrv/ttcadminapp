import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'mail_compose_screen.dart';

const _folders = [
  ('inbox', 'Inbox', Icons.inbox_rounded),
  ('sent', 'Sent', Icons.send_rounded),
  ('drafts', 'Drafts', Icons.drafts_rounded),
  ('archive', 'Archive', Icons.archive_rounded),
];

class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  String _folder = 'inbox';
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  String get _owner {
    final u = context.read<AuthProvider>().user;
    return (u['Email'] ?? u['email'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await context.read<AuthProvider>().api.get(
        '/mail/messages',
        query: {
          'folder': _folder,
          if (_owner.isNotEmpty) 'mailboxOwner': _owner,
          'limit': 200,
        },
      );
      final list = raw is Map ? raw['data'] : raw;
      if (!mounted) return;
      setState(() => _messages = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : []);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your mailbox.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> msg, Map<String, dynamic> body) async {
    final id = (msg['_id'] ?? msg['id']).toString();
    try {
      await context.read<AuthProvider>().api.patch('/mail/messages/$id',
          data: {...body, if (_owner.isNotEmpty) 'mailboxOwner': _owner});
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _visible {
    if (_search.isEmpty) return _messages;
    final q = _search.toLowerCase();
    return _messages
        .where((m) => [m['subject'], m['from'], m['fromName'], m['bodyText'], m['to']]
            .join(' ')
            .toLowerCase()
            .contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final sent = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const MailComposeScreen()));
          if (sent == true) _load();
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Compose'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.canvas,
              title: const Text('Mailbox'),
              actions: [
                IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 6),
              ],
            ),
            SliverToBoxAdapter(child: _folderBar()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search mail…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _search = '')),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(child: ListSkeleton())
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Mailbox unavailable',
                  message: _error!,
                  tone: AppColors.danger,
                  onRetry: _load,
                ),
              )
            else if (_visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateMessage(
                  icon: Icons.mark_email_read_rounded,
                  title: 'Nothing in ${_folderLabel.toLowerCase()}',
                  message: 'Pull to refresh or compose a new message.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverList.separated(
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _tile(_visible[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _folderLabel =>
      _folders.firstWhere((f) => f.$1 == _folder).$2;

  Widget _folderBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _folders.map((f) {
          final selected = f.$1 == _folder;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _folder = f.$1);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand : context.surface,
                  borderRadius: BorderRadius.circular(AppSpace.rPill),
                  border: Border.all(
                      color: selected ? AppColors.brand : context.line),
                ),
                child: Row(
                  children: [
                    Icon(f.$3,
                        size: 16,
                        color: selected ? Colors.white : context.muted),
                    const SizedBox(width: 7),
                    Text(f.$2,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected ? Colors.white : context.inkSoft)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> m) {
    final outgoing = _folder == 'sent' || _folder == 'drafts';
    final whoRaw = outgoing
        ? (m['to'] is List ? (m['to'] as List).join(', ') : (m['to'] ?? '').toString())
        : (m['fromName'] ?? m['from'] ?? '').toString();
    final who = whoRaw.isEmpty ? 'Unknown' : whoRaw;
    final unread = m['read'] == false && !outgoing;
    final starred = m['starred'] == true;
    final subject = (m['subject'] ?? '(no subject)').toString();
    final preview = (m['bodyText'] ?? '').toString();

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        if (unread) {
          await _patch(m, {'read': true});
          setState(() => m['read'] = true);
        }
        if (!mounted) return;
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MailDetailScreen(message: m, owner: _owner),
          ),
        );
        if (changed == true) _load();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              InitialsAvatar(who, size: 46, icon: outgoing ? Icons.send_rounded : null),
              if (unread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outgoing ? 'To: $who' : who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            fontSize: 14.5,
                            color: context.ink),
                      ),
                    ),
                    Text(Fmt.relative(m['sentAt'] ?? m['createdAt']),
                        style: TextStyle(color: context.faint, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13.5,
                        color: unread ? context.ink : context.inkSoft)),
                if (preview.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.muted, fontSize: 12.5)),
                ],
                Row(
                  children: [
                    if (m['hasAttachments'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Icon(Icons.attach_file_rounded,
                            size: 14, color: context.faint),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
                starred ? Icons.star_rounded : Icons.star_outline_rounded,
                color: starred ? AppColors.warning : context.faint,
                size: 20),
            onPressed: () {
              setState(() => m['starred'] = !starred);
              _patch(m, {'starred': !starred});
            },
          ),
        ],
      ),
    );
  }
}

/// Full message reader with reply / star / archive / read actions.
class MailDetailScreen extends StatefulWidget {
  const MailDetailScreen({super.key, required this.message, required this.owner});
  final Map<String, dynamic> message;
  final String owner;

  @override
  State<MailDetailScreen> createState() => _MailDetailScreenState();
}

class _MailDetailScreenState extends State<MailDetailScreen> {
  late Map<String, dynamic> m = Map<String, dynamic>.from(widget.message);
  bool _changed = false;

  Future<void> _patch(Map<String, dynamic> body, {String? toast}) async {
    final id = (m['_id'] ?? m['id']).toString();
    setState(() => m.addAll(body));
    _changed = true;
    try {
      await context.read<AuthProvider>().api.patch('/mail/messages/$id', data: {
        ...body,
        if (widget.owner.isNotEmpty) 'mailboxOwner': widget.owner,
      });
      if (toast != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(toast)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final from = (m['fromName'] ?? m['from'] ?? 'Unknown').toString();
    final to = m['to'] is List
        ? (m['to'] as List).join(', ')
        : (m['to'] ?? '').toString();
    final body = (m['bodyText'] ?? '').toString();
    final starred = m['starred'] == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Message'),
          actions: [
            IconButton(
              tooltip: 'Star',
              icon: Icon(
                  starred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: starred ? AppColors.warning : null),
              onPressed: () => _patch({'starred': !starred}),
            ),
            IconButton(
              tooltip: 'Archive',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () async {
                final nav = Navigator.of(context);
                await _patch({'folder': 'archive'}, toast: 'Archived');
                if (mounted) nav.pop(true);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'unread') _patch({'read': false}, toast: 'Marked unread');
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'unread', child: Text('Mark as unread')),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _reply,
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: const Text('Reply'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text((m['subject'] ?? '(no subject)').toString(),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 16),
            Row(
              children: [
                InitialsAvatar(from, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(from,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5)),
                      if (to.isNotEmpty)
                        Text('to $to',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: context.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Text(Fmt.date(m['sentAt'] ?? m['createdAt']),
                    style: TextStyle(color: context.faint, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            SelectableText(
              body.isEmpty ? '(No text content)' : body,
              style: const TextStyle(fontSize: 15, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reply() async {
    final from = (m['from'] ?? '').toString();
    final subject = (m['subject'] ?? '').toString();
    final replySubject =
        subject.toLowerCase().startsWith('re:') ? subject : 'Re: $subject';
    final quote =
        '\n\n———\nOn ${Fmt.date(m['sentAt'] ?? m['createdAt'])}, $from wrote:\n${(m['bodyText'] ?? '').toString()}';
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MailComposeScreen(
          to: from,
          subject: replySubject,
          quoted: quote,
          threadId: (m['threadId'] ?? '').toString(),
        ),
      ),
    );
    if (sent == true && mounted) {
      _changed = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reply sent')));
    }
  }
}
