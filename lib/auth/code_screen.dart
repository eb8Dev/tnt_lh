import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/auth/phone_sign_in.dart';
import 'package:tnt_lh/auth/welcome_screen.dart' show welcomeWallPhotos;
import 'package:tnt_lh/auth/widgets/auth_widgets.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/widgets/drift_wall.dart';

const _forest = Color(0xFF0F2419);

/// The 6-digit code. The café keeps drifting in the header while an SMS
/// bubble arrives; digits pop into place, the boxes shimmer while the code is
/// checked, and a wrong code shakes. Fills itself from the SMS where the phone
/// allows and checks itself at the sixth digit.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen>
    with TickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  // Runs continuously: the active box's pulse, the typing dots, the checking shimmer.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _changed(String v) {
    HapticFeedback.selectionClick();
    final flow = ref.read(phoneSignInProvider.notifier);
    if (ref.read(phoneSignInProvider).error != null) flow.clearError();
    if (v.length == 6) flow.verify(v);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneSignInProvider);
    final flow = ref.read(phoneSignInProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    // A wrong code: shake, clear, ready for the next try.
    ref.listen(phoneSignInProvider.select((s) => s.error), (prev, next) {
      if (next != null && prev == null && _code.text.length == 6) {
        HapticFeedback.mediumImpact();
        _shake.forward(from: 0);
        _code.clear();
        _focus.requestFocus();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Header: the café drifting, the message arriving.
            SizedBox(
              height: 250.h + MediaQuery.of(context).padding.top,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DriftWall(
                    images: welcomeWallPhotos,
                    background: _forest,
                    dim: 0.55,
                    speed: 16,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x990F2419),
                          Color(0x400F2419),
                          Color(0xF00F2419),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: Space.sm.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            tooltip: 'Change number',
                            icon: Icon(
                              PhosphorIcons.arrowLeft(),
                              color: Colors.white,
                            ),
                            onPressed: flow.editNumber,
                          ),
                          const Spacer(),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              Space.sm.w,
                              0,
                              Space.sm.w,
                              Space.lg.h,
                            ),
                            child: _SmsBubble(pulse: _pulse),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Space.lg.w,
                  Space.lg.h,
                  Space.lg.w,
                  Space.lg.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the code',
                      style: GoogleFonts.poppins(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap(Space.xxs),
                    Text.rich(
                      TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.black54,
                          height: 1.45,
                        ),
                        children: [
                          const TextSpan(text: 'Sent to '),
                          TextSpan(
                            text: '+91 ${state.phone}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: flow.editNumber,
                              child: Text(
                                'Change',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(Space.xl),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) {
                        final t = _shake.value;
                        return Transform.translate(
                          offset: Offset(
                            math.sin(t * math.pi * 6) * 10 * (1 - t),
                            0,
                          ),
                          child: child,
                        );
                      },
                      child: _CodeBoxes(
                        controller: _code,
                        focusNode: _focus,
                        pulse: _pulse,
                        enabled: !state.verifying,
                        verifying: state.verifying,
                        hasError: state.error != null,
                        onChanged: _changed,
                      ),
                    ),
                    AuthError(state.error),
                    Gap(Space.lg),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: state.verifying
                          ? Text(
                              'Checking the code',
                              key: const ValueKey('checking'),
                              style: GoogleFonts.poppins(
                                fontSize: 13.5.sp,
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : state.resendIn > 0
                          ? _ResendCountdown(
                              key: const ValueKey('wait'),
                              seconds: state.resendIn,
                            )
                          : TextButton.icon(
                              key: const ValueKey('resend'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: primary,
                              ),
                              onPressed: state.sending
                                  ? null
                                  : () => flow.sendCode(
                                      state.phone,
                                      resend: true,
                                    ),
                              icon: Icon(
                                PhosphorIcons.arrowClockwise(),
                                size: 18.sp,
                              ),
                              label: Text(
                                state.sending
                                    ? 'Sending'
                                    : "Didn't get it? Send again",
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }
}

/// A message bubble sliding in, its dots typing until the code arrives.
class _SmsBubble extends StatelessWidget {
  final Animation<double> pulse;
  const _SmsBubble({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final bubble = Container(
      padding: EdgeInsets.fromLTRB(
        Space.md.w,
        Space.sm.h,
        Space.md.w,
        Space.sm.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18.r),
          topRight: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
          bottomLeft: Radius.circular(4.r),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34.r,
            height: 34.r,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0E1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
              color: const Color(0xFF3F6B45),
              size: 20.sp,
            ),
          ),
          GapW(Space.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Messages · now',
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  color: Colors.black45,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Your sign-in code is ',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _TypingDots(pulse: pulse),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    if (reduce) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 40),
          child: Transform.scale(
            scale: 0.9 + 0.1 * v,
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: bubble,
    );
  }
}

class _TypingDots extends StatelessWidget {
  final Animation<double> pulse;
  const _TypingDots({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) => Row(
        children: List.generate(3, (i) {
          final phase = (pulse.value - i * 0.18) % 1;
          final lift = math.max(0.0, math.sin(phase * math.pi * 2));
          return Container(
            width: 6.r,
            height: 6.r,
            margin: EdgeInsets.only(right: 3.w),
            transform: Matrix4.translationValues(0, -3 * lift, 0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35 + 0.4 * lift),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

/// "Send again in 0:27", with the time drawn as a ring draining away.
class _ResendCountdown extends StatelessWidget {
  final int seconds;
  const _ResendCountdown({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        SizedBox(
          width: 20.r,
          height: 20.r,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: seconds / PhoneSignIn.resendAfter),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 2.4,
              color: primary,
              backgroundColor: primary.withValues(alpha: 0.12),
            ),
          ),
        ),
        GapW(Space.sm),
        Text(
          'Send again in 0:${seconds.toString().padLeft(2, '0')}',
          style: GoogleFonts.poppins(fontSize: 13.5.sp, color: Colors.black54),
        ),
      ],
    );
  }
}

/// Six boxes over one hidden field, so paste and SMS autofill both work.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Animation<double> pulse;
  final bool enabled;
  final bool verifying;
  final bool hasError;
  final ValueChanged<String> onChanged;
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.pulse,
    required this.enabled,
    required this.verifying,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        // The real input: invisible, but it gets the keyboard, paste and autofill.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            enabled: enabled,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: onChanged,
            showCursor: false,
            enableInteractiveSelection: false,
          ),
        ),
        GestureDetector(
          onTap: focusNode.requestFocus,
          child: AnimatedBuilder(
            animation: Listenable.merge([controller, pulse]),
            builder: (_, _) {
              final text = controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final digit = i < text.length ? text[i] : '';
                  final active = i == text.length && enabled;
                  // While checking, a glow runs across the boxes.
                  final wave = verifying
                      ? math.max(
                          0.0,
                          math.sin((pulse.value * 2 - i / 6) * math.pi),
                        )
                      : 0.0;
                  final breathe = active
                      ? 0.5 + 0.5 * math.sin(pulse.value * math.pi * 2)
                      : 0.0;
                  final border = hasError
                      ? Colors.red.shade400
                      : active
                      ? primary.withValues(alpha: 0.55 + 0.45 * breathe)
                      : digit.isNotEmpty
                      ? primary.withValues(alpha: 0.35)
                      : Colors.transparent;
                  return Container(
                    width: 46.w,
                    height: 58.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        digit.isEmpty
                            ? const Color(0xFFF4F4EE)
                            : const Color(0xFFEFF5EA),
                        primary,
                        wave * 0.35,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: border, width: 2),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: primary.withValues(
                                  alpha: 0.18 * breathe,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                        child: child,
                      ),
                      child: Text(
                        digit,
                        key: ValueKey('$i$digit'),
                        style: GoogleFonts.poppins(
                          fontSize: 23.sp,
                          fontWeight: FontWeight.w700,
                          color: wave > 0.5 ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
