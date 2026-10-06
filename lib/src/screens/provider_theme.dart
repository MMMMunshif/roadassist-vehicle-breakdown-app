part of '../screens.dart';

// Provider-only colours based on the deep blue, glass-panel visual language
// used by the provider dashboard reference. Keeping these tokens separate
// prevents provider styling from leaking into the driver and admin journeys.
const providerNavy = Color(0xFF0B2858);
const providerRoyalBlue = Color(0xFF155DBF);
const providerAction = Color(0xFF4A9AF4);
const providerActionPressed = Color(0xFF2F7ED8);
const providerSurface = Color(0xE63A5F91);
const providerSurfaceStrong = Color(0xF12B4F82);
const providerBorder = Color(0xFF718BAE);
const providerText = Color(0xFFF7F9FD);
const providerTextMuted = Color(0xFFBECBDD);
const providerSuccess = Color(0xFF45D6A0);
const providerDanger = Color(0xFFFF6B6B);

class ProviderScaffold extends StatelessWidget {
  const ProviderScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final scheme = const ColorScheme.dark(
      primary: providerAction,
      onPrimary: Colors.white,
      secondary: Color(0xFF8BC4FF),
      onSecondary: providerNavy,
      error: providerDanger,
      onError: Colors.white,
      surface: providerSurface,
      onSurface: providerText,
      onSurfaceVariant: providerTextMuted,
      outline: providerBorder,
    );
    final providerTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: providerNavy,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineMedium: RaText.display,
        headlineSmall: RaText.headline,
        titleMedium: RaText.title,
        bodyMedium: RaText.body,
        bodySmall: RaText.bodyMuted,
        labelLarge: RaText.label,
      ).apply(bodyColor: providerText, displayColor: providerText),
      iconTheme: const IconThemeData(color: providerText),
      dividerTheme: const DividerThemeData(color: providerBorder, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: providerText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: providerText,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: providerText),
      ),
      cardTheme: CardThemeData(
        color: providerSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: providerBorder),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFDCE8F8),
        textColor: providerText,
        subtitleTextStyle: TextStyle(color: providerTextMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: providerSurfaceStrong,
        selectedColor: providerAction,
        disabledColor: providerSurface,
        labelStyle: const TextStyle(
          color: providerText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: providerBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaRadius.pill),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: providerAction,
          disabledBackgroundColor: providerAction.withValues(alpha: .38),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: providerText,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: providerBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFA8D3FF),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x334A9AF4),
          foregroundColor: providerText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.md),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? providerSuccess
              : const Color(0xFF657A99),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: providerSurfaceStrong,
        hintStyle: const TextStyle(color: providerTextMuted),
        labelStyle: const TextStyle(color: providerTextMuted),
        prefixIconColor: const Color(0xFFDCE8F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RaRadius.md),
          borderSide: const BorderSide(color: providerBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RaRadius.md),
          borderSide: const BorderSide(color: providerBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RaRadius.md),
          borderSide: const BorderSide(color: providerAction, width: 1.8),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xF20A244F),
        indicatorColor: Color(0xFF3A6499),
        elevation: 0,
        height: 70,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: providerText)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: providerText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF173B70),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: providerBorder),
        ),
        titleTextStyle: const TextStyle(
          color: providerText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          color: providerTextMuted,
          fontSize: 13.5,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF173B70),
        modalBackgroundColor: Color(0xFF173B70),
        surfaceTintColor: Colors.transparent,
        dragHandleColor: providerTextMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF16396D),
        contentTextStyle: const TextStyle(color: providerText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RaRadius.md),
          side: const BorderSide(color: providerBorder),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: providerAction,
        linearTrackColor: Color(0xFF294E80),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [providerNavy, Color(0xFF103B7E), providerRoyalBlue],
          stops: [0, .48, 1],
        ),
      ),
      child: Theme(
        data: providerTheme,
        child: Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ),
    );
  }
}
