import 'package:flutter/material.dart';

/// Moops brand palette (from moops.in) arranged as neo-brutalist tokens.
///
/// Every surface is outlined in [outline] and casts a hard [shadow] offset
/// shadow; pastel blocks ([butter], [blush], [sky], [sage]) give each card one
/// clear colour. Read it from widgets with `context.stride`.
@immutable
class StrideColors extends ThemeExtension<StrideColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color outline;
  final Color shadow;
  final Color brand;
  final Color onBrand;
  final Color butter;
  final Color blush;
  final Color sky;
  final Color sage;
  final Color coral;
  final Color go;
  final Color pause;
  final Color stop;
  /// Text on pastel blocks; pastels stay light-ish in both themes' accents.
  final Color onPastel;

  const StrideColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.outline,
    required this.shadow,
    required this.brand,
    required this.onBrand,
    required this.butter,
    required this.blush,
    required this.sky,
    required this.sage,
    required this.coral,
    required this.go,
    required this.pause,
    required this.stop,
    required this.onPastel,
  });

  static const light = StrideColors(
    background: Color(0xFFF8F8F3),
    surface: Color(0xFFFDFDFA),
    surfaceAlt: Color(0xFFEFF0E8),
    ink: Color(0xFF211F1B),
    inkMuted: Color(0xFF57534A),
    outline: Color(0xFF211F1B),
    shadow: Color(0xFF211F1B),
    brand: Color(0xFF3F6B35),
    onBrand: Color(0xFFF8F8F3),
    butter: Color(0xFFFFE58A),
    blush: Color(0xFFFFDCE5),
    sky: Color(0xFFC8E4FF),
    sage: Color(0xFFE5F0CE),
    coral: Color(0xFFD96979),
    go: Color(0xFF9CC283),
    pause: Color(0xFFFFE58A),
    stop: Color(0xFFF4A3B5),
    onPastel: Color(0xFF211F1B),
  );

  static const dark = StrideColors(
    background: Color(0xFF0F130B),
    surface: Color(0xFF222B1A),
    surfaceAlt: Color(0xFF2E3A25),
    ink: Color(0xFFFBF7EC),
    inkMuted: Color(0xFFD6D3C1),
    outline: Color(0xFFFBF7EC),
    shadow: Color(0xFF000000),
    brand: Color(0xFFA9C06A),
    onBrand: Color(0xFF0F130B),
    butter: Color(0xFF3D3620),
    blush: Color(0xFF4A2B3B),
    sky: Color(0xFF243749),
    sage: Color(0xFF33431F),
    coral: Color(0xFFF79DAC),
    go: Color(0xFFA9C06A),
    pause: Color(0xFFEFD56A),
    stop: Color(0xFFF9AFC7),
    onPastel: Color(0xFFFBF7EC),
  );

  @override
  StrideColors copyWith() => this;

  @override
  StrideColors lerp(StrideColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StrideColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      outline: l(outline, other.outline),
      shadow: l(shadow, other.shadow),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      butter: l(butter, other.butter),
      blush: l(blush, other.blush),
      sky: l(sky, other.sky),
      sage: l(sage, other.sage),
      coral: l(coral, other.coral),
      go: l(go, other.go),
      pause: l(pause, other.pause),
      stop: l(stop, other.stop),
      onPastel: l(onPastel, other.onPastel),
    );
  }
}

/// Ink or cream, whichever reads on [background]. Pastels are light in the
/// light theme but go/pause/stop stay light in dark mode too, so a fixed
/// "on pastel" colour can't be right for every block.
Color textOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? const Color(0xFFFBF7EC)
        : const Color(0xFF211F1B);

extension StrideTheme on BuildContext {
  StrideColors get stride => Theme.of(this).extension<StrideColors>()!;
}

/// Shared geometry so every block lines up: one outline weight, one shadow
/// offset, radii on a small scale.
abstract final class Brutal {
  static const double outline = 2.5;
  static const double shadow = 4;
  static const double radius = 20;
  static const double radiusSmall = 14;
  static const double radiusPill = 999;

