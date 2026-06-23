import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/form_kit.dart';

class MailComposeScreen extends StatefulWidget {
  const MailComposeScreen({
    super.key,
    this.to = '',
    this.subject = '',
    this.quoted = '',
    this.threadId = '',
  });

  /// Pre-filled recipient (used when replying).
  final String to;
  final String subject;
  final String quoted;
  final String threadId;

  @override
  State<MailComposeScreen> createState() => _MailComposeScreenState();
}

class _MailComposeScreenState extends State<MailComposeScreen> {
  late final TextEditingController _to = TextEditingController(text: widget.to);
  final _cc = TextEditingController();
  late final TextEditingController _subject =
      TextEditingController(text: widget.subject);
  late final TextEditingController _body =
      TextEditingController(text: widget.quoted);
  bool _showCc = false;
  bool _sending = false;

  String get _owner {
    final u = context.read<AuthProvider>().user;
    return (u['Email'] ?? u['email'] ?? '').toString();
  }

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.to.isEmpty ? 'New message' : 'Reply'),
        actions: [
          if (!_showCc)
            TextButton(
              onPressed: () => setState(() => _showCc = true),
              child: const Text('Cc'),
            ),
        ],
      ),
      bottomNavigationBar: SubmitBar(
        label: 'Send',
        icon: Icons.send_rounded,
        saving: _sending,
        onPressed: _send,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          TextField(
            controller: _to,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'To',
              prefixIcon: Icon(Icons.person_outline_rounded),
              helperText: 'Separate multiple addresses with commas',
            ),
          ),
          const SizedBox(height: 14),
          if (_showCc) ...[
            TextField(
              controller: _cc,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Cc',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _subject,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.subject_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: 20,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_to.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one recipient.')),
      );
      return;
    }
    if (_subject.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A subject is required.')),
      );
      return;
    }
    setState(() => _sending = true);
    final bodyText = _body.text.trim();
    final form = FormData.fromMap({
      'to': _to.text.trim(),
      if (_cc.text.trim().isNotEmpty) 'cc': _cc.text.trim(),
      'subject': _subject.text.trim(),
      'bodyText': bodyText,
      'bodyHtml':
          '<div>${bodyText.replaceAll('\n', '<br/>')}</div>',
      'fromName': context.read<AuthProvider>().displayName,
      if (_owner.isNotEmpty) 'mailboxOwner': _owner,
      if (widget.threadId.isNotEmpty) 'threadId': widget.threadId,
    });
    try {
      await context
          .read<AuthProvider>()
          .api
          .post('/mail/messages/send', data: form);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    }
  }
}
