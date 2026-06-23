import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A pinned bottom action bar carrying a form's primary submit button so it
/// is always reachable above the keyboard.
class SubmitBar extends StatelessWidget {
  const SubmitBar({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.saving,
    this.helper,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool saving;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(top: BorderSide(color: context.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (helper != null)
              Expanded(
                child: Text(helper!,
                    style: TextStyle(
                        color: context.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
            if (helper != null) const SizedBox(width: 12),
            Expanded(
              flex: helper != null ? 2 : 1,
              child: FilledButton.icon(
                onPressed: saving ? null : onPressed,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(icon, size: 19),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled group heading used inside scrolling forms.
class FormSection extends StatelessWidget {
  const FormSection(this.title, {super.key, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: AppColors.brand),
            const SizedBox(width: 8),
          ],
          Text(title.toUpperCase(),
              style: TextStyle(
                  color: context.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}