  static BoxDecoration box(
    StrideColors c, {
    Color? color,
    double radius = Brutal.radius,
    double shadow = Brutal.shadow,
  }) {
    return BoxDecoration(
      color: color ?? c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.outline, width: outline),
      boxShadow: shadow == 0
          ? null
          : [BoxShadow(color: c.shadow, offset: Offset(shadow, shadow))],
    );
  }
}

class AppTheme {
  static const String display = 'Fraunces';
  static const String body = 'Geist';
  static const String mono = 'GeistMono';

  static ThemeData get lightTheme => _build(StrideColors.light, Brightness.light);
  static ThemeData get darkTheme => _build(StrideColors.dark, Brightness.dark);

  static ThemeData _build(StrideColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, fontFamily: body);
    final outlineSide = BorderSide(color: c.outline, width: Brutal.outline);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Brutal.radiusSmall),
      side: outlineSide,
    );

    TextStyle d(double size, {FontWeight w = FontWeight.w700, double h = 1.05}) =>
        TextStyle(fontFamily: display, fontSize: size, fontWeight: w, height: h, color: c.ink, letterSpacing: -0.5);
    TextStyle b(double size, {FontWeight w = FontWeight.w400, Color? color, double? ls}) =>
        TextStyle(fontFamily: body, fontSize: size, fontWeight: w, color: color ?? c.ink, letterSpacing: ls);

    final textTheme = base.textTheme.copyWith(
      displayLarge: d(40, w: FontWeight.w800),
      displayMedium: d(32, w: FontWeight.w800),
      displaySmall: d(26),
      headlineLarge: d(28),
      headlineMedium: d(24),
      headlineSmall: d(20),
      titleLarge: b(19, w: FontWeight.w700),
      titleMedium: b(16, w: FontWeight.w700),
      titleSmall: b(14, w: FontWeight.w600),
      bodyLarge: b(16),
      bodyMedium: b(14, color: c.inkMuted),
      bodySmall: b(12, color: c.inkMuted),
      labelLarge: b(15, w: FontWeight.w700, ls: 0.2),
      labelMedium: TextStyle(fontFamily: mono, fontSize: 12, fontWeight: FontWeight.w600, color: c.ink, letterSpacing: 0.8),
      labelSmall: TextStyle(fontFamily: mono, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted, letterSpacing: 1.0),
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      primaryColor: c.brand,
      dividerColor: c.outline.withValues(alpha: 0.15),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.brand,
        onPrimary: c.onBrand,
        secondary: c.coral,
        onSecondary: c.onPastel,
        error: c.coral,
        onError: c.onPastel,
        surface: c.surface,
        onSurface: c.ink,
        outline: c.outline,
      ),
      extensions: [c],
      textTheme: textTheme,
      iconTheme: IconThemeData(color: c.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.ink,
        titleTextStyle: d(26),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: rounded,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: outlineSide,
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          textStyle: textTheme.labelLarge?.copyWith(decoration: TextDecoration.underline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: b(14, color: c.inkMuted, w: FontWeight.w500),
        floatingLabelStyle: b(14, w: FontWeight.w700),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Brutal.radiusSmall), borderSide: outlineSide),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Brutal.radiusSmall), borderSide: outlineSide),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: BorderSide(color: c.brand, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: BorderSide(color: c.coral, width: 3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          borderSide: BorderSide(color: c.coral, width: 3),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Brutal.radius), side: outlineSide),
        titleTextStyle: d(24),
        contentTextStyle: b(15, color: c.inkMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: outlineSide,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: b(14, w: FontWeight.w600, color: c.background),
        // Snackbars invert the theme (ink background), so pick an action
        // colour that reads on that inverted ground.
        actionTextColor:
            brightness == Brightness.light ? c.butter : StrideColors.light.brand,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Brutal.radiusSmall)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(c.outline),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onBrand : c.outline),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.brand : c.surfaceAlt),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(outlineSide),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? c.butter : c.surface),
          foregroundColor: WidgetStatePropertyAll(c.ink),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
      listTileTheme: ListTileThemeData(
        iconColor: c.ink,
        textColor: c.ink,
        titleTextStyle: b(16, w: FontWeight.w600),
      ),
    );
  }
}
