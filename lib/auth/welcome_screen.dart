import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/auth/widgets/auth_widgets.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/widgets/drift_wall.dart';

const _wallPhotos = [
  'assets/images/wall_interior_3.jpg',
  'assets/images/wall_drinks_3.jpg',
  'assets/images/wall_food_3.jpg',
  'assets/images/wall_interior_1.jpg',
  'assets/images/wall_drinks_4.jpg',
  'assets/images/wall_food_6.jpg',
  'assets/images/wall_interior_5.jpg',
  'assets/images/wall_drinks_2.jpg',
  'assets/images/wall_food_1.jpg',
  'assets/images/wall_interior_6.jpg',
  'assets/images/wall_drinks_5.jpg',
  'assets/images/wall_food_2.jpg',
  'assets/images/wall_food_4.jpg',
  'assets/images/wall_food_5.jpg',
];

/// The first thing a new customer sees: the café drifting by, both shops'
/// names, and sign-in right there (phone, Google, Apple). One screen instead
/// of four onboarding pages and a separate login page.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  late final _phone = TextEditingController(
    text: ref.read(phoneSignInProvider).phone,
  );
  bool _social = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _withSocial(Future<void> Function() signIn) async {
    setState(() => _social = true);
    try {
      await signIn();
    } catch (_) {
      // AuthNotifier records the error; AuthWrapper shows it in a sheet.
    } finally {
      if (mounted) setState(() => _social = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signIn = ref.watch(phoneSignInProvider);
    final flow = ref.read(phoneSignInProvider.notifier);
    final auth = ref.read(authProvider.notifier);
    final busy = signIn.busy || _social;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the photos.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F2419),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DriftWall(
                    images: _wallPhotos,
                    background: Color(0xFF0F2419),
                    dim: 0.85,
                  ),
                  // Shade so the title reads on any photo.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x330F2419),
                          Color(0x000F2419),
                          Color(0xE60F2419),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        Space.lg.w,
                        Space.md.h,
                        Space.lg.w,
                        Space.lg.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Mark(Brands.cafeLogo),
                              GapW(Space.xs),
                              _Mark(Brands.bakeryLogo),
                            ],
                          ),
                          const Spacer(),
                          _Rise(
                            delay: 150,
                            child: Text(
                              'Garden brews and fresh bakes, delivered.',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 30.sp,
                                height: 1.12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Gap(Space.xs),
                          _Rise(
                            delay: 300,
                            child: Text(
                              '${Brands.cafeName} and ${Brands.bakeryName}, Guntur',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13.5.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Rise(
              delay: 400,
              offset: 40,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(26.r),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.ml.w,
                      Space.lg.h,
                      Space.ml.w,
                      Space.md.h,
                    ),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign in or create an account',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Gap(Space.xxs),
                          Text(
                            "We'll text you a 6-digit code.",
                            style: GoogleFonts.poppins(
                              fontSize: 12.5.sp,
                              color: Colors.black54,
                            ),
                          ),
                          Gap(Space.md),
                          PhoneField(
                            controller: _phone,
                            enabled: !busy,
                            onChanged: (_) =>
                                signIn.error != null ? flow.clearError() : null,
                            onSubmitted: (v) => flow.sendCode(v),
                          ),
                          AuthError(signIn.error),
                          Gap(Space.md),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _phone,
                            builder: (_, v, _) => AuthPrimaryButton(
                              label: 'Continue',
                              busy: signIn.sending,
                              onTap: v.text.length == 10 && !busy
                                  ? () => flow.sendCode(v.text)
                                  : null,
                            ),
                          ),
                          Gap(Space.md),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Colors.black12),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Space.sm.w,
                                ),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: Colors.black45,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Colors.black12),
                              ),
                            ],
                          ),
                          Gap(Space.md),
                          AuthSocialButton(
                            label: 'Continue with Google',
                            icon: Image.asset(
                              'assets/images/google_logo.png',
                              width: 24.r,
                              height: 24.r,
                            ),
                            onTap: busy
                                ? null
                                : () => _withSocial(auth.signInWithGoogle),
                          ),
                          // Apple requires its button next to any other social sign-in.
                          if (Platform.isIOS) ...[
                            Gap(Space.xs),
                            AuthSocialButton(
                              label: 'Sign in with Apple',
                              dark: true,
                              icon: Icon(
                                PhosphorIcons.appleLogo(
                                  PhosphorIconsStyle.fill,
                                ),
                                color: Colors.white,
                                size: 20.r,
                              ),
                              onTap: busy
                                  ? null
                                  : () => _withSocial(auth.signInWithApple),
                            ),
                          ],
                          Gap(Space.sm),
                          Text(
                            'By continuing you agree to our Terms and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  final String logo;
  const _Mark(this.logo);

  @override
  Widget build(BuildContext context) => Container(
    width: 44.r,
    height: 44.r,
    padding: EdgeInsets.all(6.r),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Image.asset(logo, fit: BoxFit.contain),
  );
}

/// Fades and lifts its child in, once, after [delay] ms.
class _Rise extends StatelessWidget {
  final Widget child;
  final int delay;
  final double offset;
  const _Rise({required this.child, this.delay = 0, this.offset = 16});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + delay),
      curve: Interval(delay / (650 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * offset),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
