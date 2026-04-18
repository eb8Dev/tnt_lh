import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/firebase_options.dart';
import 'package:tnt_lh/onboarding/onboarding_screen.dart';
import 'package:tnt_lh/onboarding/login_screen.dart';
import 'package:tnt_lh/onboarding/otp_verify.dart';
import 'package:tnt_lh/onboarding/register_screen.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/socket_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/utils/loading_indicator.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

// ...
// Define brand-specific themes
final ThemeData teasNTreesTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFFCFBF4),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF57733C), // Dark Green
    primary: const Color(0xFF57733C),
    onPrimary: const Color(0xFFF2F2F2),
    secondary: const Color(0xFFA5BF45),
    onSecondary: Colors.black,
    tertiary: const Color(0xFF8FA63F),
    onTertiary: Colors.black,
    surface: const Color(0xFFFCFBF4),
    onSurface: Colors.black,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().copyWith(
    displayLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineSmall: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
  ),
);

final ThemeData littleHTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFFCFBF4),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFF2F0D5), // Cream/Light Yellow
    primary: const Color(0xFF8C3414), // Dark Brown/Red
    onPrimary: const Color(0xFFF2F0D5),
    secondary: const Color(0xFFD96F66), // Coral/Orange-Red
    onSecondary: Colors.white,
    tertiary: const Color(0xFFF2E4DC), // Light Peach/Pink
    onTertiary: Colors.black,
    surface: const Color(0xFFFCFBF4),
    onSurface: Colors.black,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().copyWith(
    displayLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    headlineSmall: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Remote Config for Base URL
  await AppConfig.initializeRemoteConfig();

  // FCM Setup
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

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

    return MaterialApp(
      title: 'Teas n Trees & Little H',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => GlobalListener(child: child!),
      home: const AuthWrapper(),
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
        if (next.name == 'order:status-updated') {
          final status =
              next.data['status']?.toString().toUpperCase() ?? 'UPDATED';
          SnackBarUtils.showThemedSnackBar(
            context: context,
            message: "Order Update: Order is $status",
          );
        }
      }
    });

    return child;
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

      return RegisterScreen(
        initialName: authState.firebaseUser?.displayName,
        initialEmail: authState.firebaseUser?.email,
        initialMobile: displayMobile,
      );
    }

    if (authState.firebaseUser != null && authState.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

    return const AuthFlow();
  }
}

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  String _step = 'onboarding'; // onboarding, login, otp
  String? _phone;
  String? _verificationId;

  @override
  Widget build(BuildContext context) {
    if (_step == 'login') {
      return LoginScreen(
        onBack: () => setState(() => _step = 'onboarding'),
        onOtpSent: (phone, verId) => setState(() {
          _phone = phone;
          _verificationId = verId;
          _step = 'otp';
        }),
      );
    } else if (_step == 'otp') {
      return OtpVerifyScreen(
        phone: _phone!,
        verificationId: _verificationId!,
        onBack: () => setState(() => _step = 'login'),
      );
    }
    return OnboardingScreen(
      onGetStarted: () => setState(() => _step = 'login'),
    );
  }
}
