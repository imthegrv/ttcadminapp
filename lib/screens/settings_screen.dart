import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_controller.dart';
import '../providers/notification_center.dart';
import '../services/push_notification_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeController>();
    final email = (auth.user['Email'] ?? auth.user['email'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Profile header
          AppCard(
            child: Row(
              children: [
                InitialsAvatar(auth.displayName, size: 58),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.displayName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(email,
                            style: TextStyle(
                                color: context.muted, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Appearance
          _section(context, 'Appearance'),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final m in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppColors.brand,
                    value: m,
                    groupValue: theme.mode,
                    onChanged: (v) => theme.setMode(v ?? ThemeMode.system),
                    title: Text(switch (m) {
                      ThemeMode.system => 'System default',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    }),
                    secondary: Icon(switch (m) {
                      ThemeMode.system => Icons.brightness_auto_rounded,
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                    }, color: context.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // About
          _section(context, 'About'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _aboutRow(context, 'App version', '1.0.0'),
                Divider(color: context.line, height: 1),
                _aboutRow(context, 'Company ID',
                    auth.companyId.isEmpty ? '—' : auth.companyId),
                Divider(color: context.line, height: 1),
                _aboutRow(context, 'API', Uri.parse(AppConfig.apiBaseUrl).host),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () => _signOut(context, auth),
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t.toUpperCase(),
            style: TextStyle(
                color: context.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );

  Widget _aboutRow(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(color: context.muted, fontSize: 13.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13.5)),
          ],
        ),
      );

  Future<void> _signOut(BuildContext context, AuthProvider auth) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await PushNotificationService.instance.unregister(auth.api);
    SocketService.instance.dispose();
    if (context.mounted) context.read<NotificationCenter>().unbind();
    await auth.logout();
  }
}
