import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens.dart';

part 'features/settings/appearance_screen.dart';
part 'core/theme/app_theme.dart';

// ============================================================
// COLOR TOKENS
// Light corporate palette: white foundations, airy blue surfaces and
// deep-blue actions, with matching dark-mode semantic surfaces.
// ============================================================
const raNavy = Color(0xFF095BA8); // medium corporate header blue
const raNavyDeep = Color(0xFF074980); // pressed/header gradient blue
const raBlue = Color(0xFF0963BA); // primary action
const raBlueDeep = Color(0xFF07569E); // gradient start
const raBlueBright = Color(0xFF73B3EA); // light accent
const raGold = Color(0xFFE9A227); // rating / certified / premium only
const raGoldPale = Color(0xFFFBF0DA);
const raSuccess = Color(0xFF158A56);
const raSuccessPale = Color(0xFFE3F5EC);
const raDanger = Color(0xFFD8362A);
const raDangerPale = Color(0xFFFBEAE8);
const raInk = Color(0xFF14283F); // corporate slate text
const raMuted = Color(0xFF60758A); // secondary text
const raFaint = Color(0xFF91A5B8); // placeholders
const raCanvas = Color(0xFFF5F8FC); // calm neutral app background
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
  static const body = TextStyle(fontSize: 15, height: 1.5);
  static const bodyMuted = TextStyle(fontSize: 14, height: 1.5);
  static const label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);
  static const caption = TextStyle(fontSize: 12, height: 1.4);
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
    if (const bool.fromEnvironment('ADMIN_PORTAL')) return;
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
            constraints: const BoxConstraints(
              maxWidth: bool.fromEnvironment('ADMIN_PORTAL') ? 1200 : 430,
            ),
            child: ClipRect(
              child: AccountAccessGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
      themeMode: themeMode,
      theme: buildRoadAssistTheme(Brightness.light),
      darkTheme: buildRoadAssistTheme(Brightness.dark),
      home: const bool.fromEnvironment('ADMIN_PORTAL')
          ? const AdminPortalScreen()
          : const SplashScreen(),
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
