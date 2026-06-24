import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// A row of quick contact buttons (Call / WhatsApp / Email) for a lead or
/// customer. Only renders the actions for the data that's present.
class ContactActions extends StatelessWidget {
  const ContactActions({super.key, this.phone, this.email});
  final String? phone;
  final String? email;

  static const _whatsappGreen = Color(0xFF25D366);

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t open ${uri.scheme}')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app available for this action')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = (phone ?? '').trim();
    final e = (email ?? '').trim();
    final buttons = <Widget>[];

    if (p.isNotEmpty) {
      buttons.add(_btn(context, Icons.call_rounded, 'Call', AppColors.success,
          () => _launch(context, Uri.parse('tel:${_digits(p)}'))));
      buttons.add(_btn(context, Icons.chat_rounded, 'WhatsApp', _whatsappGreen,
          () => _launch(
              context, Uri.parse('https://wa.me/${_digits(p).replaceAll('+', '')}'))));
    }
    if (e.isNotEmpty) {
      buttons.add(_btn(context, Icons.email_rounded, 'Email', AppColors.info,
          () => _launch(context, Uri(scheme: 'mailto', path: e))));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();

    final spaced = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      spaced.add(Expanded(child: buttons[i]));
      if (i != buttons.length - 1) spaced.add(const SizedBox(width: 10));
    }
    return Row(children: spaced);
  }

  Widget _btn(BuildContext context, IconData icon, String label, Color tone,
      VoidCallback onTap) {
    return Material(
      color: tone.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpace.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpace.rMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tone, size: 21),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: tone, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
