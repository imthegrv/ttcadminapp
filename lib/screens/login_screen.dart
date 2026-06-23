import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _backupCode = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final formCard = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppSpace.rXl),
          boxShadow: AppShadow.raised,
        ),
        padding: const EdgeInsets.all(30),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: auth.requires2fa ? _twoFactorForm(auth) : _loginForm(auth),
        ),
      ),
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                Expanded(child: _brandPanel()),
                Expanded(
                  child: Container(
                    color: context.canvas,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(32),
                    child: SingleChildScrollView(child: formCard),
                  ),
                ),
              ],
            )
          : Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: formCard,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _brandPanel() => Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.flight_takeoff_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 28),
            const Text(
              'TripClub\nOperations',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Run leads, bookings, invoices and your team — from anywhere, on any device.',
              style: TextStyle(
                  color: Color(0xFFEDE4FF), fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 36),
            ..._highlights(),
          ],
        ),
      );

  List<Widget> _highlights() => const [
        _Highlight(Icons.bolt_rounded, 'Create leads, bookings & invoices fast'),
        SizedBox(height: 14),
        _Highlight(Icons.notifications_active_rounded,
            'Real-time push for new activity'),
        SizedBox(height: 14),
        _Highlight(Icons.lock_rounded, 'Secured with 2FA & encrypted sessions'),
      ];

  Widget _heading(String title, String subtitle, {bool compact = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.flight_takeoff_rounded,
                  color: Colors.white),
            ),
          if (compact) const SizedBox(height: 18),
          Text(title,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: context.muted, fontSize: 14.5)),
          const SizedBox(height: 26),
        ],
      );

  Widget _loginForm(AuthProvider auth) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Welcome back', 'Sign in to your operations workspace',
            compact: !wide),
        TextField(
          controller: _company,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Company ID',
            prefixIcon: Icon(Icons.business_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Work email',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: _hidePassword,
          onSubmitted: (_) => _submit(auth),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(_hidePassword
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded),
            ),
          ),
        ),
        _error(auth),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: auth.isLoading ? null : () => _submit(auth),
          child: auth.isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('Sign in'),
                ),
        ),
      ],
    );
  }

  Widget _twoFactorForm(AuthProvider auth) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Verify your identity',
            'Enter your authenticator code or a saved backup code',
            compact: !wide),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType:
              _backupCode ? TextInputType.text : TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 4),
          onSubmitted: (_) =>
              auth.verify2fa(_code.text, backupCode: _backupCode),
          decoration: InputDecoration(
            labelText: _backupCode ? 'Backup code' : '6-digit code',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.brand,
          title: const Text('Use a backup code',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          value: _backupCode,
          onChanged: (value) => setState(() => _backupCode = value),
        ),
        _error(auth),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: auth.isLoading
              ? null
              : () => auth.verify2fa(_code.text, backupCode: _backupCode),
          child: auth.isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Verify & continue'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: auth.isLoading ? null : auth.cancel2fa,
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _error(AuthProvider auth) {
    if (auth.errorMessage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpace.rSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(auth.errorMessage!,
                style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(AuthProvider auth) async {
    if (_company.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Company ID, email and password are required.')),
      );
      return;
    }
    await auth.login(_email.text, _password.text, _company.text);
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFEDE4FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      );
}
