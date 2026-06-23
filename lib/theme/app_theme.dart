import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Theme-independent brand + semantic colours. Neutrals live in [Palette] so
/// they can flip between light and dark.
class AppColors {
  AppColors._();

  // Brand
  static const brand = Color(0xFF7C3AED); // violet-600
  static const brandBright = Color(0xFF8B5CF6); // violet-500
  static const brandDeep = Color(0xFF4C1D95); // violet-900
  static const accent = Color(0xFFEC4899); // pink-500
  static const accentDeep = Color(0xFFDB2777); // pink-600

  // Semantic (work on both light and dark surfaces)
  static const success = Color(0xFF15A36E);
  static const warning = Color(0xFFE08600);
  static const danger = Color(0xFFF43F5E);
  static const info = Color(0xFF3B82F6);

  // Light-mode neutral defaults (also the fallback tone source).
  static const muted = Color(0xFF64748B);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBright, accentDeep],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFDB2777)],
  );
}

class AppSpace {
  AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;

  static const rSm = 12.0;
  static const rMd = 16.0;
  static const rLg = 20.0;
  static const rXl = 26.0;
  static const rPill = 999.0;
}

class AppShadow {
  AppShadow._();
  static const card = [
    BoxShadow(
      color: Color(0x0F1E293B),
      blurRadius: 18,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];
  static const raised = [
    BoxShadow(
      color: Color(0x2E4C1D95),
      blurRadius: 28,
      offset: Offset(0, 14),
      spreadRadius: -10,
    ),
  ];
}

/// Theme-aware neutral palette, exposed as a [ThemeExtension] so widgets can
/// read the right tone for the active brightness via the [PaletteContext]
/// getters (e.g. `context.surface`).
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.faint,
    required this.line,
    required this.lineStrong,
    required this.surface,
    required this.surfaceAlt,
    required this.canvas,
    required this.cardShadow,
  });

  final Color ink; // primary text
  final Color inkSoft; // secondary text
  final Color muted; // tertiary text
  final Color faint; // disabled / icons
  final Color line; // hairline border
  final Color lineStrong;
  final Color surface; // cards
  final Color surfaceAlt; // input fill / subtle fills
  final Color canvas; // scaffold background
  final List<BoxShadow> cardShadow;

  static const light = Palette(
    ink: Color(0xFF0F172A),
    inkSoft: Color(0xFF334155),
    muted: Color(0xFF64748B),
    faint: Color(0xFF94A3B8),
    line: Color(0xFFE9EDF3),
    lineStrong: Color(0xFFD8DFEA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F5F9),
    canvas: Color(0xFFF6F7FB),
    cardShadow: AppShadow.card,
  );

  static const dark = Palette(
    ink: Color(0xFFF1F5F9),
    inkSoft: Color(0xFFCBD5E1),
    muted: Color(0xFF94A3B8),
    faint: Color(0xFF6B7689),
    line: Color(0xFF273046),
    lineStrong: Color(0xFF38415C),
    surface: Color(0xFF161D2F),
    surfaceAlt: Color(0xFF1F2839),
    canvas: Color(0xFF0C111E),
    cardShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 20,
        offset: Offset(0, 10),
        spreadRadius: -8,
      ),
    ],
  );

  @override
  Palette copyWith({
    Color? ink,
    Color? inkSoft,
    Color? muted,
    Color? faint,
    Color? line,
    Color? lineStrong,
    Color? surface,
    Color? surfaceAlt,
    Color? canvas,
    List<BoxShadow>? cardShadow,
  }) =>
      Palette(
        ink: ink ?? this.ink,
        inkSoft: inkSoft ?? this.inkSoft,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        line: line ?? this.line,
        lineStrong: lineStrong ?? this.lineStrong,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        canvas: canvas ?? this.canvas,
        cardShadow: cardShadow ?? this.cardShadow,
      );

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    return Palette(
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// Ergonomic access to the active [Palette] and quick brightness check.
extension PaletteContext on BuildContext {
  Palette get pal =>
      Theme.of(this).extension<Palette>() ?? Palette.light;
  Color get ink => pal.ink;
  Color get inkSoft => pal.inkSoft;
  Color get muted => pal.muted;
  Color get faint => pal.faint;
  Color get line => pal.line;
  Color get lineStrong => pal.lineStrong;
  Color get surface => pal.surface;
  Color get surfaceAlt => pal.surfaceAlt;
  Color get canvas => pal.canvas;
  List<BoxShadow> get cardShadow => pal.cardShadow;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light, Palette.light);
  static ThemeData dark() => _build(Brightness.dark, Palette.dark);

  static ThemeData _build(Brightness brightness, Palette p) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      primary: isDark ? AppColors.brandBright : AppColors.brand,
      secondary: AppColors.accent,
      surface: p.surface,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, p),
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.ink,
        titleTextStyle: TextStyle(
          color: p.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.rLg),
          side: BorderSide(color: p.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: p.faint),
        labelStyle: TextStyle(color: p.muted),
        floatingLabelStyle: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: p.faint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.rMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.rMd),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.rMd),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.rMd),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.rMd),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.rMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.brandBright : AppColors.brand,
          side: BorderSide(color: p.lineStrong),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.rMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.brandBright : AppColors.brand,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 6,
        extendedTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand.withValues(alpha: 0.16),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.brandBright : AppColors.brand)
                : p.faint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.brandBright : AppColors.brand)
                : p.muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: AppColors.brand.withValues(alpha: 0.16),
        selectedIconTheme:
            IconThemeData(color: isDark ? AppColors.brandBright : AppColors.brand),
        unselectedIconTheme: IconThemeData(color: p.faint),
        selectedLabelTextStyle: TextStyle(
          color: isDark ? AppColors.brandBright : AppColors.brand,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: p.muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          color: p.ink,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.rPill),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1F2839) : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.rMd),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        titleTextStyle: TextStyle(
          color: p.ink,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(color: p.muted, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpace.rXl)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.surface),
      datePickerTheme: DatePickerThemeData(backgroundColor: p.surface),
      timePickerTheme: TimePickerThemeData(backgroundColor: p.surface),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      popupMenuTheme: PopupMenuThemeData(color: p.surface),
    );
  }

  static TextTheme _textTheme(TextTheme base, Palette p) {
    TextStyle s(TextStyle? style, double size, FontWeight weight,
            {double spacing = 0, Color? color, double? height}) =>
        (style ?? const TextStyle()).copyWith(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color ?? p.ink,
          height: height,
        );
    return base.copyWith(
      displaySmall: s(base.displaySmall, 30, FontWeight.w800, spacing: -0.5),
      headlineMedium: s(base.headlineMedium, 26, FontWeight.w800, spacing: -0.4),
      headlineSmall: s(base.headlineSmall, 22, FontWeight.w800, spacing: -0.3),
      titleLarge: s(base.titleLarge, 19, FontWeight.w800, spacing: -0.2),
      titleMedium: s(base.titleMedium, 16, FontWeight.w700),
      titleSmall: s(base.titleSmall, 14, FontWeight.w700),
      bodyLarge: s(base.bodyLarge, 15.5, FontWeight.w500, height: 1.4),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w500,
          color: p.inkSoft, height: 1.4),
      bodySmall: s(base.bodySmall, 12.5, FontWeight.w500, color: p.muted),
      labelLarge: s(base.labelLarge, 14, FontWeight.w700),
    );
  }
}
