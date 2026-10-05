import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens.dart';

part 'screens/appearance_screen.dart';

// ============================================================
// COLOR TOKENS
// Light corporate palette: white foundations, airy blue surfaces and
// medium-blue actions. The legacy dark navy look is intentionally removed.
// ============================================================
const raNavy = Color(0xFF397DBD); // medium corporate header blue
const raNavyDeep = Color(0xFF2F6FAE); // pressed/header gradient blue
const raBlue = Color(0xFF4A90CF); // primary action
const raBlueDeep = Color(0xFF3E82C2); // gradient start
const raBlueBright = Color(0xFF73B3EA); // light accent
const raGold = Color(0xFFE9A227); // rating / certified / premium only
const raGoldPale = Color(0xFFFBF0DA);
const raSuccess = Color(0xFF158A56);
const raSuccessPale = Color(0xFFE3F5EC);
const raDanger = Color(0xFFD8362A);
const raDangerPale = Color(0xFFFBEAE8);
const raInk = Color(0xFF18324A); // corporate slate text
const raMuted = Color(0xFF60758A); // secondary text
const raFaint = Color(0xFF91A5B8); // placeholders
const raCanvas = Color(0xFFFFFFFF); // clean white app background
const raLine = Color(0xFFCEE1F1); // soft blue borders
const raPale = Color(0xFFE7F3FD); // light-blue icon surfaces
const raCard = Color(0xFFF3F9FE); // light-blue cards

// ============================================================
// SPACING SCALE — an 4/8 grid. Use these instead of ad hoc
// numbers for anything new or touched.
// ============================================================
class RaSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const xxxl = 36.0;
}

class RaRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 100.0;
}

// ============================================================
// TYPE SCALE — one place for every recurring text role so
// screens stop inventing their own TextStyle each time.
// ============================================================
class RaText {
  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
  );
  static const eyebrowOnDark = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
    color: Color(0xFFB9C8EA),
  );
  static const display = TextStyle(
    fontSize: 27,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );
  static const headline = TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );
  static const title = TextStyle(
    fontSize: 15.5,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(fontSize: 13.5, height: 1.5);
  static const bodyMuted = TextStyle(fontSize: 13, height: 1.5);
  static const label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);
  static const caption = TextStyle(fontSize: 11, height: 1.4);
  static const numeric = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
}

class RoadAssistApp extends StatefulWidget {
  const RoadAssistApp({super.key});

  @override
  State<RoadAssistApp> createState() => _RoadAssistAppState();
}

class AppThemeController {
  AppThemeController._();

  static const _preferenceKey = 'roadassist_theme_mode';
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    mode.value = switch (preferences.getString(_preferenceKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, value.name);
  }
}

class _RoadAssistAppState extends State<RoadAssistApp> {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigationKey = GlobalKey<NavigatorState>();
  StreamSubscription<RemoteMessage>? openedMessageSubscription;
  Map<String, dynamic>? pendingNotification;
  bool navigationReady = false;
  bool openingNotification = false;

  void queueNotification(Map<String, dynamic> data) {
    if (data['requestId'] == null) return;
    pendingNotification = data;
    unawaited(openPendingNotification());
  }

