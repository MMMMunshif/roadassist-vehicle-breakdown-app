part of '../../app.dart';

/// Shared visual foundation. Authentication, navigation and data stay in app.dart.
ThemeData buildRoadAssistTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: raBlue,
    brightness: brightness,
    primary: dark ? const Color(0xFF9ACBFF) : raBlue,
    secondary: dark ? const Color(0xFF80D9CC) : const Color(0xFF007D70),
    surface: dark ? const Color(0xFF111D2B) : Colors.white,
    error: dark ? const Color(0xFFFFB4AB) : raDanger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final text = base.textTheme.copyWith(
    headlineMedium: RaText.display.copyWith(color: colors.onSurface),
    headlineSmall: RaText.headline.copyWith(color: colors.onSurface),
    titleLarge: RaText.headline.copyWith(fontSize: 20, color: colors.onSurface),
    titleMedium: RaText.title.copyWith(fontSize: 17, color: colors.onSurface),
    bodyLarge: RaText.body.copyWith(fontSize: 16, color: colors.onSurface),
    bodyMedium: RaText.body.copyWith(color: colors.onSurface),
    bodySmall: RaText.bodyMuted.copyWith(color: colors.onSurfaceVariant),
    labelLarge: RaText.label.copyWith(fontSize: 14, color: colors.onSurface),
    labelSmall: RaText.caption.copyWith(color: colors.onSurfaceVariant),
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(RaRadius.md),
  );
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(RaRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0B1420) : raCanvas,
    textTheme: text,
    dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaRadius.lg),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: shape,
        side: BorderSide(color: colors.outlineVariant),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      labelStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      helperStyle: text.bodySmall,
      errorMaxLines: 3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(colors.outlineVariant),
      enabledBorder: border(colors.outlineVariant),
      focusedBorder: border(colors.primary, 2),
      errorBorder: border(colors.error),
      focusedErrorBorder: border(colors.error, 2),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: text.labelLarge,
      side: BorderSide(color: colors.outlineVariant),
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      elevation: 0,
      height: 76,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: colors.onInverseSurface,
      ),
      actionTextColor: colors.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
  );
}
