import 'package:tnt_lh/core/responsive.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';
import 'package:tnt_lh/core/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tnt_lh/firebase_options.dart';
import 'package:tnt_lh/auth/auth_flow.dart';
import 'package:tnt_lh/auth/complete_profile_screen.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/connectivity_provider.dart';
import 'package:tnt_lh/providers/socket_provider.dart';
import 'package:tnt_lh/core/navigation.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/rider_tracking_provider.dart';
import 'package:tnt_lh/services/notification_service.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/utils/loading_indicator.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:google_fonts/google_fonts.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

// ...
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins and Playfair are bundled in google_fonts/ and declared in pubspec,
  // so google_fonts resolves them from the asset manifest. Runtime fetching is
  // off: by default the package DOWNLOADS fonts from Google's CDN on first
  // launch, which meant a customer on a poor connection opened the app in the
  // fallback typeface — and paid for the data. With this false, a missing font
  // is a build-time mistake rather than a silent runtime downgrade.
  GoogleFonts.config.allowRuntimeFetching = false;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Remote Config for Base URL
  await AppConfig.initializeRemoteConfig();

  // FCM Setup
  // Foreground + tap notification handling (local notifications, routing).
  // The permission prompt and token registration happen later, on the signed-in
  // home screen (NotificationService.enableForSignedInUser).
  await NotificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(socketManagerProvider);
    final brand = ref.watch(brandProvider);
    final theme = brand == 'teasntrees' ? teasNTreesTheme : littleHTheme;

    return ScreenUtilInit(
      // Capped on wide screens (foldables, tablets): see Responsive.
      designSize: Responsive.designSizeFor(MediaQuery.sizeOf(context)),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        title: 'Teas N Trees & Cream N Crust',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        theme: theme,
        builder: (context, child) {
          // Clamp system font scaling so accessibility large-fonts can't
          // overflow layouts (a common source of RenderFlex overflow errors).
          final mq = MediaQuery.of(context);
          final scaler = mq.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.25,
          );
          return MediaQuery(
            data: mq.copyWith(textScaler: scaler),
            // Dark status bar icons on the app's light screens. Screens with a
            // dark top (welcome, rider badge) set light icons for themselves;
            // without this default those stayed on after leaving them.
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
              child: GlobalListener(child: child!),
            ),
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

class GlobalListener extends ConsumerWidget {
  final Widget child;
  const GlobalListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SocketEvent?>(socketEventsProvider, (previous, next) {
      if (next != null) {
        // Order changes show on the screens themselves (the order, the
        // active-order bar, the orders list) and as a push when the app is
        // closed; no pop-up on top of them.
        if (next.name == 'rider:location-update') {
          ref.read(riderTrackingProvider.notifier).updateWithEvent(next);
        }
      }
    });

    // A dropped connection used to be completely silent in this app: adding to
    // the cart, applying a coupon or placing an order just failed with a generic
    // error, and the customer had no way to tell it was their phone rather than
    // us. They'd try again — which, for checkout, is the worst possible response.
    final isOnline = ref.watch(connectivityProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          _OfflineBanner(visible: !isOnline),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Sits above every screen, so it can't be missed on whichever page the customer
/// happens to be on when the signal goes.
class _OfflineBanner extends StatelessWidget {
  final bool visible;
  const _OfflineBanner({required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: visible
          ? Material(
              color: const Color(0xFFC0574F),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.wifiSlash(),
                        color: Colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          "You're offline. We'll pick up where you left off "
                          "once you're back.",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _checkedStore = false;

  @override
  void initState() {
    super.initState();
    _checkStorePref();
  }

  Future<void> _checkStorePref() async {
    // brandProvider already handles initialization from storage
    if (mounted) {
      setState(() => _checkedStore = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    ref.listen(authProvider.select((s) => s.isAuthenticated || s.requiresRegistration), (_, signedIn) {
      if (signedIn) ref.invalidate(phoneSignInProvider);
    });

    if ((authState.isLoading &&
            !authState.isAuthenticated &&
            !authState.requiresRegistration) ||
        !_checkedStore) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: HouseOfFlavorsLoader(size: 160)),
      );
    }

    if (authState.isAuthenticated) {
      return const StoreHomeScreen();
    }

    if (authState.requiresRegistration) {
      String? displayMobile = authState.user?.mobile;
      if (displayMobile == null || displayMobile.isEmpty) {
        displayMobile = authState.firebaseUser?.phoneNumber;
        if (displayMobile != null) {
          displayMobile = displayMobile.replaceAll(RegExp(r'\D'), '');
          if (displayMobile.length > 10) {
            displayMobile = displayMobile.substring(displayMobile.length - 10);
          }
        }
      }

      return CompleteProfileScreen(
        initialName: authState.firebaseUser?.displayName,
        initialEmail: authState.firebaseUser?.email,
        initialMobile: displayMobile,
      );
    }

    // Surface a post-Firebase-login backend failure with retry/logout.
    if (authState.firebaseUser != null && authState.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Not const: Phosphor icons are method calls, so they can't
                // appear inside a const expression.
                Icon(
                  PhosphorIcons.warningCircle(),
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Authentication Failed",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  authState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(authProvider.notifier).refreshProfile(),
                  child: const Text("Retry"),
                ),
                TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text("Logout"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // A Google/social failure BEFORE Firebase sign-in (no firebaseUser) used to
    // bounce silently back to onboarding, reading as "redirected to splash".
    // Show the onboarding flow but with the error surfaced so it isn't silent.
    if (authState.error != null && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final message = authState.error!;
        ref.read(authProvider.notifier).clearError();
        if (context.mounted) noticeSheet(context, message: message);
      });
    }

    return const AuthFlow();
  }
}

