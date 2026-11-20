import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tnt_lh/auth/welcome_screen.dart';

/// What shows while the app starts: the welcome screen's wall drifting in
/// with both shops' marks and the headline. A signed-out customer then gets
/// the sign-in panel rising over the same wall, mid-drift; a signed-in one
/// fades into the menu.
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  /// Long enough for the wall and headline to arrive on a fast start.
  static const minimum = Duration(milliseconds: 1600);

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Color(0xFF0F2419),
        body: _FadeIn(child: WelcomeHero()),
      ),
    );
  }
}

/// The wall comes up out of the launch colour rather than popping in.
class _FadeIn extends StatelessWidget {
  final Widget child;
  const _FadeIn({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, v, c) => Opacity(opacity: v, child: c),
      child: child,
    );
  }
}
