import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_controller.dart';
import 'providers/notification_center.dart';
import 'screens/login_screen.dart';
import 'screens/operations_shell.dart';
import 'services/navigation_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  final theme = ThemeController();
  await Future.wait([auth.restoreSession(), theme.restore()]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider(create: (_) => NotificationCenter()),
      ],
      child: const TripClubAdminApp(),
    ),
  );
}

class TripClubAdminApp extends StatelessWidget {
  const TripClubAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: 'TripClub Operations',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.mode,
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          child: auth.isAuthenticated
              ? const OperationsShell(key: ValueKey('shell'))
              : const LoginScreen(key: ValueKey('login')),
        ),
      ),
    );
  }
}