  Future<void> openPendingNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    final data = pendingNotification;
    if (!mounted ||
        !navigationReady ||
        openingNotification ||
        user == null ||
        data == null)
      return;
    pendingNotification = null;
    if (data['recipientUid'] != null && data['recipientUid'] != user.uid)
      return;
    openingNotification = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .doc(data['requestId'].toString())
          .get();
      final request = snapshot.data();
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != user.uid ||
          request == null)
        return;
      final isDriver = request['driverId'] == user.uid;
      final isProvider = request['providerId'] == user.uid;
      Widget page;
      if (data['type'] == 'chat' && (isDriver || isProvider)) {
        page = ChatScreen(
          requestId: snapshot.id,
          peerName:
              (request[isDriver ? 'providerName' : 'driverName'] as String?) ??
              'RoadAssist user',
          peerPhone:
              (request[isDriver ? 'providerPhone' : 'driverPhone']
                  as String?) ??
              '',
        );
      } else if (isDriver) {
        page = RealtimeDriverRequestDetailsScreen(
          requestId: snapshot.id,
          data: request,
        );
      } else if (isProvider ||
          (request['status'] == 'searching' && data['type'] == 'request')) {
        // Firestore rules independently check whether this provider can read the request.
        page = ProviderRequestDetailsScreen(
          requestId: snapshot.id,
          data: request,
        );
      } else {
        return;
      }
      navigationKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } catch (_) {
      if (mounted)
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'This update is no longer available for your account.',
            ),
          ),
        );
    } finally {
      openingNotification = false;
      if (pendingNotification != null) unawaited(openPendingNotification());
    }
  }

  StreamSubscription<RemoteMessage>? foregroundMessageSubscription;

  @override
  void initState() {
    super.initState();
    AppThemeController.initialize();
    openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => queueNotification(message.data),
    );
    unawaited(
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((message) {
            if (mounted && message != null) queueNotification(message.data);
          })
          .catchError((Object error) {}),
    );
    final query = Uri.base.queryParameters;
    if (query['pushRequest'] != null)
      queueNotification({
        'requestId': query['pushRequest'],
        'type': query['pushType'],
        'recipientUid': query['pushRecipient'],
      });
    foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) {
      final title = message.notification?.title ?? 'RoadAssist update';
      final body =
          message.notification?.body ??
          (message.data['message'] as String? ??
              'You have a new notification.');
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$title\n$body'),
            action: message.data['requestId'] == null
                ? null
                : SnackBarAction(
                    label: 'View',
                    onPressed: () => queueNotification(message.data),
                  ),
          ),
        );
    });
  }

  @override
  void dispose() {
    foregroundMessageSubscription?.cancel();
    openedMessageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppThemeController.mode,
    builder: (context, themeMode, _) => MaterialApp(
      title: 'RoadAssist',
      navigatorKey: navigationKey,
      navigatorObservers: [
        _NotificationNavigationObserver(() {
          navigationReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(openPendingNotification());
          });
        }),
      ],
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF091116)
            : const Color(0xFFEAF4FB),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ClipRect(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: raCanvas,
        splashFactory: InkSparkle.splashFactory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: raBlue,
          primary: raBlue,
          secondary: raGold,
          error: raDanger,
          surface: raCard,
        ),
        textTheme: const TextTheme(
          headlineMedium: RaText.display,
          headlineSmall: RaText.headline,
          titleMedium: RaText.title,
          bodyMedium: RaText.body,
          bodySmall: RaText.bodyMuted,
          labelLarge: RaText.label,
        ),
        dividerTheme: const DividerThemeData(color: raLine, thickness: 1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: raInk,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: raInk,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: raInk),
        ),
        cardTheme: CardThemeData(
          color: raCard,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.lg),
            side: const BorderSide(color: raLine),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: raPale,
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: raNavy,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: raBlue,
            disabledBackgroundColor: raBlue.withValues(alpha: 0.4),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaRadius.sm),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: raNavy,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: raLine, width: 1.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaRadius.sm),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: raBlue,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: raPale,
            foregroundColor: raBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaRadius.sm),
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? raSuccess : raLine,
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5FAFE),
          hintStyle: const TextStyle(color: raFaint, fontSize: 13.5),
          labelStyle: const TextStyle(color: raMuted, fontSize: 13.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: raLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: raLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: raBlue, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: raDanger),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: raPale,
          elevation: 0,
          height: 66,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.lg),
          ),
          titleTextStyle: const TextStyle(
            color: raInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
          contentTextStyle: const TextStyle(
            color: raMuted,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF397DBD),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101820),
        colorScheme: ColorScheme.fromSeed(
          seedColor: raBlueBright,
          brightness: Brightness.dark,
          primary: raBlueBright,
          secondary: raGold,
          error: const Color(0xFFFF7B72),
          surface: const Color(0xFF182733),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(color: Color(0xFFF3F8FC)),
          headlineSmall: TextStyle(color: Color(0xFFF3F8FC)),
          titleLarge: TextStyle(color: Color(0xFFF3F8FC)),
          titleMedium: TextStyle(color: Color(0xFFF3F8FC)),
          bodyLarge: TextStyle(color: Color(0xFFD9E5ED)),
          bodyMedium: TextStyle(color: Color(0xFFD9E5ED)),
          bodySmall: TextStyle(color: Color(0xFFAFC0CC)),
          labelLarge: TextStyle(color: Color(0xFFE7F1F7)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF345062),
          thickness: 1,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD9E5ED)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101820),
          foregroundColor: Color(0xFFEAF4FB),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFEAF4FB),
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF182733),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.lg),
            side: const BorderSide(color: Color(0xFF294353)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF182733),
          hintStyle: const TextStyle(color: Color(0xFF91A5B8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: Color(0xFF294353)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: Color(0xFF294353)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RaRadius.sm),
            borderSide: const BorderSide(color: raBlueBright, width: 1.6),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF101820),
          indicatorColor: Color(0xFF294353),
          elevation: 0,
          height: 66,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Color(0xFFD9E5ED), fontWeight: FontWeight.w700),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF182733),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RaRadius.lg),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: raBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaRadius.sm),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: raBlueBright,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: Color(0xFF3D5B6E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaRadius.sm),
            ),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? raBlue
                : const Color(0xFF3D5B6E),
          ),
        ),
      ),
      home: const SplashScreen(),
    ),
  );
}

void push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
void replace(BuildContext context, Widget page) => Navigator.of(
  context,
).pushReplacement(MaterialPageRoute(builder: (_) => page));

Future<void> showCallPrompt(
  BuildContext context, {
  required String name,
  required String number,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.call_outlined, color: raBlue),
      title: Text('Call $name?'),
      content: Text(number),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.call),
          label: const Text('Open Dialer'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final phoneNumber = number.replaceAll(RegExp(r'[^+\d]'), '');
  final opened = await launchUrl(
    Uri(scheme: 'tel', path: phoneNumber),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No phone dialer is available on this device.'),
      ),
    );
  }
}

Future<void> copyLocation(BuildContext context, String location) async {
  await Clipboard.setData(ClipboardData(text: location));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Location copied. You can share it now.')),
  );
}

Future<void> openMapNavigation(
  BuildContext context, {
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open a navigation app.')),
    );
  }
}

class _NotificationNavigationObserver extends NavigatorObserver {
  _NotificationNavigationObserver(this.ready);
  final VoidCallback ready;
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    ready();
  }
}
