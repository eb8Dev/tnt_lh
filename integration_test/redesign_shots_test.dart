// Screenshots of the redesigned screens in each of their states, for review.
// No sign-in happens: the sign-in controller is replaced by a fake holding a
// fixed state. Run with:
//   SHOTS_TARGET=integration_test/redesign_shots_test.dart \
//     tool/screenshots.py emulator-5554 tests/screenshots/app
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tnt_lh/auth/code_screen.dart';
import 'package:tnt_lh/auth/complete_profile_screen.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/auth/welcome_screen.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/theme.dart';
import 'package:tnt_lh/firebase_options.dart';

/// Holds whatever state the shot needs; nothing reaches Firebase.
class _FakeSignIn extends PhoneSignIn {
  final PhoneSignInState initial;
  _FakeSignIn(this.initial);
  @override
  PhoneSignInState build() => initial;
  @override
  Future<void> sendCode(String phone, {bool resend = false}) async {}
  @override
  Future<void> verify(String code) async => state = state.copyWith(verifying: true);
  @override
  void editNumber() {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await pumpFor(tester, const Duration(seconds: 2));
    // ignore: avoid_print
    print('SHOT:$name');
    // The host captures during this pause; flutter drive's output can lag a few seconds.
    await pumpFor(tester, const Duration(seconds: 8));
  }

  Future<void> show(WidgetTester tester, Widget screen, {PhoneSignInState? signIn}) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [if (signIn != null) phoneSignInProvider.overrideWith(() => _FakeSignIn(signIn))],
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: Responsive.designSizeFor(MediaQuery.sizeOf(context)),
            minTextAdapt: true,
            builder: (_, _) => MaterialApp(debugShowCheckedModeBanner: false, theme: teasNTreesTheme, home: screen),
          ),
        ),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  testWidgets('redesigned screens', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    const phone = '9515409973';

    await show(tester, const WelcomeScreen(), signIn: const PhoneSignInState());
    await shot(tester, '01_welcome');
    await tester.enterText(find.byType(TextField), phone);
    await shot(tester, '02_welcome_number');
    await show(tester, const WelcomeScreen(), signIn: const PhoneSignInState(error: 'Enter your 10-digit mobile number.'));
    await shot(tester, '03_welcome_error');

    const code = PhoneSignInState(step: SignInStep.code, phone: phone, verificationId: 'x', resendIn: 24);
    await show(tester, const CodeScreen(), signIn: code);
    await shot(tester, '04_code');
    await tester.enterText(find.byType(TextField), '482');
    await shot(tester, '05_code_typing');
    await tester.enterText(find.byType(TextField), '482913');
    await shot(tester, '06_code_checking');
    await show(
      tester,
      const CodeScreen(),
      signIn: const PhoneSignInState(step: SignInStep.code, phone: phone, verificationId: 'x', error: "That code isn't right. Check the SMS and try again."),
    );
    await shot(tester, '07_code_wrong');

    await show(tester, const CompleteProfileScreen(initialMobile: phone));
    await shot(tester, '08_new_customer');
    await show(tester, const CompleteProfileScreen(initialName: 'Bhanu', initialEmail: 'name@example.com'));
    await shot(tester, '09_new_customer_google');
  });
}
