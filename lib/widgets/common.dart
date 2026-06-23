import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/status_palette.dart';
import '../utils/formatters.dart';

/// A small coloured pill for status values.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.dense = false});
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = StatusPalette.tone(label);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpace.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            Fmt.humanize(label),
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient initials avatar — deterministic colour from the seed string.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 44, this.icon});
  final String name;
  final double size;
  final IconData? icon;

  static const _palettes = [
    [Color(0xFF7C3AED), Color(0xFFEC4899)],
    [Color(0xFF2563EB), Color(0xFF06B6D4)],
    [Color(0xFF15A36E), Color(0xFF84CC16)],
    [Color(0xFFD97706), Color(0xFFF59E0B)],
    [Color(0xFFE11D48), Color(0xFFF97316)],
    [Color(0xFF4F46E5), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context) {
    final seed = name.isEmpty
        ? 0
        : name.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length;
    final colors = _palettes[seed];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.46)
          : Text(
              Fmt.initials(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
            ),
    );
  }
}

/// A rounded, hairline-bordered surface with optional tap + soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.radius = AppSpace.rLg,
    this.shadow = true,
    this.color,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      decoration: BoxDecoration(
        color: color ?? context.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.line),
        boxShadow: shadow ? context.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return decorated;
  }
}

/// Section title with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.subtitle});
  final String title;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Full-screen friendly empty / error message with a retry affordance.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone ?? context.faint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 34, color: tone),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton block used in loading lists.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final base = context.surfaceAlt;
        final highlight =
            context.isDark ? const Color(0xFF2C3650) : const Color(0xFFE6EBF2);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton placeholder that mimics a list of record cards.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppSpace.rLg),
          border: Border.all(color: context.line),
        ),
        child: Row(
          children: [
            const Skeleton(width: 44, height: 44, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 160, height: 13),
                  SizedBox(height: 9),
                  Skeleton(width: 110, height: 11),
                ],
              ),
            ),
            const Skeleton(width: 54, height: 22, radius: 999),
          ],
        ),
      ),
    );
  }
}
