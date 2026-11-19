import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/auth/code_screen.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/auth/welcome_screen.dart';
import 'package:tnt_lh/widgets/auth_split.dart';

/// Signed out: welcome (number, Google, Apple), then the code. The step lives
/// in PhoneSignIn; this only draws it, sliding between the two. Back on the
/// code goes to the number instead of leaving the app.
class AuthFlow extends ConsumerWidget {
  const AuthFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(phoneSignInProvider.select((s) => s.step));
    return PopScope(
      canPop: step == SignInStep.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(phoneSignInProvider.notifier).editNumber();
      },
      child: AuthSplit(
        child: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 380),
          reverse: step == SignInStep.welcome,
          transitionBuilder: (child, primary, secondary) =>
              SharedAxisTransition(
                animation: primary,
                secondaryAnimation: secondary,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              ),
          child: step == SignInStep.code
              ? const CodeScreen(key: ValueKey('code'))
              : const WelcomeScreen(key: ValueKey('welcome')),
        ),
      ),
    );
  }
}
