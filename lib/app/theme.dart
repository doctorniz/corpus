import 'package:material_ui/material_ui.dart';

/// The palette shared with Mentis: neutral greys and one indigo accent.
@immutable
class CorpusColors extends ThemeExtension<CorpusColors> {
  const CorpusColors({
    required this.bg,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.fg,
    required this.fgSecondary,
    required this.fgTertiary,
    required this.fgMuted,
    required this.border,
    required this.accent,
    required this.accentLight,
    required this.accentFg,
    required this.danger,
    required this.warning,
    required this.success,
    required this.pink,
    required this.pinkLight,
    required this.blue,
  });

  final Color bg;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color fg;
  final Color fgSecondary;
  final Color fgTertiary;
  final Color fgMuted;
  final Color border;
  final Color accent;
  final Color accentLight;
  final Color accentFg;
  final Color danger;
  final Color warning;
  final Color success;
  final Color pink;
  final Color pinkLight;
  final Color blue;

  static const light = CorpusColors(
    bg: Color(0xFFFFFFFF),
    bgSecondary: Color(0xFFF8F9FA),
    bgTertiary: Color(0xFFF1F3F5),
    fg: Color(0xFF212529),
    fgSecondary: Color(0xFF495057),
    fgTertiary: Color(0xFF868E96),
    fgMuted: Color(0xFFADB5BD),
    border: Color(0xFFDEE2E6),
    accent: Color(0xFF5C4EE5),
    accentLight: Color(0xFFECE9FD),
    accentFg: Color(0xFFFFFFFF),
    danger: Color(0xFFE03131),
    warning: Color(0xFFF08C00),
    success: Color(0xFF2F9E44),
    pink: Color(0xFFD6336C),
    pinkLight: Color(0xFFFCC2D7),
    blue: Color(0xFF1C7ED6),
  );

  static const dark = CorpusColors(
    bg: Color(0xFF1A1B1E),
    bgSecondary: Color(0xFF25262B),
    bgTertiary: Color(0xFF2C2E33),
    fg: Color(0xFFE9ECEF),
    fgSecondary: Color(0xFFCED4DA),
    fgTertiary: Color(0xFF909296),
    fgMuted: Color(0xFF5C5F66),
    border: Color(0xFF373A40),
    accent: Color(0xFF7C6EF5),
    accentLight: Color(0xFF2B2541),
    accentFg: Color(0xFFFFFFFF),
    danger: Color(0xFFFF6B6B),
    warning: Color(0xFFFFA94D),
    success: Color(0xFF51CF66),
    pink: Color(0xFFF06595),
    pinkLight: Color(0xFF4A1531),
    blue: Color(0xFF4DABF7),
  );

  @override
  CorpusColors copyWith() => this;

  @override
  CorpusColors lerp(CorpusColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension CorpusTheme on BuildContext {
  CorpusColors get colors => Theme.of(this).extension<CorpusColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? CorpusColors.dark
      : CorpusColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(
        primary: c.accent,
        onPrimary: c.accentFg,
        primaryContainer: c.accentLight,
        onPrimaryContainer: c.accent,
        surface: c.bg,
        onSurface: c.fg,
        onSurfaceVariant: c.fgSecondary,
        surfaceContainerLowest: c.bg,
        surfaceContainerLow: c.bgSecondary,
        surfaceContainer: c.bgSecondary,
        surfaceContainerHigh: c.bgTertiary,
        surfaceContainerHighest: c.bgTertiary,
        outline: c.border,
        outlineVariant: c.border,
        error: c.danger,
      );

  final radius = BorderRadius.circular(8);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: c.fg, displayColor: c.fg)
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: c.fg,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: c.fg,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: c.fg,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: c.fg,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: c.fg,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: c.fgSecondary,
      textColor: c.fg,
      subtitleTextStyle: TextStyle(color: c.fgTertiary, fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bgSecondary,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: TextStyle(color: c.fgTertiary),
      hintStyle: TextStyle(color: c.fgMuted),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentFg,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.fg,
        minimumSize: const Size(0, 46),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.bgSecondary,
      selectedColor: c.accentLight,
      side: BorderSide(color: c.border),
      labelStyle: TextStyle(color: c.fg, fontSize: 13),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.fg,
      contentTextStyle: TextStyle(color: c.bg),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: c.accentLight,
        selectedForegroundColor: c.accent,
        foregroundColor: c.fgSecondary,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.bgTertiary,
      circularTrackColor: c.bgTertiary,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.bgTertiary,
      ),
      thumbColor: WidgetStatePropertyAll(c.accentFg),
      trackOutlineColor: WidgetStatePropertyAll(c.border),
    ),
  );
}
